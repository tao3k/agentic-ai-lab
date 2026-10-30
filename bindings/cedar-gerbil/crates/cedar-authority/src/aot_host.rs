// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! Runtime Host logic embedded into the Lean-linked AOT executable.

use crate::runtime::{
    HOST_READY_SCHEMA, HOST_SCHEMA, REPLY_SCHEMA, RuntimeHello, RuntimeReady, RuntimeReply,
    RuntimeWitness, read_frame, write_frame,
};
use crate::wire::{CEDAR_VERSION, LEAN_REVISION, Outcome, evaluate_rust, validate_native_input};
use crate::{Error, Result, canonical};
use serde::{Deserialize, Serialize};
use std::ffi::{CStr, c_char, c_int};
use std::fs::File;
use std::io::{BufReader, BufWriter, Read, Seek, SeekFrom, Write};
use std::os::unix::{fs::PermissionsExt, net::UnixListener};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

const INPUT_LIMIT: u64 = canonical::MAX_PROJECTION_BYTES as u64;
const OUTPUT_LIMIT: u64 = canonical::MAX_PROJECTION_BYTES as u64;

unsafe extern "C" {
    fn agentic_ai_lab_cedar_lean_authorize(
        bytes: *const u8,
        length: usize,
        output: *mut *mut c_char,
        error: *mut *mut c_char,
    ) -> c_int;
    fn agentic_ai_lab_cedar_lean_string_free(value: *mut c_char);
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct WorkerReply {
    outcome: Option<Outcome>,
    error: Option<Error>,
}

struct ChildGuard(Child);

impl Drop for ChildGuard {
    fn drop(&mut self) {
        // Only a positive, still-running observation authorizes signaling.
        if matches!(self.0.try_wait(), Ok(None)) {
            let _ = self.0.kill();
            let _ = self.0.wait();
        }
    }
}

struct SocketGuard(PathBuf);

impl Drop for SocketGuard {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.0);
    }
}

/// C entry point linked into the final Lean AOT Runtime Host.
///
/// # Safety
/// `argv` must be the ordinary process argument array for `argc` entries.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn agentic_ai_lab_cedar_runtime_host_main(
    argc: c_int,
    argv: *const *const c_char,
) -> c_int {
    let run = std::panic::catch_unwind(|| {
        if argc < 1 || argv.is_null() {
            return Err(Error::new(
                "cedar-runtime-arguments-invalid",
                "missing process arguments",
            ));
        }
        let mut args = Vec::with_capacity(argc as usize);
        for index in 0..argc as usize {
            // SAFETY: upheld by this exported function's contract.
            let pointer = unsafe { *argv.add(index) };
            if pointer.is_null() {
                return Err(Error::new(
                    "cedar-runtime-arguments-invalid",
                    "null process argument",
                ));
            }
            // SAFETY: process arguments are NUL-terminated C strings.
            let value = unsafe { CStr::from_ptr(pointer) }
                .to_str()
                .map_err(|_| {
                    Error::new("cedar-runtime-arguments-invalid", "argument is not UTF-8")
                })?
                .to_owned();
            args.push(value);
        }
        dispatch(&args)
    });
    match run {
        Ok(Ok(())) => 0,
        Ok(Err(error)) => {
            eprintln!("{error}");
            2
        }
        Err(_) => {
            eprintln!("cedar-runtime-panic: Rust Runtime Host panicked");
            70
        }
    }
}

fn dispatch(args: &[String]) -> Result<()> {
    match args.get(1).map(String::as_str) {
        Some("serve-unix") => serve(args),
        Some("__rust-worker") => worker(args, "cedar-rust"),
        Some("__lean-worker") => worker(args, "cedar-lean"),
        _ => Err(Error::new(
            "cedar-runtime-arguments-invalid",
            "usage: cedarRuntimeHost serve-unix <socket> <runtime-digest> <rust-component-digest> <lean-component-digest> <timeout-ms>",
        )),
    }
}

