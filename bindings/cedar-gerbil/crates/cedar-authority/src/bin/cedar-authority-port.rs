// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

use agentic_ai_lab_cedar_authority::{
    authority::{Authority, Grant, Signed},
    canonical,
    projection::{Bootstrap, Proposal},
    runtime::{Deployment, read_frame, write_frame},
    wire::{CEDAR_VERSION, LEAN_REVISION},
};
use serde::Deserialize;
use serde_json::json;
use std::{error::Error, io, os::unix::process::CommandExt, path::PathBuf, process};

#[derive(Deserialize)]
#[serde(tag = "operation", rename_all = "snake_case", deny_unknown_fields)]
enum Command {
    Issue {
        proposal: Proposal,
    },
    Check {
        proposal: Proposal,
        grant: Signed<Grant>,
    },
    Consume {
        proposal: Proposal,
        grant: Signed<Grant>,
    },
}

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if let [mode, artifact, endpoint] = args.as_slice() {
        if mode == "serve-host" {
            let artifact = std::fs::canonicalize(artifact)?;
            return Err(process::Command::new(&artifact)
                .arg("serve-unix")
                .arg(endpoint)
                .arg(canonical::raw_digest(&std::fs::read(&artifact)?))
                .arg(canonical::raw_digest(CEDAR_VERSION.as_bytes()))
                .arg(canonical::raw_digest(LEAN_REVISION.as_bytes()))
                .arg("10000")
                .exec()
                .into());
        }
    }
    let [endpoint, artifact] = args.as_slice() else {
        return Err("usage: cedar-authority-port ENDPOINT HOST_ARTIFACT".into());
    };
    let mut input = io::stdin().lock();
    let mut output = io::stdout().lock();
    let bootstrap: Bootstrap =
        canonical::parse(&read_frame(&mut input)?.ok_or("missing authority snapshot")?)?;
    let deployment = Deployment {
        runtime_endpoint: PathBuf::from(endpoint),
        runtime_artifact_digest: canonical::raw_digest(&std::fs::read(artifact)?),
        rust_component_digest: canonical::raw_digest(CEDAR_VERSION.as_bytes()),
        lean_component_digest: canonical::raw_digest(LEAN_REVISION.as_bytes()),
        timeout_ms: 10_000,
        grant_lifetime_ms: 30_000,
    };
    let mut seed = [0u8; 32];
    getrandom::fill(&mut seed).map_err(|error| io::Error::other(error.to_string()))?;
    let mut authority = Authority::new(bootstrap, deployment, seed)?;
    write_frame(&mut output, br#"{"status":"ready"}"#)?;
    while let Some(frame) = read_frame(&mut input)? {
        let result = match canonical::parse::<Command>(&frame)? {
            Command::Issue { proposal } => authority
                .issue(proposal)
                .map(|result| json!({"status": result.status, "grant": result.grant})),
            Command::Check { proposal, grant } => authority
                .check_proposal(&grant, proposal)
                .map(|()| json!({"status": "current"})),
            Command::Consume { proposal, grant } => authority
                .consume_proposal(grant, proposal)
                .map(|handoff| json!({"status": "consumed", "handoff": handoff})),
        };
        let reply = result.unwrap_or_else(|error| json!({"status":"refused","reason":error.code}));
        write_frame(&mut output, &serde_json::to_vec(&reply)?)?;
    }
    authority.close();
    Ok(())
}
