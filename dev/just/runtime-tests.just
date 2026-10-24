# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

[group('test')]
test-gerbil-test-tool executable path="t/gerbil-runtime-import-test.ss":
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 90s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss gerbil-tool "{{ gerbil_test_runtime_options }}" "{{ executable }}" "{{ path }}"

# Parse an exported policy set without starting the Runtime Host.
[group('test')]
inspect-cedar-file policy:
    cargo run --locked --quiet --manifest-path {{ cedar_workspace }} -p agentic-ai-lab-cedar-authority --bin cedar-case-check -- inspect "{{ policy }}"

# Check explicit clock domains and conservative interval observations.
[group('check')]
check-temporal-time:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ agentic_ai_lab_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-time-test.ss

# Replay immutable conclusion journals before forming a CAS proposal.
[group('check')]
check-temporal-conclusions:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ agentic_ai_lab_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-conclusions-test.ss

# Check exclusive and overlapping finite hypothesis-family semantics.
[group('check')]
check-temporal-model:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ agentic_ai_lab_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-model-test.ss

# Verify Trajectory independently of the consuming Impact module.
[group('check')]
check-temporal-trajectory:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ agentic_ai_lab_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-trajectory-test.ss

# Verify exact irregular-grid Impact arithmetic without claiming a
# trained forecaster, statistical estimator or causal effect.
[group('check')]
check-temporal-impact:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ agentic_ai_lab_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-impact-test.ss

# Check domain-neutral retrieval/use lineage and finite interleavings.
[group('check')]
check-temporal-evidence:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ agentic_ai_lab_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-evidence-test.ss

# Audit exact cut/provider receipts as inert candidate review material.
[group('check')]
check-temporal-candidate-exchange:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}/..:{{ justfile_directory() }}/core:{{ agentic_ai_lab_gerbil_path }}/lib:{{ justfile_directory() }}" just test-file t/temporal-candidate-exchange-test.ss

[group('check')]
check-native-semantic-query-model: check-native-semantic-query-lean
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group query

# Rebuild the pinned POO dependency after a native compiler/runtime repair.
# Preserve source and old AOT artifacts; never uninstall the package checkout.
[group('build')]
rebuild-poo-native backup:
    #!/usr/bin/env bash
    set -euo pipefail
    package_root="{{ agentic_ai_lab_gerbil_path }}/pkg/github.com/tao3k/gerbil-poo"
    test -f "$package_root/build.ss"
    test ! -e "{{ backup }}"
    tar -czf "{{ backup }}" -C "{{ agentic_ai_lab_library_path }}" clan/poo
    cd "$package_root"
    export GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}"
    export GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}"
    {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 60s gerbil clean
    {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 300s gerbil build

# Run the existing C4 identity/performance witness under the test heap fence.
[group('test')]
benchmark-poo-clos-native-c4:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} env gxi t/scenarios/performance/poo-clos-native-c4/scenario.ss

# Rebuild only the Scheme/C ABI owner before its source-level round-trip test.
[group('test')]
test-runtime-v0-native-ffi:
    #!/usr/bin/env bash
    set -euo pipefail
    link_options=()
    if [[ "$(uname -s)" == Darwin ]]; then
      link_options=(-ld-options "-Wl,-undefined,dynamic_lookup")
    fi
    library_root="{{ agentic_ai_lab_gerbil_path }}/lib"
    export GERBIL_LOADPATH="$library_root:{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}"
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} env gxc "${link_options[@]}" modules/workflow/runtime/runtime-v0-native.ss
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} env gxc t/runtime-v0-native-ffi-test.ss
    test_module="$library_root/agentic-ai-lab/t/runtime-v0-native-ffi-test.ssi"
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss runtime-ffi "{{ gerbil_test_runtime_options }}" "$test_module"

# Run statically linked Query/Orgize/Evidence cases through upstream gxtest.
[group('test')]
test-query-parser-native executable:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss query-native "{{ gerbil_test_runtime_options }}" "{{ executable }}"