fn serve(args: &[String]) -> Result<()> {
    if args.len() != 7 {
        return Err(Error::new(
            "cedar-runtime-arguments-invalid",
            "serve-unix requires exactly five arguments",
        ));
    }
    let endpoint = PathBuf::from(&args[2]);
    for digest in [&args[3], &args[4], &args[5]] {
        canonical::check_digest(digest)?;
    }
    if args[4] == args[5] {
        return Err(Error::new(
            "same-engine-artifact",
            "dual execution requires distinct component identities",
        ));
    }
    let expected_rust_component = canonical::raw_digest(CEDAR_VERSION.as_bytes());
    let expected_lean_component = canonical::raw_digest(LEAN_REVISION.as_bytes());
    if args[4] != expected_rust_component || args[5] != expected_lean_component {
        return Err(Error::new(
            "cedar-runtime-component-mismatch",
            "component identities differ from the linked Cedar and Lean revisions",
        ));
    }
    let timeout_ms: u64 = args[6]
        .parse()
        .map_err(|_| Error::new("cedar-runtime-budget-invalid", "timeout is not an integer"))?;
    if !(1..=10_000).contains(&timeout_ms) {
        return Err(Error::new(
            "cedar-runtime-budget-invalid",
            "timeout must be 1..10000ms",
        ));
    }
    let executable = std::env::current_exe()
        .map_err(|e| Error::new("cedar-runtime-artifact-unavailable", e.to_string()))?;
    let actual_runtime_digest = canonical::raw_digest(
        &std::fs::read(&executable)
            .map_err(|e| Error::new("cedar-runtime-artifact-unavailable", e.to_string()))?,
    );
    if actual_runtime_digest != args[3] {
        return Err(Error::new(
            "cedar-runtime-artifact-mismatch",
            "running AOT Host bytes differ from admitted digest",
        ));
    }
    let pinned_directory = tempfile::tempdir()
        .map_err(|e| Error::new("cedar-runtime-artifact-unavailable", e.to_string()))?;
    let pinned_executable = pinned_directory.path().join("runtime-host");
    std::fs::copy(&executable, &pinned_executable)
        .map_err(|e| Error::new("cedar-runtime-artifact-unavailable", e.to_string()))?;
    std::fs::set_permissions(&pinned_executable, std::fs::Permissions::from_mode(0o500))
        .map_err(|e| Error::new("cedar-runtime-artifact-unavailable", e.to_string()))?;
    if canonical::raw_digest(
        &std::fs::read(&pinned_executable)
            .map_err(|e| Error::new("cedar-runtime-artifact-unavailable", e.to_string()))?,
    ) != actual_runtime_digest
    {
        return Err(Error::new(
            "cedar-runtime-artifact-mismatch",
            "private AOT Host copy differs from admitted bytes",
        ));
    }
    let listener = UnixListener::bind(&endpoint).map_err(|error| {
        Error::new(
            "cedar-runtime-bind-failed",
            format!("endpoint={}; {error}", endpoint.display()),
        )
    })?;
    let _socket = SocketGuard(endpoint.clone());
    std::fs::set_permissions(&endpoint, std::fs::Permissions::from_mode(0o600))
        .map_err(|e| Error::new("cedar-runtime-bind-failed", e.to_string()))?;
    let mut generation_bytes = [0_u8; 32];
    getrandom::fill(&mut generation_bytes)
        .map_err(|e| Error::new("cedar-runtime-entropy-unavailable", e.to_string()))?;
    let hello = RuntimeHello {
        schema_id: HOST_SCHEMA.into(),
        generation: hex::encode(generation_bytes),
        timeout_ms,
        runtime_artifact_digest: actual_runtime_digest,
        rust_component_digest: args[4].clone(),
        lean_component_digest: args[5].clone(),
    };
    let ready = RuntimeReady {
        schema_id: HOST_READY_SCHEMA.into(),
        endpoint: endpoint.to_string_lossy().into_owned(),
    };
    let mut readiness = std::io::stdout().lock();
    serde_json::to_writer(&mut readiness, &ready)
        .map_err(|error| Error::new("cedar-runtime-ready-failed", error.to_string()))?;
    readiness
        .write_all(b"\n")
        .and_then(|()| readiness.flush())
        .map_err(|error| Error::new("cedar-runtime-ready-failed", error.to_string()))?;
    drop(readiness);
    let (stream, _) = listener
        .accept()
        .map_err(|e| Error::new("cedar-runtime-accept-failed", e.to_string()))?;
    let writer = stream
        .try_clone()
        .map_err(|e| Error::new("cedar-runtime-transport-failed", e.to_string()))?;
    serve_session(
        BufReader::new(stream),
        BufWriter::new(writer),
        &hello,
        &pinned_executable,
    )
}

