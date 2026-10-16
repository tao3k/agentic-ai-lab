# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

set shell := ["bash", "-euo", "pipefail", "-c"]

export GERBIL_BUILD_CORES := env_var_or_default("GERBIL_BUILD_CORES", `getconf _NPROCESSORS_ONLN`)

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
aitia_native_library := justfile_directory() + "/.gerbil/native/libpoo_flow_aitia.dylib"
aitia_python_dir := contribution_source_root + "/lambda-aitia/bindings/python"
python_runtime_test_environment := "//:python_runtime_test_environment"
composition_lifecycle_tests := "tests/unit/test_composition_lifecycle_arrival.py tests/unit/test_composition_lifecycle_benchmark.py tests/unit/test_composition_lifecycle_workload.py"
cedar_workspace := "bindings/cedar-gerbil/Cargo.toml"
contribution_test_path := justfile_directory() + "/.gerbil/contributions/lambda-episteme/module-test"
contribution_test_library_path := contribution_test_path + "/lib"
contribution_source_root := justfile_directory() + "/packages"
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
poo_flow_gerbil_path := env_var_or_default("GERBIL_PATH", justfile_directory() + "/.gerbil")
poo_flow_library_path := env_var_or_default("GERBIL_LOADPATH", poo_flow_gerbil_path + "/lib")
# gerbil.pkg is the parser revision authority.  Resolve source-owned fixtures
# through gxpkg's installed package root; never fall back to an arbitrary
# sibling checkout whose branch may differ from the declared dependency.
gerbil_parser_dir := poo_flow_gerbil_path + "/pkg/github.com/tao3k/gerbil-parser"
gerbil_parser_path := poo_flow_gerbil_path
gerbil_parser_library_path := poo_flow_library_path + ":" + gerbil_parser_dir + ":" + contribution_source_root + "/lambda-episteme:" + justfile_directory()
fhir_validator_jar := env_var_or_default("FHIR_VALIDATOR_JAR", "")
lean_proof_dir := justfile_directory() + "/packages/proofs/lean"
temporal_poo_proof_dir := justfile_directory() + "/packages/proofs/lean-poo"

# Show the maintained developer entrypoints.
[group('discovery')]
default:
    @just --list

# Query the complete Bazel target graph without executing actions.
[group('discovery')]
query:
    {{ bazel }} query //...

# Resolve and build the canonical Scheme project through build.ss.
[group('build')]
build:
    just build-core
    GERBIL_BUILD_VERBOSE=1 {{ gerbil_darwin_env }} gerbil build

# Compile the pinned local Core, replacing any transitive bootstrap artifacts.
# Cleaning is confined to the Core package; dependency source checkouts stay intact.
[group('build')]
build-core:
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ poo_flow_gerbil_path }}" GERBIL_LOADPATH="{{ poo_flow_library_path }}" GERBIL_BUILD_VERBOSE=1 {{ gerbil_darwin_env }} gerbil clean
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ poo_flow_gerbil_path }}" GERBIL_LOADPATH="{{ poo_flow_library_path }}" GERBIL_BUILD_VERBOSE=1 {{ gerbil_darwin_env }} gerbil build

# Build one packaged contribution inside POO Flow's package environment.
[group('build')]
build-contribute contribution="lambda-episteme":
    case "{{ contribution }}" in lambda-episteme|lambda-aitia) ;; *) echo "unsupported contribution: {{ contribution }}" >&2; exit 64 ;; esac
    cd "{{ contribution_source_root }}/{{ contribution }}" && GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ justfile_directory() }}:{{ poo_flow_library_path }}" exec {{ gerbil_darwin_env }} gerbil build </dev/null

# Clean one contribution through its native gxpkg package entry.
[group('build')]
clean-contribute contribution="lambda-episteme":
    case "{{ contribution }}" in lambda-episteme|lambda-aitia) ;; *) echo "unsupported contribution: {{ contribution }}" >&2; exit 64 ;; esac
    cd "{{ contribution_source_root }}/{{ contribution }}" && GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} gerbil clean

# Execute one contribution-owned t/<module-name>/ tree directly with gxtest.
[group('test')]
test-contribute contribution="lambda-aitia" module="sdlc":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ contribution }}" in lambda-episteme|lambda-aitia) ;; *) echo "unsupported contribution: {{ contribution }}" >&2; exit 64 ;; esac
    test_root="$(mktemp -d "${TMPDIR:-/tmp}/poo-flow-{{ contribution }}-module-test.XXXXXX")"
    trap 'find "$test_root" -depth -delete' EXIT
    if test "{{ contribution }}" = "lambda-aitia"; then
        cd "{{ contribution_source_root }}/lambda-aitia"
        runner="./run-test.ss"
        test_directory="t/{{ module }}"
    else
        runner="./run-contribute-test.ss"
        test_directory="packages/{{ contribution }}/t/{{ module }}"
    fi
    test -d "$test_directory"
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="$test_root" GERBIL_LOADPATH="{{ contribution_source_root }}/{{ contribution }}:{{ justfile_directory() }}:$test_root/lib:{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} "$runner" "$test_directory"

# Replay a previously compiled exact test under the opt-in native heap monitor.
[group('test')]
observe-contribute-import-memory contribution="lambda-aitia" module="sdlc" test_file="unit/nasa-certification-test.ss":
    case "{{ contribution }}" in lambda-episteme|lambda-aitia) ;; *) echo "unsupported contribution: {{ contribution }}" >&2; exit 64 ;; esac
    test -f "packages/{{ contribution }}/t/{{ module }}/{{ test_file }}"
    echo "[poo-flow-observability] phase=import-observer-start owner={{ contribution }} module={{ module }} test={{ test_file }} budget=15s"
    GERBIL_PATH="{{ justfile_directory() }}/.gerbil/contributions/{{ contribution }}/atomic-test" GERBIL_LOADPATH="{{ justfile_directory() }}/.gerbil/contributions/{{ contribution }}/atomic-test/lib:{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=2s 15s gxi {{ gerbil_test_runtime_options }} ./observe-contribute-import.ss "{{ contribution }}" "{{ module }}" "{{ test_file }}"

