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

# Run the package's single native Scheme test entrypoint.
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

# Keep the root package's native entry independently callable during repairs.
[group('test')]
test-root:
    @echo "[agentic-ai-lab-test-runtime] maxHeap={{ gerbil_test_max_heap }} debug={{ gerbil_test_debug }} scope=worker-process"
    GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 1200s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss package "{{ gerbil_test_runtime_options }}"

# Keep ASP's per-phase test receipts and add process wall/user/system timing.
[group('test')]
test-profile:
    time just test

# Keep Core qualification under its own Justfile.
[group('test')]
test-core:
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" just test

# Run one root-owned Scheme test with the same pre-import heap fence.
[group('test')]
test-file path:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ justfile_directory() }}:{{ agentic_ai_lab_dev_library_path }}" {{ gerbil_darwin_env }} timeout --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} "{{ justfile_directory() }}/core/t/qualification/testing/run.ss" "{{ path }}" "{{ gerbil_test_runtime_options }}" 120 false

# Run wall-clock performance scenarios through the native ASP scheduler,
# outside the ordinary unit-test batches.
[group('test')]
test-performance:
    @echo "[agentic-ai-lab-test-runtime] maxHeap={{ gerbil_test_max_heap }} debug={{ gerbil_test_debug }} scope=worker-process"
    GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}" gerbil {{ gerbil_test_runtime_options }} env ./dev/performance-tests.ss

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
