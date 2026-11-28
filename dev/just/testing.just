# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Keep the 10k scale fixture out of the ordinary unit-test worker. This
# dedicated gate owns its benchmark budget and emits the full runtime receipt.
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
test: build-testing build-test-workers prepare-test-inputs build-library
    #!/usr/bin/env bash
    set -euo pipefail
    # A maintenance sleep consumes every real Case/runner deadline. Keep the
    # host awake for this parent only; -w releases assertions when it exits.
    if [[ "$(uname -s)" == Darwin ]]; then
        /usr/bin/caffeinate -is -w "$$" &
    fi
    just test-core
    just test-root

# Run the development suites through the standard Scheme test entry.
[group('test')]
test-dev:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gerbil {{ gerbil_test_runtime_options }} test dev.ss

# Run Lab test batches with the existing fixture environment and aggregate deadline.
[group('test')]
[positional-arguments]
test-root *paths: test-lab-layout
    {{ lab_test_env }} {{ lab_test_fixtures }} -- {{ gerbil_test_timeout }} 1200s gerbil {{ gerbil_test_runtime_options }} interactive t/harness/run-lab-tests.ss {{ gerbil_test_runtime_options }} {{ lab_test_file_budget }} "$@"

[group('test')]
test-lab-layout:
    {{ lab_test_env }} {{ gerbil_test_timeout }} {{ lab_test_file_budget }} gerbil {{ gerbil_test_runtime_options }} interactive t/harness/run-lab-tests.ss {{ gerbil_test_runtime_options }} {{ lab_test_file_budget }} t/integration/module-publication/loader-ownership-test.ss

[group('test')]
test-testing-integration:
    just test-root t/integration/testing/source-admission-observability-profile-test.ss t/integration/testing/user-interface-live-cicd-case-test.ss

# Diagnose a long runtime file with the full package's unchanged process budget.
[group('test')]
test-package-file path:
    mkdir -p "{{ justfile_directory() }}/.gerbil/test-results"
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}" python3 packages/automation/gerbil_test_inputs.py --inputs "{{ agentic_ai_lab_gerbil_path }}/test-inputs" -- {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 1200s gerbil {{ gerbil_test_runtime_options }} test "{{ path }}"

# Keep the official Harness receipts and add process wall/user/system timing.
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
test-file path observe="false":
    #!/usr/bin/env bash
    set -euo pipefail
    options=()
    case "{{ observe }}" in
      false) ;;
      true) options=(-D yuanxu-module-test-observation) ;;
      trace) options=(-D yuanxu-module-test-observation,yuanxu-module-test-trace) ;;
      *) echo 'observe must be false, true, or trace' >&2; exit 64 ;;
    esac
    {{ lab_test_env }} {{ lab_focused_test_deadline }} gerbil {{ gerbil_test_runtime_options }} test ${options[@]+"${options[@]}"} "{{ path }}"

# Run performance Suites serially through the same official test entry.
[group('test')]
test-performance:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 1200s gerbil {{ gerbil_test_runtime_options }} test 't/performance/...' t/module-system-poo-performance-test-support

# Run the focused composition-lifecycle Python gate.
[group('test')]
test-python-composition-lifecycle:
    cd {{ python_runtime_dir }} && uv run --group dev pytest -q {{ composition_lifecycle_tests }}

# Run Python consumers against the native shared libraries.
[group('test')]
test-python:
    cd {{ python_runtime_dir }} && AGENTIC_AI_LAB_RUNTIME_V0_LIBRARY="{{ runtime_c_output }}/libagentic_ai_lab_runtime_v0.{{ runtime_c_extension }}" uv run --group dev pytest -q

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
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_dev_library_path }}:{{ justfile_directory() }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss module-ownership "{{ gerbil_test_runtime_options }}"
