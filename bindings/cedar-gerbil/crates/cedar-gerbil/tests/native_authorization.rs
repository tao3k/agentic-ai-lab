// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

use gerbil_scheme::{GerbilRuntime, LinkedGerbilProgram};
use gerbil_scheme_sys::{GerbilGlobalState, GerbilModuleOrLink};
use agentic_ai_lab_cedar_authority::{
    canonical,
    runtime::{Deployment, HOST_READY_SCHEMA, RuntimeReady},
    wire::{CEDAR_VERSION, LEAN_REVISION},
};
use agentic_ai_lab_cedar_gerbil::NativeAuthority;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::mpsc;
use std::time::Duration;

unsafe extern "C" {
    fn ___LNK_poo__flow__cedar__linker(state: *mut GerbilGlobalState) -> *mut GerbilModuleOrLink;
    fn agentic_ai_lab_cedar_snapshot_root() -> i64;
    fn agentic_ai_lab_cedar_allow_root() -> i64;
    fn agentic_ai_lab_cedar_deny_root() -> i64;
    fn agentic_ai_lab_cedar_forbid_root() -> i64;
}

struct TestRuntime {
    deployment: Deployment,
    child: Child,
    _directory: tempfile::TempDir,
}

impl Drop for TestRuntime {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

fn spawn_runtime() -> TestRuntime {
    let host = PathBuf::from(
        std::env::var_os("AGENTIC_AI_LAB_CEDAR_RUNTIME_HOST")
            .expect("qualification requires the AOT Runtime Host artifact"),
    );
    let runtime_artifact_digest = canonical::raw_digest(&std::fs::read(&host).unwrap());
    let rust_component_digest = canonical::raw_digest(CEDAR_VERSION.as_bytes());
    let lean_component_digest = canonical::raw_digest(LEAN_REVISION.as_bytes());
    let directory = tempfile::tempdir().unwrap();
    let endpoint = directory.path().join("runtime.sock");
    let mut child = Command::new(&host)
        .args([
            "serve-unix",
            endpoint.to_str().unwrap(),
            &runtime_artifact_digest,
            &rust_component_digest,
            &lean_component_digest,
            "10000",
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .unwrap();
    let stdout = child.stdout.take().unwrap();
    let (sender, receiver) = mpsc::sync_channel(1);
    std::thread::spawn(move || {
        let mut line = String::new();
        let result = BufReader::new(stdout).read_line(&mut line).map(|_| line);
        let _ = sender.send(result);
    });
    let ready = receiver
        .recv_timeout(Duration::from_secs(10))
        .unwrap()
        .unwrap();
    let ready: RuntimeReady = canonical::parse(ready.as_bytes()).unwrap();
    assert_eq!(ready.schema_id, HOST_READY_SCHEMA);
    assert_eq!(Path::new(&ready.endpoint), endpoint);
    TestRuntime {
        deployment: Deployment {
            runtime_endpoint: endpoint,
            runtime_artifact_digest,
            rust_component_digest,
            lean_component_digest,
            timeout_ms: 10000,
            grant_lifetime_ms: 30000,
        },
        child,
        _directory: directory,
    }
}

#[test]
fn native_poo_projection_dual_authorization_and_single_use_consumption() {
    let output = PathBuf::from(env!("OUT_DIR"));
    let program_c = std::fs::read_to_string(output.join("program_link.c")).unwrap();
    let bridge_c =
        std::fs::read_to_string(output.join("gerbil-scheme-rust__scheme__native.c")).unwrap();
    let program_id = "#define ___LINKER_ID ___LNK_poo__flow__cedar__linker";
    assert!(program_c.contains(program_id));
    assert!(
        !bridge_c.contains(program_id),
        "module linker identity was overwritten"
    );
    // SAFETY: build.ss and the generated linker include the bridge, POO module,
    // and the four exception-contained conformance exports declared above.
    let program = unsafe { LinkedGerbilProgram::from_linker(___LNK_poo__flow__cedar__linker) };
    let runtime = GerbilRuntime::initialize_program(program).unwrap();
    assert!(GerbilRuntime::initialize().is_err());
    let snapshot = unsafe { runtime.bind_string_export(agentic_ai_lab_cedar_snapshot_root) }.unwrap();
    let allow = unsafe { runtime.bind_string_export(agentic_ai_lab_cedar_allow_root) }.unwrap();
    let deny = unsafe { runtime.bind_string_export(agentic_ai_lab_cedar_deny_root) }.unwrap();
    let forbid = unsafe { runtime.bind_string_export(agentic_ai_lab_cedar_forbid_root) }.unwrap();
    let host = spawn_runtime();
    let mut authority =
        NativeAuthority::new(&runtime, &snapshot, host.deployment.clone(), [42; 32]).unwrap();
    let result = authority.issue(&allow).unwrap();
    assert_eq!(result.status, "authorized");
    assert!(
        result
            .receipt
            .payload
            .rust
            .payload
            .outcome
            .agrees_with(&result.receipt.payload.lean.payload.outcome)
    );
    assert_eq!(
        result.receipt.payload.provenance.composition_identity,
        "native.composition"
    );
    println!(
        "native-cedar decision={} rust_policies={:?} lean_policies={:?} input_digest={}",
        result.receipt.payload.rust.payload.outcome.decision,
        result
            .receipt
            .payload
            .rust
            .payload
            .outcome
            .determining_policies,
        result
            .receipt
            .payload
            .lean
            .payload
            .outcome
            .determining_policies,
        result.receipt.payload.rust.payload.input_artifact_digest,
    );
    let grant = result.grant.unwrap();
    assert_eq!(
        authority.consume(grant.clone(), &deny).unwrap_err().code,
        "grant-request-binding-mismatch"
    );
    assert_eq!(authority.info().pending_grants, 1);
    let consumed = authority.consume(grant.clone(), &allow).unwrap();
    assert_eq!(consumed.handoff.payload_hex, "0a141e");
    let replay = authority.consume(grant, &allow).unwrap_err();
    assert_eq!(replay.code, "grant-consumed-or-unknown");
    println!(
        "native-consume payload={} replay={}",
        consumed.handoff.payload_hex, replay.code
    );
    assert!(authority.issue(&deny).unwrap().grant.is_none());
    let denied = authority.issue(&forbid).unwrap();
    assert!(denied.grant.is_none());
    assert_eq!(
        denied
            .receipt
            .payload
            .rust
            .payload
            .outcome
            .determining_policies,
        ["native-atomic-bundle-1"]
    );
    authority.close();
}
