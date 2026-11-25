# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later


set shell := ["bash", "-euo", "pipefail", "-c"]

# std/make uses this host's CPU count; explicit caller/CI budgets win.
export GERBIL_BUILD_CORES := env_var_or_default("GERBIL_BUILD_CORES", num_cpus())

# Test processes are bounded before any Scheme profile module can load. The
# ASP POO Testing profile remains the policy and receipt owner inside the
# process; this launch option is the fail-closed pre-import boundary.
gerbil_test_max_heap := env_var_or_default("GERBIL_TEST_MAX_HEAP", "2G")

gerbil_test_debug := env_var_or_default("GERBIL_TEST_DEBUG", "q")

gerbil_test_runtime_options := "-:max-heap=" + gerbil_test_max_heap + ",debug=" + gerbil_test_debug

runtime_c_output := agentic_ai_lab_gerbil_path + "/runtime-c"

runtime_c_extension := if os() == "macos" { "dylib" } else { "so" }

python_runtime_dir := "packages/python-runtime"

composition_lifecycle_tests := "tests/unit/test_composition_lifecycle_arrival.py tests/unit/test_composition_lifecycle_benchmark.py tests/unit/test_composition_lifecycle_workload.py"

cedar_workspace := "bindings/cedar-gerbil/Cargo.toml"

gerbil_homebrew_runtime := `gerbil_executable="$(command -v gerbil 2>/dev/null || true)"; if [ -n "$gerbil_executable" ] && realpath "$gerbil_executable" | grep -F '/opt/homebrew/Cellar/' >/dev/null; then printf true; else printf false; fi`

homebrew_openssl_prefix := `if command -v brew >/dev/null 2>&1; then brew --prefix openssl@3 2>/dev/null || true; fi`

homebrew_prefix := `if command -v brew >/dev/null 2>&1; then brew --prefix 2>/dev/null || true; fi`

darwin_openssl_prefix := env_var_or_default("OPENSSL_PREFIX", homebrew_openssl_prefix)

darwin_pkg_config_path := darwin_openssl_prefix + "/lib/pkgconfig:" + homebrew_prefix + "/opt/zlib/lib/pkgconfig:" + homebrew_prefix + "/opt/sqlite/lib/pkgconfig"

# Preserve the configured/user-selected compiler. For Homebrew Gerbil on
# Darwin, keep Nix SDK/header/library variables out of child builds and make
# GCC's collect2 resolve the Apple system linker instead of a Nix-provided ld.
# Restore only the explicit Homebrew OpenSSL include/library roots required by
# Gerbil's crypto modules; never inherit ambient CPATH or LIBRARY_PATH values.
# A Nix Gerbil runtime retains its own compiler and linker environment.
gerbil_darwin_env := if os() == "macos" { if gerbil_homebrew_runtime == "true" { "env -u SDKROOT -u DEVELOPER_DIR -u CPATH -u LIBRARY_PATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u MACOSX_DEPLOYMENT_TARGET -u DYLD_LIBRARY_PATH -u DYLD_FALLBACK_LIBRARY_PATH COMPILER_PATH=/usr/bin CPATH='" + darwin_openssl_prefix + "/include' LIBRARY_PATH='" + darwin_openssl_prefix + "/lib' PKG_CONFIG_PATH=\"" + darwin_pkg_config_path + "${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}\"" } else { "env" } } else { "env" }

agentic_ai_lab_gerbil_path := env_var_or_default("GERBIL_PATH", justfile_directory() + "/.gerbil")

agentic_ai_lab_library_path := env_var_or_default("GERBIL_LOADPATH", agentic_ai_lab_gerbil_path + "/lib")
lab_build_env := ("GERBIL_PATH=" + quote(agentic_ai_lab_gerbil_path) +
    " GERBIL_LOADPATH=" + quote(agentic_ai_lab_library_path) + " " + gerbil_darwin_env)

# Optional development packages must never rewrite the production package store.
agentic_ai_lab_dev_gerbil_path := justfile_directory() + "/dev/.gerbil"
agentic_ai_lab_dev_library_dir := agentic_ai_lab_dev_gerbil_path + "/lib"
agentic_ai_lab_dev_build_library_path := agentic_ai_lab_library_path + ":" + agentic_ai_lab_dev_library_dir
agentic_ai_lab_dev_library_path := if path_exists(agentic_ai_lab_dev_library_dir) == "true" { agentic_ai_lab_dev_build_library_path } else { agentic_ai_lab_library_path }

gerbil_test_heap_env := 'GAMBOPT="${GAMBOPT:+$GAMBOPT,}max-heap=' + gerbil_test_max_heap + ',debug=' + gerbil_test_debug + '"'
lab_test_env := (gerbil_test_heap_env +
    " GERBIL_PATH=" + quote(agentic_ai_lab_gerbil_path) +
    " GERBIL_LOADPATH=" + quote(agentic_ai_lab_dev_library_path + ":" + justfile_directory()) +
    " " + gerbil_darwin_env)
lab_test_fixtures := 'python3 packages/automation/gerbil_test_inputs.py --inputs "${AGENTIC_AI_LAB_OPENTOFU_TEST_INPUTS:-' + agentic_ai_lab_gerbil_path + '/test-inputs}"'
gerbil_test_timeout := "timeout --foreground --signal=TERM --kill-after=5s"
lab_test_file_budget := env_var_or_default("LAB_TEST_FILE_BUDGET", "120s")
lab_macos_qualification_timing := if os() == "macos" { env_var_or_default("LAB_MACOS_QUALIFICATION_TIMING", "") } else { "" }
lab_focused_test_deadline := if lab_macos_qualification_timing == "1" { "" } else { gerbil_test_timeout + " " + lab_test_file_budget }
lab_context_temporal_deadline := if lab_macos_qualification_timing == "1" { "" } else { "timeout --foreground --signal=TERM --kill-after=1s 45s" }

# gerbil.pkg is the parser revision authority.  Resolve source-owned fixtures
# through gxpkg's installed package root; never fall back to an arbitrary
# sibling checkout whose branch may differ from the declared dependency.
gerbil_parser_dir := agentic_ai_lab_gerbil_path + "/pkg/github.com/tao3k/gerbil-parser"

gerbil_parser_path := agentic_ai_lab_gerbil_path

gerbil_parser_library_path := agentic_ai_lab_library_path + ":" + gerbil_parser_dir + ":" + contribution_source_root + "/lambda-episteme:" + justfile_directory()

aitia_ffi_library := justfile_directory() + "/.gerbil/runtime/libagentic_ai_lab_aitia.dylib"

aitia_python_dir := contribution_source_root + "/lambda-aitia/bindings/python"

contribution_test_path := justfile_directory() + "/.gerbil/contributions/lambda-episteme/module-test"

contribution_test_library_path := contribution_test_path + "/lib"

contribution_source_root := justfile_directory() + "/packages"

fhir_validator_jar := env_var_or_default("FHIR_VALIDATOR_JAR", "")

lean_proof_dir := justfile_directory() + "/packages/proofs/lean"

temporal_poo_proof_dir := justfile_directory() + "/packages/proofs/lean-poo"
