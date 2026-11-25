# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Repository-owned CI orchestration entrypoints.
# GitHub Actions workflows stay thin and delegate dynamic checks here so local
# runs and CI execute the exact same code.

# Run repository license, version, namespace, automation unit, and ORG modularity gates.
[group('ci')]
ci-contracts:
    python3 packages/automation/check_license_contract.py
    python3 packages/automation/check_version_contract.py
    python3 packages/automation/check_namespace_contract.py
    python3 -m unittest discover -s packages/automation/tests -p 'test_*.py'
    python3 packages/automation/org_modularization.py scan --max-lines 1000 --fail-on-unmodularized

# Install/verify Gerbil runtime dependencies, rebuild vendored Core, and link Lab.
[group('ci')]
ci-prepare-gerbil-deps cache_hit="false":
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$HOME/.gerbil/pkg"
    gerbil pkg dir --add git.cons.io/mighty-gerbils/gerbil-directory
    rebuild_dependents=false
    if [ "{{ cache_hit }}" != "true" ] ||
       ! gerbil env gerbil interactive -e '(begin (import :clan/poo/object) (displayln "runtime-dependency-cache-ready"))' >/tmp/gerbil-dependency-cache-check.log 2>&1; then
      gerbil env gerbil interactive packages/automation/runtime-dependencies.ss
      (cd core && GERBIL_PATH="{{ justfile_directory() }}/.gerbil" gerbil env gerbil interactive ../packages/automation/runtime-dependencies.ss)
      rebuild_dependents=true
    fi
    gerbil env gerbil interactive -e '(begin (import :clan/poo/object) (displayln "runtime-dependencies-ready"))'
    (cd core && GERBIL_PATH="{{ justfile_directory() }}/.gerbil" gerbil env gerbil clean)
    gerbil env just build-core
    if "$rebuild_dependents"; then
      gerbil env gerbil interactive packages/automation/runtime-dependencies.ss --rebuild-core-dependents
    fi
    gerbil env gerbil pkg unlink github.com/tao3k/agentic-ai-lab >/dev/null 2>&1 || true
    gerbil env gerbil pkg link github.com/tao3k/agentic-ai-lab "{{ justfile_directory() }}"
    mkdir -p dev/.gerbil/lib

# Run Core build-input-context mutation and publication admission gates.
[group('ci')]
ci-core-gates artifact_dir:
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" just test-build-input-context-mutations "{{ artifact_dir }}"
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" just test-file t/module-publication-test.ss
    cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" just test-file t/module-testing-source-admission-test.ss

# Verify Core authoring zero-carrier assertions and strict receipt markers.
[group('ci')]
ci-authoring-carriers log_path:
    #!/usr/bin/env bash
    set -euo pipefail
    (cd "{{ justfile_directory() }}/core" && GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" /usr/bin/time -p just test-file t/module-authoring-dispatch-work-test.ss) 2>&1 | tee "{{ log_path }}"
    python3 packages/automation/ci_gates.py verify-focused-log "{{ log_path }}"

# Run real selected downstream qualification suites and verify all receipts.
[group('ci')]
ci-qualify-downstreams log_dir:
    python3 packages/automation/ci_gates.py qualify-downstreams --log-dir "{{ log_dir }}"

# Build the Lab development library into an isolated qualification prefix and install dev deps.
[group('ci')]
ci-build-dev-qualification qualification_dir:
    mkdir -p "{{ qualification_dir }}/lib"
    ln -sfn "{{ agentic_ai_lab_gerbil_path }}/pkg" "{{ qualification_dir }}/pkg"
    gerbil env env GERBIL_PATH="{{ qualification_dir }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" just build-library
    cd "{{ justfile_directory() }}/dev" && GERBIL_PATH="{{ agentic_ai_lab_dev_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" gerbil env gerbil interactive ../packages/automation/runtime-dependencies.ss

# Build the Scheme semantic AOT byte boundary into output_dir.
[group('ci')]
ci-semantic-aot output_dir:
    mkdir -p "{{ output_dir }}"
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" python3 bindings/runtime-c/tools/build-semantic.py --output "{{ output_dir }}/libagentic_ai_lab_semantic.{{ runtime_c_extension }}"

# Run declared ASCENT package integration and python-testing cases.
[group('ci')]
ci-ascent-integration:
    gerbil env just test-ascent-integration
    gerbil env just test-ascent-temporal
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" gerbil env python3 -m agentic_ai_lab_testing run --case ascent.source-withdrawal
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" gerbil env python3 -m agentic_ai_lab_testing run --case evidence-ascent.hypothesis-status
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" gerbil env python3 -m agentic_ai_lab_testing run --case model-study.runtime-fixtures

# Run runtime performance scenarios without unit-batch contention.
[group('ci')]
ci-performance:
    gerbil env gxc -O modules/workflow/qualification/ascent-table-expression.ss t/scenarios/performance/ascent-table-expression/baseline.ss
    gerbil env just test-performance
    gerbil env gxi t/scenarios/performance/ascent-table-expression/scenario.ss
    gerbil env gxi t/scenarios/performance/ascent-table-expression-membership/scenario.ss
    gerbil env gxi t/scenarios/performance/ascent-reachability-closure/scenario.ss

# Build Cedar AOT Runtime Host, run Rust qualification tests, and replay artifact cases.
[group('ci')]
ci-cedar-runtime-host host_path:
    AGENTIC_AI_LAB_CEDAR_BUILD_PROFILE=dev python3 packages/automation/build_cedar_runtime_host.py "{{ host_path }}"
    AGENTIC_AI_LAB_CEDAR_RUNTIME_HOST="{{ host_path }}" cargo test --locked --manifest-path "{{ cedar_workspace }}" -p agentic-ai-lab-cedar-authority --features runtime-host-qualification --test runtime_host --test authorization --test case_check
    cargo run --locked --quiet --manifest-path "{{ cedar_workspace }}" -p agentic-ai-lab-cedar-authority --bin cedar-case-check -- bindings/cedar-gerbil/fixtures/atomic-case/manifest.json "{{ host_path }}" bindings/cedar-gerbil/fixtures/atomic-case/policies.cedar