fn serve_session(
    mut input: impl Read,
    mut output: impl Write,
    hello: &RuntimeHello,
    executable: &Path,
) -> Result<()> {
    write_json(&mut output, hello)?;
    let mut sequence = 0_u64;
    while let Some(bytes) = read_frame(&mut input)? {
        sequence = sequence.checked_add(1).ok_or_else(|| {
            Error::new("cedar-runtime-sequence-exhausted", "u64 sequence exhausted")
        })?;
        let digest = canonical::raw_digest(&bytes);
        let reply = evaluate(hello, sequence, digest, &bytes, executable);
        write_json(&mut output, &reply)?;
    }
    Ok(())
}

fn evaluate(
    hello: &RuntimeHello,
    sequence: u64,
    input_artifact_digest: String,
    bytes: &[u8],
    executable: &Path,
) -> RuntimeReply {
    let result = (|| {
        validate_native_input(bytes)?;
        let mut input = tempfile::NamedTempFile::new()
            .map_err(|e| Error::new("cedar-input-io-failed", e.to_string()))?;
        input
            .write_all(bytes)
            .and_then(|()| input.flush())
            .map_err(|e| Error::new("cedar-input-io-failed", e.to_string()))?;
        let deadline = Instant::now() + Duration::from_millis(hello.timeout_ms);
        let rust = run_worker(executable, "__rust-worker", input.path(), deadline)?;
        let lean = run_worker(executable, "__lean-worker", input.path(), deadline)?;
        if !rust.outcome.agrees_with(&lean.outcome) {
            return Err(Error::new(
                "cedar-engine-disagreement",
                format!("rust={:?}; lean={:?}", rust.outcome, lean.outcome),
            ));
        }
        Ok((rust, lean))
    })();
    match result {
        Ok((rust, lean)) => RuntimeReply {
            schema_id: REPLY_SCHEMA.into(),
            generation: hello.generation.clone(),
            sequence,
            input_artifact_digest,
            rust: Some(RuntimeWitness {
                engine_id: "cedar-rust".into(),
                component_digest: hello.rust_component_digest.clone(),
                elapsed_ms: rust.elapsed_ms,
                outcome: rust.outcome,
            }),
            lean: Some(RuntimeWitness {
                engine_id: "cedar-lean".into(),
                component_digest: hello.lean_component_digest.clone(),
                elapsed_ms: lean.elapsed_ms,
                outcome: lean.outcome,
            }),
            error: None,
        },
        Err(error) => RuntimeReply {
            schema_id: REPLY_SCHEMA.into(),
            generation: hello.generation.clone(),
            sequence,
            input_artifact_digest,
            rust: None,
            lean: None,
            error: Some(error),
        },
    }
}

struct WorkerExecution {
    outcome: Outcome,
    elapsed_ms: u64,
}

fn run_worker(
    executable: &Path,
    mode: &str,
    input: &Path,
    deadline: Instant,
) -> Result<WorkerExecution> {
    let started = Instant::now();
    if started >= deadline {
        return Err(Error::new("cedar-engine-timeout", format!("engine={mode}")));
    }
    let stdout =
        tempfile::tempfile().map_err(|e| Error::new("cedar-engine-io-failed", e.to_string()))?;
    let stderr =
        tempfile::tempfile().map_err(|e| Error::new("cedar-engine-io-failed", e.to_string()))?;
    let mut child = ChildGuard(
        Command::new(executable)
            .args([
                mode,
                input.to_str().ok_or_else(|| {
                    Error::new("cedar-input-io-failed", "input path is not UTF-8")
                })?,
            ])
            .stdin(Stdio::null())
            .stdout(stdout.try_clone().map_err(io_error)?)
            .stderr(stderr.try_clone().map_err(io_error)?)
            .spawn()
            .map_err(|e| Error::new("cedar-engine-unavailable", format!("engine={mode}; {e}")))?,
    );
    let status = loop {
        if Instant::now() >= deadline {
            return Err(Error::new(
                "cedar-engine-timeout",
                format!(
                    "engine={mode}; elapsed_ms={}",
                    started.elapsed().as_millis()
                ),
            ));
        }
        if stdout.metadata().map_err(io_error)?.len() + stderr.metadata().map_err(io_error)?.len()
            > OUTPUT_LIMIT
        {
            return Err(Error::new("cedar-engine-output-budget-exceeded", mode));
        }
        if let Some(status) = child.0.try_wait().map_err(io_error)? {
            break status;
        }
        std::thread::sleep(Duration::from_millis(2));
    };
    if !status.success() {
        return Err(Error::new(
            "cedar-engine-crash",
            format!(
                "engine={mode}; status={status}; stderr={}",
                read_output(stderr)?
            ),
        ));
    }
    let reply: WorkerReply = canonical::parse(read_output(stdout)?.as_bytes())?;
    match (reply.outcome, reply.error) {
        (Some(mut outcome), None) => {
            let (identity, revision) = if mode == "__rust-worker" {
                ("cedar-rust", CEDAR_VERSION)
            } else {
                ("cedar-lean", LEAN_REVISION)
            };
            outcome.validate(identity, revision)?;
            Ok(WorkerExecution {
                outcome,
                elapsed_ms: started.elapsed().as_millis() as u64,
            })
        }
        (None, Some(error)) => Err(error),
        _ => Err(Error::new("cedar-engine-malformed-projection", mode)),
    }
}