# Execute one exact test file. Source admission belongs to the native gxtest
# lifecycle and is enabled declaratively by its POO Testing Profile.
[group('test')]
test-contribute-atomic contribution="lambda-aitia" module="sdlc" test_file="unit/nasa-certification-test.ss":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ contribution }}" in lambda-episteme|lambda-aitia) ;; *) echo "unsupported contribution: {{ contribution }}" >&2; exit 64 ;; esac
    test_root="$(mktemp -d "${TMPDIR:-/tmp}/poo-flow-{{ contribution }}-atomic-test.XXXXXX")"
    trap 'find "$test_root" -depth -delete' EXIT
    if test "{{ contribution }}" = "lambda-aitia"; then
        cd "{{ contribution_source_root }}/lambda-aitia"
        runner="./run-test.ss"
        test_path="t/{{ module }}/{{ test_file }}"
    else
        runner="./run-contribute-test.ss"
        test_path="packages/{{ contribution }}/t/{{ module }}/{{ test_file }}"
    fi
    test -f "$test_path"
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="$test_root" GERBIL_LOADPATH="{{ contribution_source_root }}/{{ contribution }}:{{ justfile_directory() }}:$test_root/lib:{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s gxi {{ gerbil_test_runtime_options }} "$runner" "$test_path"

# Execute the root-owned, mechanism-only cross-contribution qualification.
[group('test')]
test-standards-multi-industry-profile-composition:
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ contribution_source_root }}/lambda-aitia:{{ contribution_source_root }}/lambda-episteme:{{ justfile_directory() }}:{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/qualification/standards-multi-industry/profile-composition-test.ss

# Keep the 10k scale fixture out of the ordinary unit-test worker. This
# dedicated gate owns its benchmark budget and emits the full native receipt.
[group('test')]
test-standards-resolution-performance:
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 90s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/performance/standards-resolution-performance-test.ss

# Keep the 10k Sources Lock fixture outside the ordinary unit-test worker. The
# Scenario measures canonical construction separately from indexed lookup.
[group('test')]
test-sources-lock-performance:
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 90s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/performance/sources-lock-performance-test.ss

# Let gxtest qualify source first, then build the admitted contribution.
[group('check')]
check-contribute contribution="lambda-aitia" module="sdlc":
    just test-contribute "{{ contribution }}" "{{ module }}"
    just build-contribute "{{ contribution }}"

# Let gxtest qualify one source file first, then build the contribution.
[group('check')]
check-contribute-atomic contribution="lambda-aitia" module="sdlc" test_file="unit/nasa-certification-test.ss":
    just test-contribute-atomic "{{ contribution }}" "{{ module }}" "{{ test_file }}"
    just build-contribute "{{ contribution }}"

# Aitia owns the SDLC and GitOps composition and its integration closure.
[group('check')]
check-aitia-integration:
    just build-contribute lambda-aitia
    cd "{{ contribution_source_root }}/lambda-aitia" && GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} ./integration-build.ss compile
    just test-contribute lambda-aitia bindings
    just test-contribute lambda-aitia integration

# Build the self-contained Aitia Scheme-native library and its Aitia-owned consumers.
[group('check')]
check-aitia-native:
    just build-contribute lambda-aitia
    cd "{{ contribution_source_root }}/lambda-aitia" && GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} ./integration-build.ss compile
    mkdir -p "{{ justfile_directory() }}/.gerbil/native"
    cd "{{ contribution_source_root }}/lambda-aitia" && GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} python3 tools/build-native-library.py --output "{{ aitia_native_library }}"
    cc -std=c11 -Wall -Wextra -Werror -pedantic -I"{{ contribution_source_root }}/lambda-aitia/bindings/c/include" "{{ contribution_source_root }}/lambda-aitia/bindings/c/tests/aitia-header-harness.c" -o "{{ justfile_directory() }}/.gerbil/native/aitia_header_harness"
    "{{ justfile_directory() }}/.gerbil/native/aitia_header_harness"
    cc -std=c11 -Wall -Wextra -Werror -pedantic -I"{{ contribution_source_root }}/lambda-aitia/bindings/c/include" "{{ contribution_source_root }}/lambda-aitia/bindings/c/tests/aitia-dynamic-harness.c" -o "{{ justfile_directory() }}/.gerbil/native/aitia_dynamic_harness"
    "{{ justfile_directory() }}/.gerbil/native/aitia_dynamic_harness" "{{ aitia_native_library }}"
    just test-contribute lambda-aitia bindings
    cd "{{ aitia_python_dir }}" && {{ gerbil_darwin_env }} uv lock --check
    cd "{{ aitia_python_dir }}" && {{ gerbil_darwin_env }} uv run --locked --extra test python src/lambda_aitia/_native/_build.py
    cd "{{ aitia_python_dir }}" && LAMBDA_AITIA_NATIVE_LIBRARY="{{ aitia_native_library }}" {{ gerbil_darwin_env }} uv run --locked --extra test pytest
    cd "{{ contribution_source_root }}/lambda-aitia" && just build-python-wheel "{{ aitia_native_library }}"

# Install the dependency revisions declared by gerbil.pkg.
[group('dependency')]
deps:
    {{ gerbil_darwin_env }} gerbil deps --install
    {{ gerbil_darwin_env }} gerbil clean

# Clean only native Gerbil package build artifacts.
[group('build')]
clean:
    gerbil clean

# Run the cold native lifecycle in order; stop on the first failure.
[group('check')]
rebuild:
    just clean
    just deps
    just build
    just test

# Incrementally build the canonical Scheme project through a persistent Bazel development root.
[group('build')]
build-dev:
    {{ bazel }} run {{ gerbil_dev_compile }}

# Build the runtime-C library target.
[group('build')]
build-runtime-c:
    {{ bazel }} build {{ runtime_c_library }}

# Build the Bundle v1 C library target.
[group('build')]
build-bundle-v1:
    {{ bazel }} build {{ bundle_v1_library }}

# Build the single Lean-linked Cedar Runtime Host at an explicit output path (Nix: $out/bin/cedarRuntimeHost).
[group('build')]
build-cedar-runtime-host out:
    python3 packages/automation/build_cedar_runtime_host.py "{{ out }}"

# Show the registered Gerbil implementation selected for the host platform.
[group('build')]
toolchain:
    {{ bazel }} build --toolchain_resolution_debug={{ gerbil_toolchain_type }} {{ gerbil_compile }}

