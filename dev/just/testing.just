# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Keep the 10k scale fixture out of the ordinary unit-test worker. This
# dedicated gate owns its benchmark budget and emits the full native receipt.
[group('test')]
test-standards-resolution-performance:
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 90s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/performance/standards-resolution-performance-test.ss

# Keep the 10k Sources Lock fixture outside the ordinary unit-test worker. The
# Scenario measures canonical construction separately from indexed lookup.
[group('test')]
test-sources-lock-performance:
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 90s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/performance/sources-lock-performance-test.ss

# Run Core and product tests through their init-owned publications.
[group('test')]
test:
    #!/usr/bin/env bash
    set -euo pipefail
    # A maintenance sleep consumes every real Case/runner deadline. Keep the
    # host awake for this parent only; -w releases assertions when it exits.
    if [[ "$(uname -s)" == Darwin ]]; then
        /usr/bin/caffeinate -is -w "$$" &
    fi
    just test-core
    just test-root

# Exercise actual Gerbil progress and an intentional cached-import stall. These
# control fixtures are outside ordinary *-test.ss discovery by design.
[group('test')]
test-native-harness-progress:
    #!/usr/bin/env bash
    set -euo pipefail
    results="{{ agentic_ai_lab_gerbil_path }}/test-results/native-harness"
    mkdir -p "$results"
    {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 20s python3 packages/python-runtime/tools/watch.py gerbil {{ gerbil_test_runtime_options }} test -v 5 -D yuanxu-module-test-observation t/qualification/testing/native-progress-positive.ss > "$results/positive.log" 2>&1
    # CI runners provide POSIX grep; progress admission needs no ripgrep install.
    for marker in '^MODULE-OK ' '^HARNESS-OK ' '^OK$'; do grep -Eq "$marker" "$results/positive.log"; done
    if grep -Eq 'ERROR CASE|ERROR CHECK|ERROR HARNESS|Heap overflow|Stack overflow' "$results/positive.log"; then cat "$results/positive.log"; exit 1; fi
    if {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 20s python3 packages/python-runtime/tools/watch.py gerbil {{ gerbil_test_runtime_options }} test -v 5 -D yuanxu-module-test-observation t/qualification/testing/native-progress-idle.ss > "$results/idle.log" 2>&1; then
        echo 'cached-import stall unexpectedly passed' >&2
        exit 1
    else
        status=$?
        test "$status" -eq 124
    fi
    grep -Eq '^FAIL: five seconds without test progress$' "$results/idle.log"
    echo 'NATIVE-HARNESS-PROGRESS-OK positive=passed cached-import-idle=refused'
    {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 90s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/native-progress-admission.ss "{{ gerbil_test_runtime_options }}"

# Keep the root package's native entry independently callable during repairs.
[group('test')]
test-root: build-testing build-test-workers prepare-test-inputs build-library
    #!/usr/bin/env bash
    set -euo pipefail
    manifest=$(mktemp)
    trap 'rm -f "$manifest"' EXIT
    just test-files > "$manifest"
    # Preparation above is shared, not repeated by every file. The external
    # loop owns isolation; each native Harness retains its own heap and budget.
    # The init-owned inventory contains 315 serial files. This outer queue
    # envelope includes process/setup work; each native worker retains its
    # 120-second fence and each dedicated Context gate keeps 150s.
    python3 packages/automation/native_test_inputs.py --inputs "{{ agentic_ai_lab_gerbil_path }}/test-inputs" -- timeout --signal=TERM --kill-after=5s 7200s bash -euo pipefail -c '
      failed=0
      while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        [[ -f "$file" && "$file" == *-test.ss ]] || { echo "invalid test input: $file" >&2; exit 64; }
        started=$SECONDS
        printf "TEST-FILE-START file=%s\n" "$file"
        if just _test-file "$file" true; then status=0; else status=$?; failed=1; fi
        printf "TEST-FILE-END status=%s elapsed-s=%s file=%s\n" "$status" "$((SECONDS - started))" "$file"
      done < "$1"
      exit "$failed"
    ' -- "$manifest"

# Keep the existing declarative inclusion policy, not a second file scanner.
[private]
test-files:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 60s gxi {{ gerbil_test_runtime_options }} dev/tests.ss list

# Diagnose a long native file with the full package's unchanged process budget.
[group('test')]
test-package-file path: build-test-workers prepare-test-inputs
    mkdir -p "{{ justfile_directory() }}/.gerbil/test-results"
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" python3 packages/automation/native_test_inputs.py --inputs "{{ agentic_ai_lab_gerbil_path }}/test-inputs" -- {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 1200s gxi {{ gerbil_test_runtime_options }} dev/tests.ss run "{{ path }}" "{{ gerbil_test_runtime_options }}" 1200 false

# Keep ASP's per-phase test receipts and add process wall/user/system timing.
[group('test')]
test-profile:
    time just test

# Keep Core qualification under its own Justfile.
[group('test')]
test-core:
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" just test

# Preserve the root workspace's exported compiler/runtime settings for Core too.
[group('test')]
test-core-file path:
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" just test-file "{{ path }}"

# Run one root-owned Scheme test with the same pre-import heap fence.
[group('test')]
test-file path observe="false": build-library (_test-file path observe)

# Diagnose the Gerbil's actual support dependencies without replacing its scheduler.
[group('test')]
test-build-inspection path:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}:{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} dev/tests.ss inspect "{{ path }}" "{{ gerbil_test_runtime_options }}"

# Keep native loader diagnosis outside source preparation and the Gerbil Harness.
[group('test')]
test-native-object path mode="map":
    {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 30s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/native-object-load.ss "{{ path }}" "{{ mode }}"

# Compare the unmodified Gerbil entry against the instrumented entry on one file.
[group('test')]
test-native-gerbil-harness path:
    {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} test "{{ path }}"

[private]
_test-file path observe="false":
    # Preparation and the native worker each retain their own 120-second
    # budget. This outer guard also covers CLI loading and natural shutdown.
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 300s gxi {{ gerbil_test_runtime_options }} dev/tests.ss run "{{ path }}" "{{ gerbil_test_runtime_options }}" 120 "{{ observe }}"

# Use the maintained Nix integration gate and its existing pre-import fences.
[group('test')]
test-nix-file path: build-test-workers prepare-test-inputs
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" python3 packages/automation/native_test_inputs.py --inputs "{{ agentic_ai_lab_gerbil_path }}/test-inputs" -- {{ gerbil_darwin_env }} just --justfile t/qualification/nix/Justfile test "{{ path }}"

# Run wall-clock performance scenarios through the native ASP scheduler,
# outside the ordinary unit-test batches.
[group('test')]
test-performance:
    @echo "[agentic-ai-lab-test-runtime] maxHeap={{ gerbil_test_max_heap }} debug={{ gerbil_test_debug }} scope=worker-process"
    GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" gerbil {{ gerbil_test_runtime_options }} env ./dev/performance-tests.ss

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

# Validate Agentic AI Lab as a clean external Bzlmod dependency.
[group('test')]
test-external-bazel-module:
    python3 -m unittest discover -s t/qualification/external_bazel -p 'external_module_test.py' -v
    python3 t/qualification/external_bazel/external_module.py

# Validate the single source-owned RFC45 module-system ownership map.
[group('test')]
test-module-system-ownership:
    {{ bazel }} test --test_output=errors {{ module_system_owner_tests }}

# Run the focused composition-lifecycle Python gate.
[group('test')]
test-python-composition-lifecycle:
    cd {{ python_runtime_dir }} && uv run --group dev pytest -q {{ composition_lifecycle_tests }}

# Run the complete Python suite in the Bazel-declared Gerbil project environment.
[group('test')]
test-python:
    {{ bazel }} run {{ python_runtime_test_environment }} -- uv run --group dev pytest -q

[group('test')]
model-understanding-compute script:
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s env GERBIL_DEBUG=expansion gxi {{ gerbil_test_runtime_options }} t/model-study/direct-understanding/compute-loader.ss "{{ script }}"

[group('test')]
model-understanding-score expected candidate:
    {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s gxi {{ gerbil_test_runtime_options }} t/model-study/direct-understanding/prediction-score.ss "{{ expected }}" "{{ candidate }}"

# Fixed-schema Orgize source producer through canonical POO Query.
[group('test')]
test-query-orgize-source:
    GERBIL_LOADPATH="{{ justfile_directory() }}${GERBIL_LOADPATH:+:$GERBIL_LOADPATH}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=1s 45s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss query-source "{{ gerbil_test_runtime_options }}"

# Source-level ownership controls; heap fence applies before any imports.
test-module-ownership:
    timeout --foreground --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss module-ownership "{{ gerbil_test_runtime_options }}"
