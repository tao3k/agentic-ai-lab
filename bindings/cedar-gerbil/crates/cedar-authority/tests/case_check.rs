// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! A real schema-valid Cedar evaluation error must not qualify as an expected denial.

use std::path::PathBuf;
use std::process::Command;

#[test]
fn cedar_case_cli_rejects_aligned_evaluation_error() {
    let host = std::env::var_os("AGENTIC_AI_LAB_CEDAR_RUNTIME_HOST")
        .expect("qualification requires the AOT Runtime Host artifact");
    let fixtures = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/atomic-case");
    let output = Command::new(env!("CARGO_BIN_EXE_cedar-case-check"))
        .arg(fixtures.join("manifest.json"))
        .arg(host)
        .arg(fixtures.join("overflow.cedar"))
        .output()
        .expect("case CLI must start");
    assert!(!output.status.success());
    let stderr = String::from_utf8(output.stderr).expect("CLI stderr must be UTF-8");
    assert!(
        stderr.contains("base-permit: Cedar evaluation error in policies"),
        "unexpected error: {stderr}"
    );
}