# Run the package's single native Scheme test entrypoint.
[group('test')]
test:
    just test-core
    @echo "[poo-flow-test-runtime] maxHeap={{ gerbil_test_max_heap }} debug={{ gerbil_test_debug }} scope=worker-process"
    gerbil {{ gerbil_test_runtime_options }} env ./unit-tests.ss

# Keep ASP's per-phase test receipts and add process wall/user/system timing.
[group('test')]
test-profile:
    time just test

# Run the existing C4 identity/performance witness under the test heap fence.
[group('test')]
benchmark-poo-clos-native-c4:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} env gxi t/scenarios/performance/poo-clos-native-c4/scenario.ss

# Keep Core qualification under its own Justfile.
[group('test')]
test-core:
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ poo_flow_gerbil_path }}" GERBIL_LOADPATH="{{ poo_flow_library_path }}" just test

# Run one root-owned Scheme test with the same pre-import heap fence.
[group('test')]
test-file path:
    #!/usr/bin/env bash
    set -euo pipefail
    test -f "{{ path }}"
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} env gxtest "{{ path }}" 2>&1 | tee "$log"
    if grep -E 'ERROR (CHECK|CASE|HARNESS)|Heap overflow|Stack overflow' "$log" >/dev/null; then exit 1; fi
    grep -F 'MODULE-OK {{ path }}' "$log" >/dev/null
    grep -F 'HARNESS-OK' "$log" >/dev/null
    grep -x 'OK' "$log" >/dev/null

# Rebuild only the Scheme/C ABI owner before its source-level round-trip test.
[group('test')]
test-runtime-v0-native-ffi:
    #!/usr/bin/env bash
    set -euo pipefail
    link_options=()
    if [[ "$(uname -s)" == Darwin ]]; then
      link_options=(-ld-options "-Wl,-undefined,dynamic_lookup")
    fi
    library_root="{{ poo_flow_gerbil_path }}/lib"
    export GERBIL_LOADPATH="$library_root:{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}"
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} env gxc "${link_options[@]}" modules/workflow/runtime/runtime-v0-native.ss
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} env gxc t/runtime-v0-native-ffi-test.ss
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    test_module="$library_root/poo-flow/t/runtime-v0-native-ffi-test.ssi"
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} env gxtest "$test_module" </dev/null 2>&1 | tee "$log"
    if grep -E 'ERROR (MODULE|CHECK|CASE|HARNESS)|Heap overflow|Stack overflow' "$log" >/dev/null; then exit 1; fi
    grep -F "MODULE-OK $test_module" "$log" >/dev/null
    grep -F 'HARNESS-OK' "$log" >/dev/null
    grep -x 'OK' "$log" >/dev/null

# Run statically linked Query/Orgize/Evidence cases through upstream gxtest.
[group('test')]
test-query-parser-native executable:
    #!/usr/bin/env bash
    set -euo pipefail
    test -x "{{ executable }}"
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    POO_FLOW_TEST_PROGRESS=1 GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s python3 "{{ justfile_directory() }}/packages/python-runtime/tools/watch.py" "{{ executable }}" {{ gerbil_test_runtime_options }} -v 5 "{{ justfile_directory() }}/t/query-core-test.ss" "{{ justfile_directory() }}/t/query-orgize-source-test.ss" "{{ justfile_directory() }}/t/evidence-assessment-core-test.ss" 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS)|Heap overflow|Stack overflow' "$log"; then exit 1; fi
    test "$(grep -Ec '^CASE-OK ' "$log" || true)" = 24
    grep -Eq '^MODULE-OK .*query-core-test.ss$' "$log"
    grep -Eq '^MODULE-OK .*query-orgize-source-test.ss$' "$log"
    grep -Eq '^MODULE-OK .*evidence-assessment-core-test.ss$' "$log"
    grep -Eq '^HARNESS-OK ' "$log"
    grep -Eq '^OK$' "$log"

# Run the compiler-owned native Temporal suite with heap fencing and Case receipts.
[group('test')]
test-temporal-family-native executable:
    #!/usr/bin/env bash
    set -euo pipefail
    test -x "{{ executable }}"
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    POO_FLOW_TEST_PROGRESS=1 GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s python3 "{{ justfile_directory() }}/packages/python-runtime/tools/watch.py" "{{ executable }}" {{ gerbil_test_runtime_options }} -v 5 "{{ justfile_directory() }}/t/temporal-applicability-test.ss" "{{ justfile_directory() }}/t/temporal-lifecycle-test.ss" 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS)|Heap overflow|Stack overflow' "$log"; then exit 1; fi
    test "$(grep -Ec '^CASE-OK ' "$log" || true)" = 13
    grep -Eq '^MODULE-OK .*temporal-applicability-test.ss$' "$log"
    grep -Eq '^MODULE-OK .*temporal-lifecycle-test.ss$' "$log"
    grep -Eq '^HARNESS-OK ' "$log"
    grep -Eq '^OK$' "$log"

# Verify original MRR owner values and fresh-process archive replay through the ABI.
[group('test')]
test-temporal-family-archive executable library sha256 directory:
    #!/usr/bin/env bash
    set -euo pipefail
    test -x "{{ executable }}"
    test -f "{{ library }}"
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    MRR_NATIVE_PROGRESS=1 POO_FLOW_RUNTIME_TRACE=1 POO_FLOW_ARCHIVE_DIRECTORY="{{ directory }}" POO_FLOW_SEMANTIC_LIBRARY="{{ library }}" POO_FLOW_SEMANTIC_SHA256="{{ sha256 }}" timeout --foreground --signal=TERM --kill-after=1s 45s python3 "{{ justfile_directory() }}/packages/python-runtime/tools/watch.py" "{{ executable }}" --exact original_mrr_values_project_to_real_native_poo --nocapture --test-threads=1 2>&1 | tee "$log"
    test "$(grep -Ec '^test result: ok\. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out;' "$log" || true)" = 2
    grep -Eq '^Fresh-process full Family proof archive replay verified$' "$log"
    test -s "{{ directory }}/archive.ss"
    test -s "{{ directory }}/replayed.ss"

# Require real Context binding and stale-Source checks in the native MRR ABI run.
[group('test')]
test-temporal-mrr-context executable library sha256 directory:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    just --justfile "{{ justfile_directory() }}/justfile" test-temporal-family-archive "{{ executable }}" "{{ library }}" "{{ sha256 }}" "{{ directory }}" 2>&1 | tee "$log"
    grep -F 'MRR Context checked original receipt, policy, temporal fact and current Source; forged/missing/foreign bindings rejected' "$log" >/dev/null
    grep -Fx 'MRR Context rejected stale native Source after correction' "$log" >/dev/null

