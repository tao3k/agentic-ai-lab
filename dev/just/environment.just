# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later


set shell := ["bash", "-euo", "pipefail", "-c"]

# Keep the default cold build within a bounded compiler memory budget.
export GERBIL_BUILD_CORES := env_var_or_default("GERBIL_BUILD_CORES", "2")

# Test processes are bounded before any Scheme profile module can load. The
# ASP POO Testing profile remains the policy and receipt owner inside the
# process; this launch option is the fail-closed pre-import boundary.
gerbil_test_max_heap := env_var_or_default("GERBIL_TEST_MAX_HEAP", "1G")

gerbil_test_debug := env_var_or_default("GERBIL_TEST_DEBUG", "q")

gerbil_test_runtime_options := "-:max-heap=" + gerbil_test_max_heap + ",debug=" + gerbil_test_debug

bazel := env_var_or_default("BAZEL", "bazelisk")

gerbil_compile := "//:compile"

gerbil_dev_compile := "//:dev_compile"

gerbil_capability_tests := "//t/qualification/gerbil-bazel:tests"

module_system_owner_tests := "//t/qualification/module-system:owner_map_tests"

runtime_c_library := "//bindings/runtime-c:runtime_c_library"

runtime_c_tests := "//bindings/runtime-c:runtime_c_tests"

runtime_c_sanitizer_tests := "//bindings/runtime-c:runtime_c_sanitizer_tests"

runtime_c_leak_test := "//bindings/runtime-c:runtime_c_leak_test"

bundle_v1_library := "//bindings/runtime-c/bundle-v1:bundle_v1"

bundle_v1_tests := "//bindings/runtime-c/bundle-v1:bundle_v1_tests"

gerbil_toolchain_type := "@gerbil_bazel//gerbil:toolchain_type"

python_runtime_dir := "packages/python-runtime"

python_runtime_test_environment := "//:python_runtime_test_environment"

composition_lifecycle_tests := "tests/unit/test_composition_lifecycle_arrival.py tests/unit/test_composition_lifecycle_benchmark.py tests/unit/test_composition_lifecycle_workload.py"

cedar_workspace := "bindings/cedar-gerbil/Cargo.toml"

gerbil_homebrew_runtime := `gerbil_executable="$(command -v gerbil 2>/dev/null || true)"; if [ -n "$gerbil_executable" ] && realpath "$gerbil_executable" | grep -F '/opt/homebrew/Cellar/' >/dev/null; then printf true; else printf false; fi`

homebrew_openssl_prefix := `if command -v brew >/dev/null 2>&1; then brew --prefix openssl@3 2>/dev/null || true; fi`

darwin_openssl_prefix := env_var_or_default("OPENSSL_PREFIX", homebrew_openssl_prefix)

# Preserve the configured/user-selected compiler. For Homebrew Gerbil on
# Darwin, keep Nix SDK/header/library variables out of child builds and make
# GCC's collect2 resolve the Apple system linker instead of a Nix-provided ld.
# Restore only the explicit Homebrew OpenSSL include/library roots required by
# Gerbil's crypto modules; never inherit ambient CPATH or LIBRARY_PATH values.
# A Nix Gerbil runtime retains its own compiler and linker environment.
gerbil_darwin_env := if os() == "macos" { if gerbil_homebrew_runtime == "true" { "env -u SDKROOT -u DEVELOPER_DIR -u CPATH -u LIBRARY_PATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u MACOSX_DEPLOYMENT_TARGET -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH COMPILER_PATH=/usr/bin CPATH='" + darwin_openssl_prefix + "/include' LIBRARY_PATH='" + darwin_openssl_prefix + "/lib'" } else { "env" } } else { "env" }

agentic_ai_lab_gerbil_path := env_var_or_default("GERBIL_PATH", justfile_directory() + "/.gerbil")

agentic_ai_lab_library_path := env_var_or_default("GERBIL_LOADPATH", agentic_ai_lab_gerbil_path + "/lib")

# Optional development packages must never rewrite the production package store.
agentic_ai_lab_dev_gerbil_path := justfile_directory() + "/dev/.gerbil"
agentic_ai_lab_dev_library_path := agentic_ai_lab_library_path + ":" + agentic_ai_lab_dev_gerbil_path + "/lib"

# gerbil.pkg is the parser revision authority.  Resolve source-owned fixtures
# through gxpkg's installed package root; never fall back to an arbitrary
# sibling checkout whose branch may differ from the declared dependency.
gerbil_parser_dir := agentic_ai_lab_gerbil_path + "/pkg/github.com/tao3k/gerbil-parser"

gerbil_parser_path := agentic_ai_lab_gerbil_path

gerbil_parser_library_path := agentic_ai_lab_library_path + ":" + gerbil_parser_dir + ":" + contribution_source_root + "/lambda-episteme:" + justfile_directory()

aitia_native_library := justfile_directory() + "/.gerbil/native/libagentic_ai_lab_aitia.dylib"

aitia_python_dir := contribution_source_root + "/lambda-aitia/bindings/python"

contribution_test_path := justfile_directory() + "/.gerbil/contributions/lambda-episteme/module-test"

contribution_test_library_path := contribution_test_path + "/lib"

contribution_source_root := justfile_directory() + "/packages"

fhir_validator_jar := env_var_or_default("FHIR_VALIDATOR_JAR", "")

lean_proof_dir := justfile_directory() + "/packages/proofs/lean"

temporal_poo_proof_dir := justfile_directory() + "/packages/proofs/lean-poo"
