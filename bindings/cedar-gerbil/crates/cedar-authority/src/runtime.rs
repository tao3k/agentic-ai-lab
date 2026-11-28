// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! Bounded framing and receipts for an independently owned Runtime host.

use crate::{Error, Result, canonical, wire::Outcome};
use serde::{Deserialize, Serialize};
use std::io::{Read, Write};
#[cfg(unix)]
use std::os::unix::net::UnixStream;
#[cfg(unix)]
use std::path::Path;
use std::path::PathBuf;
use std::time::Duration;

pub const HOST_SCHEMA: &str = "agentic-ai-lab.cedar-runtime-host.v1";
pub const HOST_READY_SCHEMA: &str = "agentic-ai-lab.cedar-runtime-ready.v1";
pub const REPLY_SCHEMA: &str = "agentic-ai-lab.cedar-runtime-reply.v1";
pub const MAX_FRAME_BYTES: usize = canonical::MAX_PROJECTION_BYTES;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RuntimeHello {
    pub schema_id: String,
    pub generation: String,
    pub timeout_ms: u64,
    pub runtime_artifact_digest: String,
    pub rust_component_digest: String,
    pub lean_component_digest: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RuntimeReady {
    pub schema_id: String,
    pub endpoint: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Deployment {
    pub runtime_endpoint: PathBuf,
    pub runtime_artifact_digest: String,
    pub rust_component_digest: String,
    pub lean_component_digest: String,
    pub timeout_ms: u64,
    pub grant_lifetime_ms: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RuntimeWitness {
    pub engine_id: String,
    pub component_digest: String,
    pub elapsed_ms: u64,
    pub outcome: Outcome,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RuntimeReply {
    pub schema_id: String,
    pub generation: String,
    pub sequence: u64,
    pub input_artifact_digest: String,
    pub rust: Option<RuntimeWitness>,
    pub lean: Option<RuntimeWitness>,
    pub error: Option<Error>,
}

impl RuntimeReply {
    pub fn validate(&self, hello: &RuntimeHello, sequence: u64, input: &[u8]) -> Result<()> {
        if self.schema_id != REPLY_SCHEMA
            || self.generation != hello.generation
            || self.sequence != sequence
            || self.input_artifact_digest != canonical::raw_digest(input)
        {
            return Err(Error::new(
                "cedar-runtime-reply-identity-mismatch",
                "schema, generation, sequence, or input digest differs",
            ));
        }
        match (&self.rust, &self.lean, &self.error) {
            (Some(rust), Some(lean), None) => {
                if rust.engine_id != "cedar-rust"
                    || lean.engine_id != "cedar-lean"
                    || rust.component_digest != hello.rust_component_digest
                    || lean.component_digest != hello.lean_component_digest
                    || !rust.outcome.agrees_with(&lean.outcome)
                {
                    return Err(Error::new(
                        "cedar-runtime-witness-mismatch",
                        "engine identity, artifact, or outcome differs",
                    ));
                }
            }
            (None, None, Some(_)) => {}
            _ => {
                return Err(Error::new(
                    "cedar-runtime-reply-malformed",
                    "reply must contain two witnesses or one error",
                ));
            }
        }
        Ok(())
    }
}

/// Connected client for a lifecycle-independent Runtime Host.
///
/// This type never starts or owns the Host process. An outer orchestrator must
/// create the endpoint and retain process/crash ownership.
#[cfg(unix)]
pub struct RuntimeClient {
    reader: std::io::BufReader<UnixStream>,
    writer: std::io::BufWriter<UnixStream>,
    hello: RuntimeHello,
    sequence: u64,
}

#[cfg(unix)]
impl RuntimeClient {
    pub fn connect(
        endpoint: &Path,
        runtime_artifact_digest: &str,
        rust_component_digest: &str,
        lean_component_digest: &str,
        timeout_ms: u64,
    ) -> Result<Self> {
        canonical::check_digest(runtime_artifact_digest)?;
        canonical::check_digest(rust_component_digest)?;
        canonical::check_digest(lean_component_digest)?;
        let stream = UnixStream::connect(endpoint).map_err(|error| {
            Error::new(
                "cedar-runtime-unavailable",
                format!("endpoint={}; {error}", endpoint.display()),
            )
        })?;
        let transport_timeout = Duration::from_millis(timeout_ms.saturating_add(1_000));
        stream
            .set_read_timeout(Some(transport_timeout))
            .and_then(|()| stream.set_write_timeout(Some(transport_timeout)))
            .map_err(|e| Error::new("cedar-runtime-transport-failed", e.to_string()))?;
        let writer = std::io::BufWriter::new(
            stream
                .try_clone()
                .map_err(|e| Error::new("cedar-runtime-transport-failed", e.to_string()))?,
        );
        let mut reader = std::io::BufReader::new(stream);
        let bytes = read_frame(&mut reader)?.ok_or_else(|| {
            Error::new(
                "cedar-runtime-handshake-missing",
                "host closed before its handshake",
            )
        })?;
        let hello: RuntimeHello = canonical::parse(&bytes)?;
        let generation = hex::decode(&hello.generation).map_err(|_| {
            Error::new(
                "cedar-runtime-handshake-invalid",
                "generation is not hexadecimal",
            )
        })?;
        if hello.schema_id != HOST_SCHEMA
            || generation.len() != 32
            || hello.timeout_ms != timeout_ms
            || hello.runtime_artifact_digest != runtime_artifact_digest
            || hello.rust_component_digest != rust_component_digest
            || hello.lean_component_digest != lean_component_digest
            || hello.rust_component_digest == hello.lean_component_digest
        {
            return Err(Error::new(
                "cedar-runtime-handshake-mismatch",
                "schema, generation, timeout, or admitted artifacts differ",
            ));
        }
        Ok(Self {
            reader,
            writer,
            hello,
            sequence: 0,
        })
    }

    pub fn hello(&self) -> &RuntimeHello {
        &self.hello
    }

    pub fn evaluate(&mut self, input: &[u8]) -> Result<(RuntimeWitness, RuntimeWitness)> {
        self.sequence = self.sequence.checked_add(1).ok_or_else(|| {
            Error::new("cedar-runtime-sequence-exhausted", "u64 sequence exhausted")
        })?;
        write_frame(&mut self.writer, input)?;
        let bytes = read_frame(&mut self.reader)?.ok_or_else(|| {
            Error::new(
                "cedar-runtime-reply-missing",
                "host closed before its reply",
            )
        })?;
        let reply: RuntimeReply = canonical::parse(&bytes)?;
        reply.validate(&self.hello, self.sequence, input)?;
        match (reply.rust, reply.lean, reply.error) {
            (Some(rust), Some(lean), None) => Ok((rust, lean)),
            (None, None, Some(error)) => Err(error),
            _ => unreachable!("RuntimeReply::validate established the reply shape"),
        }
    }
}

pub fn write_frame(mut writer: impl Write, bytes: &[u8]) -> Result<()> {
    if bytes.len() > MAX_FRAME_BYTES {
        return Err(Error::new(
            "cedar-runtime-frame-too-large",
            "frame exceeds 1 MiB",
        ));
    }
    let length = u32::try_from(bytes.len())
        .map_err(|_| Error::new("cedar-runtime-frame-too-large", "length is not u32"))?;
    writer
        .write_all(&length.to_be_bytes())
        .and_then(|()| writer.write_all(bytes))
        .and_then(|()| writer.flush())
        .map_err(|e| Error::new("cedar-runtime-transport-failed", e.to_string()))
}

pub fn read_frame(mut reader: impl Read) -> Result<Option<Vec<u8>>> {
    let mut length = [0_u8; 4];
    match reader.read(&mut length[..1]) {
        Ok(0) => return Ok(None),
        Ok(1) => {}
        Ok(_) => unreachable!(),
        Err(error) => {
            return Err(Error::new(
                "cedar-runtime-transport-failed",
                error.to_string(),
            ));
        }
    }
    reader
        .read_exact(&mut length[1..])
        .map_err(|e| Error::new("cedar-runtime-frame-truncated", e.to_string()))?;
    let length = u32::from_be_bytes(length) as usize;
    if length > MAX_FRAME_BYTES {
        return Err(Error::new(
            "cedar-runtime-frame-too-large",
            "frame exceeds 1 MiB",
        ));
    }
    let mut bytes = vec![0_u8; length];
    reader
        .read_exact(&mut bytes)
        .map_err(|e| Error::new("cedar-runtime-frame-truncated", e.to_string()))?;
    Ok(Some(bytes))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn framing_round_trips_and_fails_closed() {
        let mut encoded = Vec::new();
        write_frame(&mut encoded, b"abc").unwrap();
        assert_eq!(
            read_frame(encoded.as_slice()).unwrap(),
            Some(b"abc".to_vec())
        );
        assert_eq!(read_frame([].as_slice()).unwrap(), None);
        assert_eq!(
            read_frame([0, 0, 0, 2, 1].as_slice()).unwrap_err().code,
            "cedar-runtime-frame-truncated"
        );
        assert_eq!(
            write_frame(Vec::new(), &vec![0; MAX_FRAME_BYTES + 1])
                .unwrap_err()
                .code,
            "cedar-runtime-frame-too-large"
        );
    }
}