# Check the declared ASCENT package through POO Flow's Observability Case.
[group('test')]
test-ascent-integration:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s python3 "{{ justfile_directory() }}/packages/python-runtime/tools/watch.py" gerbil {{ gerbil_test_runtime_options }} env gerbil {{ gerbil_test_runtime_options }} t/harness/ascent-guarded-runner.ss 2>&1 | tee "$log"
    if grep -E 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log" >/dev/null; then exit 1; fi
    grep -F 'CASE-OK guarded copy and join preserve source snapshots' "$log" >/dev/null
    grep -F 'MODULE-OK t/qualification/ascent-integration/guarded-test.ss' "$log" >/dev/null
    grep -F 'HARNESS-OK' "$log" >/dev/null
    grep -x 'OK' "$log" >/dev/null

# Run wall-clock performance scenarios through the native ASP scheduler,
# outside the ordinary unit-test batches.
[group('test')]
test-performance:
    @echo "[poo-flow-test-runtime] maxHeap={{ gerbil_test_max_heap }} debug={{ gerbil_test_debug }} scope=worker-process"
    gerbil {{ gerbil_test_runtime_options }} env ./performance-tests.ss

# Run only hermetic Bazel qualifications; `just test` owns Scheme unit tests.
[group('test')]
test-bazel:
    just test-gerbil-capability
    just test-module-system-ownership
    just test-external-bazel-module

# Validate the shared Gerbil toolchain and dependency-install capabilities.
[group('test')]
test-gerbil-capability:
    {{ bazel }} test --test_output=errors {{ gerbil_capability_tests }}

# Validate POO Flow as a clean external Bzlmod dependency.
[group('test')]
test-external-bazel-module:
    python3 -m unittest discover -s t/qualification/external_bazel -p 'external_module_test.py' -v
    python3 t/qualification/external_bazel/external_module.py

# Validate the single source-owned RFC45 module-system ownership map.
[group('test')]
test-module-system-ownership:
    {{ bazel }} test --test_output=errors {{ module_system_owner_tests }}

# Run the ordinary runtime-C acceptance suite.
[group('test')]
test-runtime-c:
    {{ bazel }} test --test_output=errors {{ runtime_c_tests }}

# Run the Bundle v1 acceptance suite.
[group('test')]
test-bundle-v1:
    {{ bazel }} test --test_output=errors {{ bundle_v1_tests }}

# Qualify an explicitly supplied Cedar Runtime Host artifact.
[group('test')]
test-cedar-runtime-host host:
    POO_FLOW_CEDAR_RUNTIME_HOST="{{ host }}" cargo test --locked --manifest-path {{ cedar_workspace }} -p poo-flow-cedar-authority --features native-runtime-host-qualification --test runtime_host --test authorization --test case_check

# Qualify the Scheme POO -> native authority -> AOT Host path with one Cedar artifact.
[group('test')]
test-cedar-native host:
    POO_FLOW_CEDAR_RUNTIME_HOST="{{ host }}" cargo test --locked --manifest-path {{ cedar_workspace }} -p poo-flow-cedar-gerbil --features conformance --test native_authorization

# Replay one data-only case manifest against exported Cedar files and both Host engines.
[group('test')]
test-cedar-case manifest host policy:
    cargo run --locked --quiet --manifest-path {{ cedar_workspace }} -p poo-flow-cedar-authority --bin cedar-case-check -- "{{ manifest }}" "{{ host }}" "{{ policy }}"

# Parse an exported policy set without starting the Runtime Host.
[group('test')]
inspect-cedar-file policy:
    cargo run --locked --quiet --manifest-path {{ cedar_workspace }} -p poo-flow-cedar-authority --bin cedar-case-check -- inspect "{{ policy }}"

# Run the focused composition-lifecycle Python gate.
[group('test')]
test-python-composition-lifecycle:
    cd {{ python_runtime_dir }} && uv run --group dev pytest -q {{ composition_lifecycle_tests }}

# Run the complete Python suite in the Bazel-declared Gerbil project environment.
[group('test')]
test-python:
    {{ bazel }} run {{ python_runtime_test_environment }} -- uv run --group dev pytest -q

# Run the explicit runtime-C sanitizer gate.
[group('test')]
test-runtime-c-sanitizers:
    {{ bazel }} test --test_output=errors {{ runtime_c_sanitizer_tests }}

# Run the explicit runtime-C leak gate.
[group('test')]
test-runtime-c-leaks:
    {{ bazel }} test --test_output=errors {{ runtime_c_leak_test }}

# Run the native Scheme build and ordinary-test convergence gate.
[group('check')]
check: build test

# Admit gerbil-parser through POO Flow's current V19 dependency environment.
# The sibling remains the parser source owner; qualification imports only the
# demanded modules and never builds a second stale package cache.
_prepare-gerbil-parser:
    test -f "{{ gerbil_parser_dir }}/gerbil.pkg"
    GERBIL_PATH="{{ gerbil_parser_path }}" GERBIL_LOADPATH="{{ gerbil_parser_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s gerbil interactive -e '(begin (import :gerbil-parser/src/runtime/artifact) (displayln "gerbil-parser-v19-ready"))'

# separate semantic gate; no source acceptance is presented as model checking.


