// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! Minimal command-line entrypoint for the crate-owned case checker.

fn main() {
    if let Err(error) = agentic_ai_lab_cedar_authority::case_check::run_cli() {
        eprintln!("cedar-case-check: {error}");
        std::process::exit(1);
    }
}