fn worker(args: &[String], identity: &str) -> Result<()> {
    if args.len() != 3 {
        return Err(Error::new(
            "cedar-runtime-worker-arguments-invalid",
            identity,
        ));
    }
    let bytes = read_input(Path::new(&args[2]))?;
    let result = if identity == "cedar-rust" {
        evaluate_rust(&bytes)
    } else {
        evaluate_lean(&bytes)
    };
    let reply = match result {
        Ok(outcome) => WorkerReply {
            outcome: Some(outcome),
            error: None,
        },
        Err(error) => WorkerReply {
            outcome: None,
            error: Some(error),
        },
    };
    let stdout = std::io::stdout();
    let mut output = BufWriter::new(stdout.lock());
    serde_json::to_writer(&mut output, &reply)
        .map_err(|e| Error::new("cedar-engine-output-failed", e.to_string()))?;
    output
        .flush()
        .map_err(|e| Error::new("cedar-engine-output-failed", e.to_string()))?;
    Ok(())
}

fn evaluate_lean(bytes: &[u8]) -> Result<Outcome> {
    let mut output = std::ptr::null_mut();
    let mut error = std::ptr::null_mut();
    // SAFETY: the C bridge copies the input and returns separately allocated,
    // NUL-terminated strings owned by `agentic_ai_lab_cedar_lean_string_free`.
    let status = unsafe {
        agentic_ai_lab_cedar_lean_authorize(bytes.as_ptr(), bytes.len(), &mut output, &mut error)
    };
    let text = unsafe {
        let pointer = if status == 0 { output } else { error };
        if pointer.is_null() {
            return Err(Error::new(
                "cedar-lean-ffi-invalid",
                "Lean returned no result string",
            ));
        }
        let value = CStr::from_ptr(pointer).to_string_lossy().into_owned();
        agentic_ai_lab_cedar_lean_string_free(pointer);
        value
    };
    if status != 0 {
        return Err(Error::new("cedar-lean-evaluation-failed", text));
    }
    canonical::parse(text.as_bytes())
}

fn read_input(path: &Path) -> Result<Vec<u8>> {
    let file = File::open(path).map_err(io_error)?;
    if file.metadata().map_err(io_error)?.len() > INPUT_LIMIT {
        return Err(Error::new("cedar-input-too-large", "input exceeds 1 MiB"));
    }
    let mut bytes = Vec::new();
    file.take(INPUT_LIMIT + 1)
        .read_to_end(&mut bytes)
        .map_err(io_error)?;
    if bytes.len() as u64 > INPUT_LIMIT {
        return Err(Error::new("cedar-input-too-large", "input exceeds 1 MiB"));
    }
    Ok(bytes)
}

fn read_output(mut file: File) -> Result<String> {
    file.seek(SeekFrom::Start(0)).map_err(io_error)?;
    let mut bytes = Vec::new();
    file.take(OUTPUT_LIMIT + 1)
        .read_to_end(&mut bytes)
        .map_err(io_error)?;
    if bytes.len() as u64 > OUTPUT_LIMIT {
        return Err(Error::new(
            "cedar-engine-output-budget-exceeded",
            "output exceeds 1 MiB",
        ));
    }
    String::from_utf8(bytes)
        .map_err(|e| Error::new("cedar-engine-malformed-projection", e.to_string()))
}

fn write_json(writer: &mut impl Write, value: &impl Serialize) -> Result<()> {
    let bytes = serde_json::to_vec(value)
        .map_err(|e| Error::new("cedar-runtime-reply-invalid", e.to_string()))?;
    write_frame(writer, &bytes)
}

fn io_error(error: std::io::Error) -> Error {
    Error::new("cedar-engine-io-failed", error.to_string())
}