# Qualify Case-owned GQL Sources from the parser owner's package environment.
# Lambda stays independent of gerbil-parser; parser acceptance is not execution.
[group('check')]
check-healthcare-gql: _prepare-gerbil-parser
    cd "{{ contribution_source_root }}/lambda-episteme" && GERBIL_PATH="{{ gerbil_parser_path }}" GERBIL_LOADPATH="{{ contribution_test_library_path }}:{{ gerbil_parser_library_path }}" gerbil interactive -e '(begin (import (only-in :std/misc/ports read-all-as-string) (only-in :poo-flow/modules/query/gql poo-flow-query->gql) (only-in :poo-flow/lambda-episteme/user-interface/scenarios/healthcare/assurance healthcare-case-qualification-gql-paths) (only-in :poo-flow/lambda-episteme/user-interface/scenarios/healthcare/reasoning HealthcareCaseProfileRelationsQuery HealthcareProfileImpactQuery HealthcarePrescriptionCausalTrajectoryQuery) (only-in :gerbil-parser/languages/gql/iso-39075-2024/parser +gql-syntax-contract+ parse-gql-iso-39075-2024) (only-in :gerbil-parser/src/runtime/artifact parse-artifact-ref parse-artifact-success? parse-artifact-valid? parse-artifact-roundtrip)) (let loop ((queries (list HealthcareCaseProfileRelationsQuery HealthcareProfileImpactQuery HealthcarePrescriptionCausalTrajectoryQuery)) (paths (healthcare-case-qualification-gql-paths)) (receipts (quote ()))) (if (null? paths) (begin (for-each displayln (reverse receipts)) (exit 0)) (let* ((query (car queries)) (path (car paths)) (expected (call-with-input-file path read-all-as-string)) (source (poo-flow-query->gql query)) (artifact (parse-gql-iso-39075-2024 source)) (accepted? (and (equal? source expected) (parse-artifact-success? artifact) (parse-artifact-valid? artifact) (equal? source (parse-artifact-roundtrip artifact))))) (unless accepted? (displayln (list (cons (quote source) path) (cons (quote exact-projection) (equal? source expected)) (cons (quote accepted) #f))) (exit 1)) (loop (cdr queries) (cdr paths) (cons (list (cons (quote source) path) (cons (quote parser) (quote gerbil-parser)) (cons (quote syntax-contract) +gql-syntax-contract+) (cons (quote source-content-id) (parse-artifact-ref artifact (quote sourceDigest))) (cons (quote grammar-content-id) (parse-artifact-ref artifact (quote grammarDigest))) (cons (quote exact-projection) #t) (cons (quote accepted) #t) (cons (quote roundtrip) #t)) receipts))))))'

# Parse the domain-owned legacy message through the parser source owner, then
# require exact equality with Lambda's retained projection.
[group('check')]
check-healthcare-hl7v2-migration: _prepare-gerbil-parser
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ gerbil_parser_path }}" GERBIL_LOADPATH="{{ contribution_source_root }}/lambda-episteme:{{ gerbil_parser_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/qualification/healthcare-hl7v2-migration/parser-receipt-test.ss

# Qualify parser-owned FHIRPath syntax without claiming evaluator semantics.
[group('check')]
check-healthcare-fhirpath-syntax: _prepare-gerbil-parser
    GERBIL_PARSER_DIR="{{ gerbil_parser_dir }}" GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ gerbil_parser_path }}" GERBIL_LOADPATH="{{ contribution_source_root }}/lambda-episteme:{{ gerbil_parser_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/qualification/healthcare-fhirpath-syntax/parser-receipt-test.ss

# Replay the pinned external Validator from its local JAR/package cache. The
# test verifies the binary digest and compares decoded OperationOutcome JSON.
[group('check')]
check-healthcare-fhir-reference-validator:
    test -n "{{ fhir_validator_jar }}" && test -f "{{ fhir_validator_jar }}"
    FHIR_VALIDATOR_JAR="{{ fhir_validator_jar }}" GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ poo_flow_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 90s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/qualification/healthcare-fhir-reference-validator/replay-test.ss

# Build one Lean module and exactly its import closure.  This is the normal
# proof-development gate; it never traverses the PooFlowProof aggregate root.
[group('check')]
check-lean-module module:
    [[ "{{ module }}" =~ ^PooFlowProof(\.[A-Za-z0-9_]+)+$ ]]
    cd "{{ lean_proof_dir }}" && lake build "{{ module }}"

# remain independent gates owned by their parser/model-checker lifecycles.
[group('check')]
check-healthcare-lean:
    cd "{{ lean_proof_dir }}" && lake build PooFlowScenarioHealthcareProof
    GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ contribution_test_library_path }}:{{ poo_flow_library_path }}" gerbil interactive -e '(begin (import (only-in :poo-flow/lambda-episteme/user-interface/scenarios/healthcare/assurance healthcare-publish-lean-refinement-receipt!)) (displayln (healthcare-publish-lean-refinement-receipt!)))'

[group('check')]
check-governance-lean:
    cd "{{ lean_proof_dir }}" && lake build PooFlowModuleGovernanceProof

# Prove the shared Object/Entity/Element/Relation/Query ownership laws without
# traversing the repository-wide Lean aggregate.
[group('check')]
check-native-semantic-query-lean:
    cd "{{ lean_proof_dir }}" && lake build PooFlowCoreProof.PooC4.NativeSemanticQueryModel


[group('check')]
check-native-semantic-query-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group query

# Explore the module-owned hypothesis family both to exhaustion and under a
# tighter bound. Each configuration checks every candidate selection order.
[group('check')]
check-temporal-family-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group family

# Model-check append-only temporal evidence revisions and stable as-of cuts.
[group('check')]
check-temporal-revisions-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group revision

# Check the finite reverse-dependency model and the separate LeanPoo 4.34
# certificate target without changing the Cedar-bound Lean 4.31 project.
[group('check')]
check-temporal-invalidation-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group invalidation

# Check explicit clock domains and conservative interval observations.
[group('check')]
check-temporal-time:
    GERBIL_PATH="{{ poo_flow_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ poo_flow_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-time-test.ss

# Replay immutable conclusion journals before forming a CAS proposal.
[group('check')]
check-temporal-conclusions:
    GERBIL_PATH="{{ poo_flow_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ poo_flow_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-conclusions-test.ss

# Check exclusive and overlapping finite hypothesis-family semantics.
[group('check')]
check-temporal-model:
    GERBIL_PATH="{{ poo_flow_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ poo_flow_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-model-test.ss

# Verify Trajectory independently of the consuming Impact module.
[group('check')]
check-temporal-trajectory:
    GERBIL_PATH="{{ poo_flow_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ poo_flow_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-trajectory-test.ss

# Verify exact irregular-grid Impact arithmetic without claiming a
# trained forecaster, statistical estimator or causal effect.
[group('check')]
check-temporal-impact:
    GERBIL_PATH="{{ poo_flow_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ poo_flow_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-impact-test.ss

# Check domain-neutral retrieval/use lineage and finite interleavings.
[group('check')]
check-temporal-evidence:
    GERBIL_PATH="{{ poo_flow_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ poo_flow_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-evidence-test.ss

