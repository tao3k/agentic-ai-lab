// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

use std::{
    env,
    ffi::{OsStr, OsString},
    path::{Path, PathBuf},
    process::Command,
};

fn gerbil_load_path(stage: &Path) -> OsString {
    let mut paths = vec![stage.join("lib")];
    if let Some(inherited) = env::var_os("GERBIL_LOADPATH") {
        paths.extend(env::split_paths(&inherited));
    }
    if let Some(inherited_prefix) = env::var_os("GERBIL_PATH") {
        paths.push(PathBuf::from(inherited_prefix).join("lib"));
    }
    env::join_paths(paths).expect("compose GERBIL_LOADPATH")
}

fn run_gxi(
    gxi: &OsStr,
    script: &Path,
    argument: &OsStr,
    directory: &Path,
    stage: &Path,
    load_path: &OsStr,
    operation: &str,
) {
    let status = Command::new(gxi)
        .arg(script)
        .arg(argument)
        .current_dir(directory)
        .env("GERBIL_PATH", stage)
        .env("GERBIL_LOADPATH", load_path)
        .status()
        .unwrap_or_else(|error| panic!("{operation}: {error}"));
    assert!(status.success(), "{operation} failed: {status}");
}

fn main() {
    println!("cargo:rerun-if-changed=build.ss");
    println!("cargo:rerun-if-changed=scheme/conformance-build-runtime.ss");
    println!("cargo:rerun-if-changed=../../../../gerbil.pkg");
    println!("cargo:rerun-if-changed=scheme/conformance.ss");
    println!("cargo:rerun-if-changed=../../../../core/object-family/syntax.ss");
    println!("cargo:rerun-if-changed=../../../../modules/authorization/providers/cedar/objects.ss");
    println!("cargo:rerun-if-env-changed=GERBIL_GXI");
    println!("cargo:rerun-if-env-changed=GERBIL_GSC");
    println!("cargo:rerun-if-env-changed=GERBIL_PATH");
    println!("cargo:rerun-if-env-changed=GERBIL_LOADPATH");
    if env::var_os("CARGO_FEATURE_CONFORMANCE").is_none() {
        return;
    }
    let root = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap());
    let output = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    let gxi = env::var_os("GERBIL_GXI").unwrap_or_else(|| "gxi".into());
    let gsc =
        env::var_os("GERBIL_GSC").expect("GERBIL_GSC must select the installed Gambit compiler");
    let bridge = gerbil_scheme_native_build::source_workspace();
    let bridge_build = bridge.join("build.ss");
    let bridge_program_build = bridge.join("scheme/program-build.ss");
    let bridge_native = bridge.join("scheme/native.ss");
    println!("cargo:rerun-if-changed={}", bridge_build.display());
    println!("cargo:rerun-if-changed={}", bridge_program_build.display());
    println!("cargo:rerun-if-changed={}", bridge_native.display());

    let stage = output.join("gerbil");
    let load_path = gerbil_load_path(&stage);
    run_gxi(
        &gxi,
        &bridge_build,
        OsStr::new("compile"),
        &bridge,
        &stage,
        &load_path,
        "compile Cargo-resolved gerbil-scheme-rust modules",
    );
    run_gxi(
        &gxi,
        &root.join("build.ss"),
        output.as_os_str(),
        &root,
        &stage,
        &load_path,
        "build canonical Cedar/Gerbil conformance graph",
    );
    let receipt = gerbil_scheme_native_build::build_program_archive(
        gerbil_scheme_native_build::ProgramArchiveRequest {
            manifest: &output.join("program.json"),
            gsc: &PathBuf::from(gsc),
            archive_name: "agentic_ai_lab_cedar_program",
            linker_name: "agentic_ai_lab_cedar_linker",
            out_dir: &output,
        },
    )
    .expect("build native POO conformance graph");
    for directive in receipt.cargo_directives {
        println!("{}", directive.line());
    }
}
