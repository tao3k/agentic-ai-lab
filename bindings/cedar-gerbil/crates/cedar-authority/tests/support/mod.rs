// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

use agentic_ai_lab_cedar_authority::runtime::{HOST_READY_SCHEMA, RuntimeReady};
use std::io::{BufRead, BufReader};
use std::path::Path;
use std::process::Child;
use std::sync::mpsc;
use std::time::Duration;

pub fn wait_for_runtime_ready(child: &mut Child, endpoint: &Path) {
    let stdout = child
        .stdout
        .take()
        .expect("Runtime Host stdout must carry its readiness receipt");
    let (sender, receiver) = mpsc::sync_channel(1);
    std::thread::spawn(move || {
        let mut line = String::new();
        let result = BufReader::new(stdout)
            .read_line(&mut line)
            .map(|length| (length, line));
        let _ = sender.send(result);
    });
    let observed = (|| -> Result<RuntimeReady, String> {
        let (length, line) = receiver
            .recv_timeout(Duration::from_secs(10))
            .map_err(|error| format!("Runtime Host readiness timed out: {error}"))?
            .map_err(|error| format!("Runtime Host readiness channel failed: {error}"))?;
        if length == 0 {
            return Err("Runtime Host exited before readiness".into());
        }
        serde_json::from_str(line.trim_end())
            .map_err(|error| format!("Runtime Host readiness is not typed JSON: {error}"))
    })();
    let failure = match observed {
        Ok(ready) if ready.schema_id != HOST_READY_SCHEMA => Some(format!(
            "unexpected Runtime Host readiness schema: {}",
            ready.schema_id
        )),
        Ok(ready) if Path::new(&ready.endpoint) != endpoint => Some(format!(
            "Runtime Host readiness endpoint mismatch: {}",
            ready.endpoint
        )),
        Ok(_) if !matches!(child.try_wait(), Ok(None)) => {
            Some("Runtime Host exited after readiness".into())
        }
        Ok(_) => None,
        Err(error) => Some(error),
    };
    if let Some(error) = failure {
        let _ = child.kill();
        let _ = child.wait();
        panic!("{error}");
    }
}