# Audit exact cut/provider receipts as inert candidate review material.
[group('check')]
check-temporal-candidate-exchange:
    GERBIL_PATH="{{ poo_flow_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ poo_flow_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-candidate-exchange-test.ss

[group('check')]
check-temporal-evidence-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group evidence

# Explore both orders of competing conclusion-selection proposals. The
# checked transition is an abstract atomic CAS, not a runtime pointer write.
[group('check')]
check-temporal-conclusion-selection-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group selection

[group('check')]
check-temporal-poo-lean:
    cd "{{ temporal_poo_proof_dir }}" && PATH="{{ justfile_directory() }}/.devenv/profile/bin:$PATH" timeout 120s lake build PooFlowTemporalPooProof

# Session lifecycle, WorkTree sharing, and explicit C4 policy proofs belong to
# POO Flow. MRR receipts are external inputs to these contracts.
[group('check')]
check-session-poo-lean:
    cd "{{ temporal_poo_proof_dir }}" && PATH="{{ justfile_directory() }}/.devenv/profile/bin:$PATH" timeout 120s lake build PooFlowSessionProof

[group('check')]
check-session-context-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group session

[group('check')]
check-session-proof: check-session-poo-lean check-session-context-quint

[group('check')]
check-context-delta-lean:
    cd "{{ temporal_poo_proof_dir }}" && timeout 120s lean ContextDelta.lean

[group('check')]
check-context-delta-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group context-delta

[group('check')]
check-context-delta-proof: check-context-delta-lean check-context-delta-quint check-context-coverage-quint

[group('check')]
check-context-coverage-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group context-coverage

[group('check')]
check-session-attempt-lean:
    cd "{{ temporal_poo_proof_dir }}" && timeout 120s lean SessionAttempt.lean

[group('check')]
check-session-attempt-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group session-attempt

[group('check')]
check-session-attempt-proof: check-session-attempt-lean check-session-attempt-quint


[group('check')]
check-context-org-anchor-lean:
    cd "{{ temporal_poo_proof_dir }}" && timeout 120s lean OrgAnchor.lean

[group('check')]
check-context-session-claim-lean:
    cd "{{ temporal_poo_proof_dir }}" && timeout 120s lean ContextSessionClaim.lean

[group('check')]
check-context-session-claim-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group context-session-claim

[group('check')]
check-context-session-claim-proof: check-context-org-anchor-lean check-context-session-claim-lean check-context-session-claim-quint

[group('check')]
check-context-temporal-policy-lean:
    cd "{{ temporal_poo_proof_dir }}" && timeout 120s lean ContextTemporalPolicy.lean

[group('check')]
check-context-temporal-lifecycle-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group context-temporal-lifecycle

[group('check')]
check-context-temporal-policy-proof: check-context-temporal-policy-lean check-context-temporal-lifecycle-quint

[group('check')]
check-native-semantic-query-model: check-native-semantic-query-lean
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group query

# Full aggregation is an explicit integration qualification, never the default
# local or pull-request proof gate.
[group('check')]
check-lean-all: check-temporal-poo-lean check-session-poo-lean
    cd "{{ lean_proof_dir }}" && lake build PooFlowProof

[group('check')]
check-governance-model:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group governance


# Check finite clinical authority transitions through Quint.
[group('check')]
check-healthcare-temporal-model:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group healthcare

# Exact bounded model for the AI-assisted prescription Case.
[group('check')]
check-healthcare-ai-temporal-model:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group healthcare-ai

# Formal-model governance evidence is an explicit assurance gate.
[group('check')]
check-healthcare-standard-migration-model:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group healthcare-migration

[group('check')]
check-healthcare-standard-migration-lean:
    cd "{{ lean_proof_dir }}" && lake build PooFlowScenarioHealthcareProof

# Source-byte and impact-map qualification rejects stale downstream Lean proof
[group('check')]
check-healthcare-standard-migration-proof-impact: check-healthcare-standard-migration-model check-healthcare-standard-migration-lean
    python3 "{{ justfile_directory() }}/packages/proofs/quint/source_binding.py"

[group('check')]
check-healthcare-standard-migration-assurance: check-healthcare-standard-migration-proof-impact

# Only this exact qualification may combine the independent Scheme, parser,
# downstream runtime and contribution assurance keep separate evidence scopes.
[group('check')]
check-healthcare-case-assurance: build-contribute check-healthcare-gql check-healthcare-lean check-healthcare-ai-temporal-model
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ contribution_test_path }}" GERBIL_LOADPATH="{{ contribution_test_library_path }}:{{ poo_flow_library_path }}" timeout --foreground --signal=TERM --kill-after=3s 20s gxi {{ gerbil_test_runtime_options }} ./run-contribute-test.ss "packages/lambda-episteme/t/ontology/qualification/healthcare-case-assurance.ss"

# Validate the repository and published-package license contract.
[group('check')]
check-license-contract:
    python3 packages/automation/check_license_contract.py
    python3 -m unittest discover -s packages/automation/tests -p 'test_*.py'

# Validate every first-party manifest and Runtime ABI projection against VERSION.
[group('check')]
check-version-contract:
    python3 packages/automation/check_version_contract.py

# Validate that gerbil.pkg direct pins and every Bazel projection agree.
[group('check')]
check-gerbil-dependency-contract:
    python3 packages/automation/gerbil_dependency_pin.py check

# Verify that dependency resolution is represented by the tracked lock.
[group('dependency')]
lock-check:
    {{ bazel }} mod deps --lockfile_mode=error

# Refresh this host's native Bazel lock; CI merges Linux and Darwin evaluations.
[group('dependency')]
bazel-update:
    {{ bazel }} mod deps --lockfile_mode=update

# Change a direct Gerbil dependency once. gerbil.pkg is authoritative; the
# source archive digest and both platform lock projections are derived.
[group('dependency')]
pin-gerbil-dependency package revision:
    python3 packages/automation/gerbil_dependency_pin.py pin "{{ package }}" "{{ revision }}"
    {{ bazel }} mod deps --lockfile_mode=update
    python3 packages/automation/gerbil_dependency_pin.py sync-lock
    python3 packages/automation/gerbil_dependency_pin.py check

# Normalize MODULE.bazel declarations while explicitly updating the lock.
[group('dependency')]
mod-tidy:
    {{ bazel }} mod tidy --lockfile_mode=update