# Run the compiler-owned native Temporal suite with heap fencing and Case receipts.
[group('test')]
test-temporal-family-native executable:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss temporal-native "{{ gerbil_test_runtime_options }}" "{{ executable }}"

# Verify original MRR owner values and fresh-process archive replay through the ABI.
[group('test')]
test-temporal-family-archive executable library sha256 directory:
    #!/usr/bin/env bash
    set -euo pipefail
    test -x "{{ executable }}"
    test -f "{{ library }}"
    log="$(mktemp)"
    trap 'rm -f "$log"' EXIT
    MRR_NATIVE_PROGRESS=1 AGENTIC_AI_LAB_RUNTIME_TRACE=1 AGENTIC_AI_LAB_ARCHIVE_DIRECTORY="{{ directory }}" AGENTIC_AI_LAB_SEMANTIC_LIBRARY="{{ library }}" AGENTIC_AI_LAB_SEMANTIC_SHA256="{{ sha256 }}" timeout --foreground --signal=TERM --kill-after=1s 45s python3 "{{ justfile_directory() }}/packages/python-runtime/tools/watch.py" "{{ executable }}" --exact original_mrr_values_project_to_real_native_poo --nocapture --test-threads=1 2>&1 | tee "$log"
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

# Check the declared ASCENT package through Agentic AI Lab's Observability Case.
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
    AGENTIC_AI_LAB_CEDAR_RUNTIME_HOST="{{ host }}" cargo test --locked --manifest-path {{ cedar_workspace }} -p agentic-ai-lab-cedar-authority --features native-runtime-host-qualification --test runtime_host --test authorization --test case_check

# Qualify the Scheme POO -> native authority -> AOT Host path with one Cedar artifact.
[group('test')]
test-cedar-native host:
    AGENTIC_AI_LAB_CEDAR_RUNTIME_HOST="{{ host }}" cargo test --locked --manifest-path {{ cedar_workspace }} -p agentic-ai-lab-cedar-gerbil --features conformance --test native_authorization

# Replay one data-only case manifest against exported Cedar files and both Host engines.
[group('test')]
test-cedar-case manifest host policy:
    cargo run --locked --quiet --manifest-path {{ cedar_workspace }} -p agentic-ai-lab-cedar-authority --bin cedar-case-check -- "{{ manifest }}" "{{ host }}" "{{ policy }}"

# Run the explicit runtime-C sanitizer gate.
[group('test')]
test-runtime-c-sanitizers:
    {{ bazel }} test --test_output=errors {{ runtime_c_sanitizer_tests }}

# Run the explicit runtime-C leak gate.
[group('test')]
test-runtime-c-leaks:
    {{ bazel }} test --test_output=errors {{ runtime_c_leak_test }}

# Qualify the pinned temporal package with visible case receipts.
[group('test')]
test-ascent-temporal:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss ascent-temporal "{{ gerbil_test_runtime_options }}"

# Persistent worker baseline for matched semantic transport measurements.
[group('test')]
semantic-worker:
    {{ gerbil_darwin_env }} GERBIL_PATH="${GERBIL_PATH:-{{ justfile_directory() }}/.gerbil}" GERBIL_LOADPATH="${GERBIL_LOADPATH:-{{ justfile_directory() }}/.gerbil/lib}" timeout --foreground --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} t/harness/semantic-worker.ss

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

[group('test')]
test-temporal-support:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss temporal-support "{{ gerbil_test_runtime_options }}"

[group('test')]
test-temporal-evaluator:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss temporal-evaluator "{{ gerbil_test_runtime_options }}"

# Original Context/Temporal suites through installed Scheme and upstream gxtest.
[group('test')]
test-context-temporal:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss context-temporal "{{ gerbil_test_runtime_options }}"

# Qualify the default interpreter dispatcher independently of the AOT tool.
[group('test')]
test-gerbil-runtime:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 90s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss gerbil-runtime "{{ gerbil_test_runtime_options }}"
