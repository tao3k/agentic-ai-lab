// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! Explicit qualification: a C-owned thread calls Lean's compiled library.
//! This does not claim authorization-grant, timeout, or crash isolation closure.
use cedar_policy::{Context, Entities, Policy, PolicyId, PolicySet, Request};
use agentic_ai_lab_cedar_authority::{canonical, wire};
use std::{io::Write, process::Command};

fn probe(bytes: &[u8]) -> std::process::Output {
    let executable = std::env::var_os("AGENTIC_AI_LAB_CEDAR_NATIVE_PROBE")
        .expect("qualification requires the compiled C native probe; no skipped checks");
    let mut input = tempfile::NamedTempFile::new().unwrap();
    input.write_all(bytes).unwrap();
    Command::new(executable).arg(input.path()).output().unwrap()
}

#[test]
fn native_lean_matches_rust_allow_default_deny_and_forbid() {
    for (approved, blocked, expected) in [
        (true, false, "allow"),
        (false, false, "deny"),
        (true, true, "deny"),
    ] {
        let mut policies = PolicySet::new();
        for (id, source) in [
            (
                "permit-run",
                "permit(principal, action, resource) when { context.approved };",
            ),
            (
                "forbid-blocked",
                "forbid(principal, action, resource) when { context.blocked };",
            ),
        ] {
            policies
                .add(Policy::parse(Some(PolicyId::new(id)), source).unwrap())
                .unwrap();
        }
        let request = Request::new(
            "User::\"alice\"".parse().unwrap(),
            "Action::\"run\"".parse().unwrap(),
            "Job::\"demo\"".parse().unwrap(),
            Context::from_json_value(
                serde_json::json!({"approved": approved, "blocked": blocked}),
                None,
            )
            .unwrap(),
            None,
        )
        .unwrap();
        let bytes = wire::AuthorizationRequest::encode(&request, &policies, &Entities::empty());
        let rust = wire::evaluate_rust(&bytes).unwrap();
        let output = probe(&bytes);
        assert!(
            output.status.success(),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
        let native_receipt = String::from_utf8_lossy(&output.stderr);
        assert!(
            native_receipt.starts_with("cedar-native-receipt repetitions=128 steady_elapsed_ns=")
        );
        assert!(native_receipt.ends_with(" sigchld_preserved=true\n"));
        let mut lean: wire::Outcome = canonical::parse(&output.stdout).unwrap();
        lean.validate("cedar-lean", wire::LEAN_REVISION).unwrap();
        assert_eq!(lean.decision, expected);
        assert!(rust.agrees_with(&lean), "rust={rust:?}; lean={lean:?}");
        println!(
            "native-ffi {}decision={} determining={:?} input_digest={}",
            native_receipt,
            lean.decision,
            lean.determining_policies,
            canonical::raw_digest(&bytes)
        );
    }
}

#[test]
fn native_lean_rejects_malformed_protobuf() {
    let output = probe(&[0xff]);
    assert_eq!(
        output.status.code(),
        Some(2),
        "malformed protobuf must be a typed rejection, not a panic: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(output.stdout.is_empty());
    assert!(String::from_utf8_lossy(&output.stderr).starts_with("cedar-input-invalid:"));
}