# Qualify the pinned temporal package with visible case receipts.
[group('test')]
test-ascent-temporal:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s python3 "{{ justfile_directory() }}/packages/python-runtime/tools/watch.py" gerbil {{ gerbil_test_runtime_options }} env gerbil {{ gerbil_test_runtime_options }} t/harness/ascent-temporal-runner.ss 2>&1 | tee "$log"
    if grep -E 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log" >/dev/null; then exit 1; fi
    grep -F 'MODULE-OK t/ascent-temporal-lens-test.ss' "$log" >/dev/null
    grep -F 'CASE-OK POO values keep native evidence separate from cut authority' "$log" >/dev/null
    grep -F 'CASE-OK explicit cut bridge preserves uncertainty and original identity binding' "$log" >/dev/null
    grep -F 'HARNESS-OK' "$log" >/dev/null
    grep -x 'OK' "$log" >/dev/null

# Persistent worker baseline for matched semantic transport measurements.
[group('test')]
semantic-worker:
    {{ gerbil_darwin_env }} GERBIL_PATH="${GERBIL_PATH:-{{ justfile_directory() }}/.gerbil}" GERBIL_LOADPATH="${GERBIL_LOADPATH:-{{ justfile_directory() }}/.gerbil/lib}" timeout --foreground --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} t/harness/semantic-worker.ss

[group('build')]
build-semantic-native output:
    python3 bindings/runtime-c/tools/build-semantic.py --output "{{ output }}"

[group('test')]
model-understanding-compute script:
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s env GERBIL_DEBUG=expansion gxi {{ gerbil_test_runtime_options }} t/model-study/direct-understanding/compute-loader.ss "{{ script }}"

[group('test')]
model-understanding-score expected candidate:
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s gxi {{ gerbil_test_runtime_options }} t/model-study/direct-understanding/prediction-score.ss "{{ expected }}" "{{ candidate }}"

# Explicit installed-artifact acceptance; ASP Scheme owns measurement and receipts.
[group('test')]
benchmark-temporal-mrr:
    just test-file t/qualification/temporal-mrr-native/native-test.ss

# Paid model samples run once; ASP measures each, without repeated p95 sampling.
[group('test')]
qualify-temporal-model python binary library oracle env_file output:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 180s gerbil {{ gerbil_test_runtime_options }} env gxi t/qualification/temporal-model-native/scenario.ss "{{ python }}" "{{ binary }}" "{{ library }}" "{{ oracle }}" "{{ env_file }}" "{{ output }}"

[group('test')]
qualify-temporal-physical-model python binary library oracle env_file output:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 60s gerbil {{ gerbil_test_runtime_options }} env gxi t/qualification/temporal-physical-native/model-scenario.ss "{{ python }}" "{{ binary }}" "{{ library }}" "{{ oracle }}" "{{ env_file }}" "{{ output }}"

# Compile the bounded acyclic support kernel before native runtime qualification.
[group('build')]
build-temporal-support:
    gxc -:max-heap=1G,debug=q -V -O modules/temporal-causality/revisions/types.ss modules/temporal-causality/revisions/objects.ss modules/temporal-causality/revisions/funs.ss modules/temporal-causality/revisions/interface.ss modules/temporal-causality/truth-maintenance/support/types.ss modules/temporal-causality/truth-maintenance/support/objects.ss modules/temporal-causality/truth-maintenance/support/funs.ss modules/temporal-causality/truth-maintenance/support/policy.ss modules/temporal-causality/truth-maintenance/support/interface.ss modules/temporal-causality/truth-maintenance/interface.ss

[group('test')]
test-temporal-support:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    timeout --foreground --signal=TERM --kill-after=1s 45s python3 packages/python-runtime/tools/watch.py gerbil {{ gerbil_test_runtime_options }} env gerbil {{ gerbil_test_runtime_options }} t/harness/temporal-support-runner.ss 2>&1 | tee "$log"
    if grep -E 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log" >/dev/null; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 9
    grep -Fx 'MODULE-OK t/temporal-support-test.ss' "$log" >/dev/null
    grep -F 'HARNESS-OK' "$log" >/dev/null
    grep -x 'OK' "$log" >/dev/null

# Named original ASCENT positive-proof adapter and host policy boundary.
[group('build')]
build-temporal-evaluator:
    gxc -:max-heap=1G,debug=q -V -O modules/temporal-causality/truth-maintenance/support/policy-host.ss modules/temporal-causality/evaluator/positive-proof.ss modules/temporal-causality/evaluator/fact.ss modules/temporal-causality/evaluator/binding.ss modules/temporal-causality/evaluator/rule.ss modules/temporal-causality/evaluator/derivation.ss modules/temporal-causality/evaluator/proof-host.ss modules/temporal-causality/evaluator/interface.ss

[group('test')]
test-temporal-evaluator:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    timeout --foreground --signal=TERM --kill-after=1s 45s python3 packages/python-runtime/tools/watch.py gxi {{ gerbil_test_runtime_options }} t/harness/temporal-evaluator-runner.ss 2>&1 | tee "$log"
    if grep -E 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log" >/dev/null; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 28
    grep -Fx 'MODULE-OK t/temporal-evaluator-test.ss' "$log" >/dev/null
    grep -F 'HARNESS-OK' "$log" >/dev/null
    grep -x 'OK' "$log" >/dev/null

# Fixed-schema Orgize source producer through canonical POO Query.
[group('test')]
test-query-orgize-source:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    timeout --foreground --signal=TERM --kill-after=1s 45s python3 packages/python-runtime/tools/watch.py gxi {{ gerbil_test_runtime_options }} t/harness/query-orgize-source-runner.ss 2>&1 | tee "$log"
    if grep -E 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log" >/dev/null; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 4
    grep -Fx 'MODULE-OK t/query-orgize-source-test.ss' "$log" >/dev/null
    grep -F 'HARNESS-OK' "$log" >/dev/null
    grep -x 'OK' "$log" >/dev/null

# Formal source authority matches MRR: Quint 0.33.0 and Apalache 0.62.1.
[group('check')]
prepare-quint:
    npm ci --prefix "{{ justfile_directory() }}/packages/proofs/quint" --no-audit --no-fund
    python3 "{{ justfile_directory() }}/packages/proofs/quint/prepare_backend.py"

[group('check')]
check-quint-types:
    python3 "{{ justfile_directory() }}/packages/proofs/quint/typecheck.py"

