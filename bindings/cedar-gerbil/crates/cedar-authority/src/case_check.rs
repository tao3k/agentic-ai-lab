// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! Data-driven qualification of exported Cedar files against the strict Runtime Host.

use crate::authority::Authority;
use crate::canonical;
use crate::projection::{Bootstrap, PolicySource, Proposal};
use crate::runtime::{Deployment, HOST_READY_SCHEMA, RuntimeReady};
use crate::wire::{CEDAR_VERSION, LEAN_REVISION, Outcome};
use cedar_policy::PolicySet;
use serde::Deserialize;
use std::collections::BTreeSet;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::str::FromStr;
use std::sync::mpsc;
use std::time::{Duration, Instant};

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Case {
    name: String,
    proposal: Proposal,
    expected_status: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Manifest {
    bootstrap: Bootstrap,
    cases: Vec<Case>,
}

struct Host {
    child: Child,
    _directory: tempfile::TempDir,
    deployment: Deployment,
}

impl Drop for Host {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

fn read_policy_file(path: &Path) -> Result<(PolicySource, usize), String> {
    let bytes = std::fs::read(path).map_err(|error| format!("{}: {error}", path.display()))?;
    let source = std::str::from_utf8(&bytes).map_err(|error| error.to_string())?;
    let policies =
        PolicySet::from_str(source).map_err(|error| format!("{}: {error}", path.display()))?;
    if policies.templates().next().is_some() {
        return Err(format!(
            "{}: policy templates require explicit linking",
            path.display()
        ));
    }
    let count = policies.policies().count();
    if count == 0 {
        return Err(format!("{}: no static policies", path.display()));
    }
    let digest = canonical::raw_digest(&bytes);
    Ok((
        PolicySource {
            identity: format!("artifact-{}", &digest[7..]),
            source: source.to_owned(),
        },
        count,
    ))
}

fn require_error_free_decision(name: &str, outcome: &Outcome) -> Result<(), String> {
    if outcome.erroring_policies.is_empty() {
        Ok(())
    } else {
        Err(format!(
            "{name}: Cedar evaluation error in policies {:?}",
            outcome.erroring_policies
        ))
    }
}

fn start_host(path: &Path) -> Result<Host, String> {
    let artifact = canonical::raw_digest(&std::fs::read(path).map_err(|error| error.to_string())?);
    let rust = canonical::raw_digest(CEDAR_VERSION.as_bytes());
    let lean = canonical::raw_digest(LEAN_REVISION.as_bytes());
    let directory = tempfile::tempdir().map_err(|error| error.to_string())?;
    let endpoint = directory.path().join("runtime.sock");
    let mut child = Command::new(path)
        .args([
            "serve-unix",
            endpoint.to_str().ok_or("non-UTF8 socket path")?,
            &artifact,
            &rust,
            &lean,
            "10000",
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .map_err(|error| error.to_string())?;
    let stdout = match child.stdout.take() {
        Some(stdout) => stdout,
        None => {
            let _ = child.kill();
            let _ = child.wait();
            return Err("missing Host readiness pipe".into());
        }
    };
    let (sender, receiver) = mpsc::sync_channel(1);
    std::thread::spawn(move || {
        let mut line = String::new();
        let result = BufReader::new(stdout).read_line(&mut line).map(|_| line);
        let _ = sender.send(result);
    });
    let readiness = (|| -> Result<(), String> {
        let ready = receiver
            .recv_timeout(Duration::from_secs(10))
            .map_err(|error| format!("Host readiness timeout: {error}"))?
            .map_err(|error| error.to_string())?;
        let ready: RuntimeReady =
            serde_json::from_str(&ready).map_err(|error| error.to_string())?;
        if ready.schema_id != HOST_READY_SCHEMA || Path::new(&ready.endpoint) != endpoint {
            return Err("Host readiness identity mismatch".into());
        }
        Ok(())
    })();
    if let Err(error) = readiness {
        let _ = child.kill();
        let _ = child.wait();
        return Err(error);
    }
    Ok(Host {
        child,
        _directory: directory,
        deployment: Deployment {
            runtime_endpoint: endpoint,
            runtime_artifact_digest: artifact,
            rust_component_digest: rust,
            lean_component_digest: lean,
            timeout_ms: 10000,
            grant_lifetime_ms: 30000,
        },
    })
}

/// Replay one manifest and one or more exported Cedar files from CLI arguments.
pub fn run_cli() -> Result<(), String> {
    let mut args = std::env::args_os().skip(1);
    let first = args
        .next()
        .ok_or("usage: cedar-case-check MANIFEST HOST POLICY.cedar [POLICY.cedar ...]")?;
    if first == std::ffi::OsStr::new("inspect") {
        let files = args.map(PathBuf::from).collect::<Vec<_>>();
        if files.is_empty() {
            return Err("usage: cedar-case-check inspect POLICY.cedar [POLICY.cedar ...]".into());
        }
        for file in files {
            println!(
                "{}: {} static policies",
                file.display(),
                read_policy_file(&file)?.1
            );
        }
        return Ok(());
    }
    let manifest_path = PathBuf::from(first);
    let host_path = PathBuf::from(args.next().ok_or("missing AOT Runtime Host path")?);
    let files = args.map(PathBuf::from).collect::<Vec<_>>();
    if files.is_empty() {
        return Err("at least one exported .cedar file is required".into());
    }
    let mut manifest: Manifest =
        serde_json::from_slice(&std::fs::read(&manifest_path).map_err(|error| error.to_string())?)
            .map_err(|error| error.to_string())?;
    if !manifest.bootstrap.policies.is_empty() || manifest.cases.is_empty() {
        return Err("manifest requires empty bootstrap.policies and nonempty cases".into());
    }
    let mut names = BTreeSet::new();
    for case in &manifest.cases {
        if case.name.is_empty() || !names.insert(&case.name) {
            return Err(format!("duplicate or empty case name: {}", case.name));
        }
        if case.expected_status != "authorized" && case.expected_status != "denied" {
            return Err(format!(
                "{}: expected_status must be authorized or denied",
                case.name
            ));
        }
    }
    let mut policy_count = 0;
    for file in &files {
        let (source, count) = read_policy_file(file)?;
        manifest.bootstrap.policies.push(source);
        policy_count += count;
    }
    let case_count = manifest.cases.len();
    let started = Instant::now();
    let host = start_host(&host_path)?;
    let mut seed = [0u8; 32];
    getrandom::fill(&mut seed).map_err(|error| error.to_string())?;
    let mut authority = Authority::new(manifest.bootstrap, host.deployment.clone(), seed)
        .map_err(|error| error.to_string())?;
    let mut consumed = 0;
    let mut rust_worker_ms = 0_u64;
    let mut lean_worker_ms = 0_u64;
    for case in manifest.cases {
        let result = authority
            .issue(case.proposal.clone())
            .map_err(|error| format!("{}: {error}", case.name))?;
        if !result
            .receipt
            .payload
            .rust
            .payload
            .outcome
            .agrees_with(&result.receipt.payload.lean.payload.outcome)
        {
            return Err(format!(
                "{}: Cedar Rust and Lean outcomes disagree",
                case.name
            ));
        }
        require_error_free_decision(&case.name, &result.receipt.payload.rust.payload.outcome)?;
        if result.status != case.expected_status {
            return Err(format!(
                "{}: expected {}, got {}",
                case.name, case.expected_status, result.status
            ));
        }
        rust_worker_ms += result.receipt.payload.rust.payload.elapsed_ms;
        lean_worker_ms += result.receipt.payload.lean.payload.elapsed_ms;
        match (result.status.as_str(), result.grant) {
            ("authorized", Some(grant)) => {
                // Consumption is confined to this diagnostic Authority.
                // No effect dispatcher receives the returned handoff.
                authority
                    .consume_proposal(grant, case.proposal)
                    .map_err(|error| format!("{}: {error}", case.name))?;
                consumed += 1;
            }
            ("denied", None) => {}
            _ => return Err(format!("{}: inconsistent grant and decision", case.name)),
        }
        println!("{}: {} (Cedar Rust + Lean)", case.name, result.status);
    }
    authority.close();
    println!(
        "cedar-case-check: {case_count} cases, {policy_count} policies, {consumed} locally consumed grants, {} ms wall, {rust_worker_ms} ms Rust workers, {lean_worker_ms} ms Lean workers",
        started.elapsed().as_millis()
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::require_error_free_decision;
    use crate::wire::Outcome;

    #[test]
    fn a_denied_case_cannot_hide_a_matching_engine_error() {
        let mut outcome = Outcome {
            schema_id: "agentic-ai-lab.cedar-engine-outcome.v1".into(),
            engine_id: "cedar-rust".into(),
            semantic_revision: "test".into(),
            decision: "deny".into(),
            determining_policies: vec![],
            erroring_policies: vec!["policy-with-error".into()],
        };
        assert!(
            require_error_free_decision("expected-deny", &outcome)
                .unwrap_err()
                .contains("policy-with-error")
        );
        outcome.erroring_policies.clear();
        require_error_free_decision("expected-deny", &outcome).unwrap();
    }
}
