// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! Byte-stable Rust IR projected from executable Agentic AI Lab Scheme contracts.
//!
//! This crate distributes generated build inputs. It does not implement or
//! reinterpret the owning Scheme contracts.

/// Transport pre-admission for a Query execution candidate.
pub const QUERY_EXECUTION_CANDIDATE_V1_IR: &str =
    include_str!("../query-execution-candidate-v1.ir.json");