[group('check')]
check-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group all

# Producer mathematical qualification; consumer binding proofs remain in MRR.
check-composition-proof:
    cd proofs/Composition && lake build && lake env lean --run CompositionChecks.lean && lake env lean --run SearchTemporalChecks.lean && lake env lean --run SearchReadinessChecks.lean && lake env lean --run SearchDagChecks.lean && lake env lean CompositionAxioms.lean

# Reuse the existing finite-model runner and exact negative-control admission.
[group('check')]
check-search-attempt-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group search-attempt
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group search-readiness
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group search-dag
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group search-evidence
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group search-evidence-history
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m poo_flow_testing.checks.quint --group search-inputs

# Bootstrap the expander in Gxi, then use the upstream GxTest entry point.
# No private assertion runner; require all Cases and the final harness receipt.
[group('check')]
check-search-attempt-scheme:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gerbil {{ gerbil_test_runtime_options }} env gxi -e '(import (only-in :gerbil/tools/gxtest main)) (main "-v" "5" "t/search-attempt-test.ss")' 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log"; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 8
    grep -Fx 'MODULE-OK t/search-attempt-test.ss' "$log"
    grep -F 'HARNESS-OK' "$log"
    grep -x 'OK' "$log"

[group('check')]
check-search-dag-scheme:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gerbil {{ gerbil_test_runtime_options }} env gxi -e '(import (only-in :gerbil/tools/gxtest main)) (main "-v" "5" "t/search-engine-test.ss")' 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log"; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 8
    grep -Fx 'MODULE-OK t/search-engine-test.ss' "$log"
    grep -F 'HARNESS-OK' "$log"
    grep -x 'OK' "$log"

[group('check')]
check-search-framework-scheme:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gerbil {{ gerbil_test_runtime_options }} env gxi -e '(import (only-in :gerbil/tools/gxtest main)) (main "-v" "5" "t/search-framework-test.ss")' 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log"; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 6
    grep -Fx 'MODULE-OK t/search-framework-test.ss' "$log"
    grep -F 'HARNESS-OK' "$log"
    grep -x 'OK' "$log"

[group('check')]
check-search-evidence-scheme:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gerbil {{ gerbil_test_runtime_options }} env gxi -e '(import (only-in :gerbil/tools/gxtest main)) (main "-v" "5" "t/search-evidence-test.ss")' 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS|MODULE)|Heap overflow|Stack overflow' "$log"; then exit 1; fi
    test "$(grep -c '^CASE-OK ' "$log")" = 10
    grep -Fx 'MODULE-OK t/search-evidence-test.ss' "$log"
    grep -F 'HARNESS-OK' "$log"
    grep -x 'OK' "$log"

[group('check')]
check-search-model-bindings:
    python3 packages/proofs/quint/source_binding.py
    packages/proofs/quint/node_modules/.bin/quint typecheck packages/proofs/quint/SearchAttempt_none.qnt
    packages/proofs/quint/node_modules/.bin/quint typecheck packages/proofs/quint/SearchReadiness_none.qnt
    packages/proofs/quint/node_modules/.bin/quint typecheck packages/proofs/quint/SearchDag_none.qnt
    packages/proofs/quint/node_modules/.bin/quint typecheck packages/proofs/quint/SearchEvidence_none.qnt
    packages/proofs/quint/node_modules/.bin/quint typecheck packages/proofs/quint/SearchEvidenceHistory_none.qnt
    packages/proofs/quint/node_modules/.bin/quint typecheck packages/proofs/quint/SearchInputs_none.qnt

[group('check')]
check-search-engine-proof: check-composition-proof check-search-model-bindings check-search-attempt-quint check-search-attempt-scheme check-search-dag-scheme check-search-framework-scheme check-search-evidence-scheme

# Original Context/Temporal suites through installed Scheme and upstream gxtest.
[group('test')]
test-context-temporal:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s python3 "{{ justfile_directory() }}/packages/python-runtime/tools/watch.py" gxi {{ gerbil_test_runtime_options }} -e '(load "t/harness/scheme-progress.ss") (import (only-in :gerbil/tools/gxtest main)) (let (status (main "-v" "5" "{{ justfile_directory() }}/.gerbil/lib/poo-flow/t/temporal-evaluator-test.ssi" "{{ justfile_directory() }}/.gerbil/lib/poo-flow/t/ai-agentic-context-session-host-test.ssi" "{{ justfile_directory() }}/.gerbil/lib/poo-flow/t/ai-agentic-context-delta-test.ssi" "{{ justfile_directory() }}/.gerbil/lib/poo-flow/t/session-attempt-test.ssi" "{{ justfile_directory() }}/.gerbil/lib/poo-flow/t/ai-agentic-context-org-anchors-test.ssi" "{{ justfile_directory() }}/.gerbil/lib/poo-flow/t/query-orgize-source-test.ssi")) (displayln "poo-test: gxtest returned " status) (force-output) (exit status))' 2>&1 | tee "$log"
    if grep -Eq 'ERROR (CHECK|CASE|HARNESS|MODULE)|\*\*\* ERROR|Heap overflow|Stack overflow|WARNING -- Variable.*is undefined' "$log"; then exit 1; fi
    test "$(grep -Ec '^CASE-OK ' "$log" || true)" = 69
    for module in temporal-evaluator ai-agentic-context-session-host ai-agentic-context-delta session-attempt ai-agentic-context-org-anchors query-orgize-source; do grep -Fx "MODULE-OK {{ justfile_directory() }}/.gerbil/lib/poo-flow/t/${module}-test.ssi" "$log" >/dev/null; done
    grep -Eq '^HARNESS-OK ' "$log"
    grep -Eq '^OK$' "$log"

# Source-level ownership controls; heap fence applies before any imports.
test-module-ownership:
    #!/usr/bin/env bash
    set -euo pipefail
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    timeout --foreground --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} t/qualification/module-ownership/run.ss 2>&1 | tee "$log"
    if grep -E 'ERROR (CASE|CHECK|HARNESS)|Heap overflow|Stack overflow' "$log" >/dev/null; then exit 1; fi
    grep -F 'MODULE-OK t/qualification/module-ownership/run.ss' "$log" >/dev/null
    grep -F 'HARNESS-OK module-ownership' "$log" >/dev/null
    grep -x 'OK' "$log" >/dev/null
