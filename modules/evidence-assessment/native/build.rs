//! Freeze the actual application and resolved rule-engine sources into the Python artifact.
use sha2::{Digest, Sha256};
use std::{collections::BTreeMap, env, fs, path::Path, process::Command};
fn collect(root: &Path, path: &Path, output: &mut BTreeMap<String, String>) {
    if path.is_dir() {
        let mut entries = fs::read_dir(path)
            .unwrap()
            .map(|e| e.unwrap().path())
            .collect::<Vec<_>>();
        entries.sort();
        for entry in entries {
            collect(root, &entry, output);
        }
    } else if path.extension().is_some_and(|e| e == "rs" || e == "ss")
        || path
            .file_name()
            .is_some_and(|n| n == "Cargo.toml" || n == "Cargo.lock")
    {
        println!("cargo:rerun-if-changed={}", path.display());
        output.insert(
            path.strip_prefix(root)
                .unwrap()
                .to_string_lossy()
                .into_owned(),
            format!("{:x}", Sha256::digest(fs::read(path).unwrap())),
        );
    }
}
fn main() {
    let package = std::path::PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap());
    let root = package.join("../../..").canonicalize().unwrap();
    let mut inputs = BTreeMap::new();
    for relative in [
        "modules/evidence-assessment/native/src",
        "modules/evidence-assessment/native/build.rs",
        "modules/evidence-assessment/native/Cargo.toml",
        "modules/evidence-assessment/native/Cargo.lock",
        "modules/ai-agentic-context/clues/native",
        "modules/ai-agentic-context/interaction/native",
        "modules/temporal-causality/trajectory/native",
        "packages/python-runtime/src/agentic_ai_lab_runtime/reasoning_rules",
    ] {
        collect(&root, &root.join(relative), &mut inputs);
    }
    let metadata = Command::new(env::var_os("CARGO").unwrap())
        .args(["metadata", "--locked", "--offline", "--format-version", "1",
            "--filter-platform", &env::var("TARGET").expect("Cargo target triple")])
        .current_dir(&package)
        .output()
        .expect("resolved dependency inventory");
    assert!(
        metadata.status.success(),
        "cargo metadata failed: {}",
        String::from_utf8_lossy(&metadata.stderr)
    );
    let metadata: serde_json::Value = serde_json::from_slice(&metadata.stdout).unwrap();
    let dependencies = metadata["packages"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|p| p["name"] == "gerbil-ascent")
        .collect::<Vec<_>>();
    assert_eq!(
        dependencies.len(),
        1,
        "exactly one ASCENT producer required"
    );
    let producer = dependencies[0];
    let producer_manifest = Path::new(producer["manifest_path"].as_str().unwrap());
    let producer_root = producer_manifest.parent().unwrap();
    let mut producer_inputs = BTreeMap::new();
    collect(
        producer_root,
        &producer_root.join("src"),
        &mut producer_inputs,
    );
    collect(producer_root, producer_manifest, &mut producer_inputs);
    let receipt = serde_json::json!({"schema":"agentic-ai-lab.reasoning-build.v1","sourceInputs":inputs,
        "producerSource":producer["source"],"producerInputs":producer_inputs});
    fs::write(
        Path::new(&env::var_os("OUT_DIR").unwrap()).join("reasoning-build.json"),
        serde_json::to_vec(&receipt).unwrap(),
    )
    .unwrap();
}
