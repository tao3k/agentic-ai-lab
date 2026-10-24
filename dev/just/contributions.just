# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Execute the root-owned, mechanism-only cross-contribution qualification.
[group('test')]
test-standards-multi-industry-profile-composition:
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ contribution_source_root }}/lambda-aitia:{{ contribution_source_root }}/lambda-episteme:{{ justfile_directory() }}:{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/qualification/standards-multi-industry/profile-composition-test.ss

# Aitia owns the SDLC and GitOps composition and its integration closure.
[group('check')]
check-aitia-integration:
    just build-contribute lambda-aitia
    cd "{{ contribution_source_root }}/lambda-aitia" && GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} ./integration-build.ss compile
    just test-contribute lambda-aitia bindings
    just test-contribute lambda-aitia integration

# Build the self-contained Aitia Scheme-native library and its Aitia-owned consumers.
[group('check')]
check-aitia-native:
    just build-contribute lambda-aitia
    cd "{{ contribution_source_root }}/lambda-aitia" && GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} ./integration-build.ss compile
    mkdir -p "{{ justfile_directory() }}/.gerbil/native"
    cd "{{ contribution_source_root }}/lambda-aitia" && GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} python3 tools/build-native-library.py --output "{{ aitia_native_library }}"
    cc -std=c11 -Wall -Wextra -Werror -pedantic -I"{{ contribution_source_root }}/lambda-aitia/bindings/c/include" "{{ contribution_source_root }}/lambda-aitia/bindings/c/tests/aitia-header-harness.c" -o "{{ justfile_directory() }}/.gerbil/native/aitia_header_harness"
    "{{ justfile_directory() }}/.gerbil/native/aitia_header_harness"
    cc -std=c11 -Wall -Wextra -Werror -pedantic -I"{{ contribution_source_root }}/lambda-aitia/bindings/c/include" "{{ contribution_source_root }}/lambda-aitia/bindings/c/tests/aitia-dynamic-harness.c" -o "{{ justfile_directory() }}/.gerbil/native/aitia_dynamic_harness"
    "{{ justfile_directory() }}/.gerbil/native/aitia_dynamic_harness" "{{ aitia_native_library }}"
    just test-contribute lambda-aitia bindings
    cd "{{ aitia_python_dir }}" && {{ gerbil_darwin_env }} uv lock --check
    cd "{{ aitia_python_dir }}" && {{ gerbil_darwin_env }} uv run --locked --extra test python src/lambda_aitia/_native/_build.py
    cd "{{ aitia_python_dir }}" && LAMBDA_AITIA_NATIVE_LIBRARY="{{ aitia_native_library }}" {{ gerbil_darwin_env }} uv run --locked --extra test pytest
    cd "{{ contribution_source_root }}/lambda-aitia" && just build-python-wheel "{{ aitia_native_library }}"

# separate semantic gate; no source acceptance is presented as model checking.


# Qualify Case-owned GQL Sources from the parser owner's package environment.
# Lambda stays independent of gerbil-parser; parser acceptance is not execution.
[group('check')]
check-healthcare-gql: _prepare-gerbil-parser
    cd "{{ contribution_source_root }}/lambda-episteme" && GERBIL_PATH="{{ gerbil_parser_path }}" GERBIL_LOADPATH="{{ contribution_test_library_path }}:{{ gerbil_parser_library_path }}" gerbil interactive -e '(begin (import (only-in :std/misc/ports read-all-as-string) (only-in :agentic-ai-lab/modules/query/gql agentic-ai-lab-query->gql) (only-in :agentic-ai-lab/lambda-episteme/user-interface/scenarios/healthcare/assurance healthcare-case-qualification-gql-paths) (only-in :agentic-ai-lab/lambda-episteme/user-interface/scenarios/healthcare/reasoning HealthcareCaseProfileRelationsQuery HealthcareProfileImpactQuery HealthcarePrescriptionCausalTrajectoryQuery) (only-in :gerbil-parser/languages/gql/iso-39075-2024/parser +gql-syntax-contract+ parse-gql-iso-39075-2024) (only-in :gerbil-parser/src/runtime/artifact parse-artifact-ref parse-artifact-success? parse-artifact-valid? parse-artifact-roundtrip)) (let loop ((queries (list HealthcareCaseProfileRelationsQuery HealthcareProfileImpactQuery HealthcarePrescriptionCausalTrajectoryQuery)) (paths (healthcare-case-qualification-gql-paths)) (receipts (quote ()))) (if (null? paths) (begin (for-each displayln (reverse receipts)) (exit 0)) (let* ((query (car queries)) (path (car paths)) (expected (call-with-input-file path read-all-as-string)) (source (agentic-ai-lab-query->gql query)) (artifact (parse-gql-iso-39075-2024 source)) (accepted? (and (equal? source expected) (parse-artifact-success? artifact) (parse-artifact-valid? artifact) (equal? source (parse-artifact-roundtrip artifact))))) (unless accepted? (displayln (list (cons (quote source) path) (cons (quote exact-projection) (equal? source expected)) (cons (quote accepted) #f))) (exit 1)) (loop (cdr queries) (cdr paths) (cons (list (cons (quote source) path) (cons (quote parser) (quote gerbil-parser)) (cons (quote syntax-contract) +gql-syntax-contract+) (cons (quote source-content-id) (parse-artifact-ref artifact (quote sourceDigest))) (cons (quote grammar-content-id) (parse-artifact-ref artifact (quote grammarDigest))) (cons (quote exact-projection) #t) (cons (quote accepted) #t) (cons (quote roundtrip) #t)) receipts))))))'

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
    FHIR_VALIDATOR_JAR="{{ fhir_validator_jar }}" GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 90s gerbil {{ gerbil_test_runtime_options }} test -v 3 t/qualification/healthcare-fhir-reference-validator/replay-test.ss

# remain independent gates owned by their parser/model-checker lifecycles.
[group('check')]
check-healthcare-lean:
    cd "{{ lean_proof_dir }}" && lake build AgenticAILabScenarioHealthcareProof
    GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ contribution_test_library_path }}:{{ agentic_ai_lab_library_path }}" gerbil interactive -e '(begin (import (only-in :agentic-ai-lab/lambda-episteme/user-interface/scenarios/healthcare/assurance healthcare-publish-lean-refinement-receipt!)) (displayln (healthcare-publish-lean-refinement-receipt!)))'

# Check finite clinical authority transitions through Quint.
[group('check')]
check-healthcare-temporal-model:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group healthcare

# Exact bounded model for the AI-assisted prescription Case.
[group('check')]
check-healthcare-ai-temporal-model:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group healthcare-ai

# Formal-model governance evidence is an explicit assurance gate.
[group('check')]
check-healthcare-standard-migration-model:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group healthcare-migration

[group('check')]
check-healthcare-standard-migration-lean:
    cd "{{ lean_proof_dir }}" && lake build AgenticAILabScenarioHealthcareProof

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
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ contribution_test_path }}" GERBIL_LOADPATH="{{ contribution_test_library_path }}:{{ agentic_ai_lab_library_path }}" timeout --foreground --signal=TERM --kill-after=3s 20s gxi {{ gerbil_test_runtime_options }} ./run-contribute-test.ss "packages/lambda-episteme/t/ontology/qualification/healthcare-case-assurance.ss"

# Build one packaged contribution inside Agentic AI Lab's package environment.
[group('build')]
build-contribute contribution="lambda-episteme":
    case "{{ contribution }}" in lambda-episteme|lambda-aitia) ;; *) echo "unsupported contribution: {{ contribution }}" >&2; exit 64 ;; esac
    cd "{{ contribution_source_root }}/{{ contribution }}" && GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ justfile_directory() }}:{{ agentic_ai_lab_library_path }}" exec {{ gerbil_darwin_env }} gerbil build </dev/null

# Clean one contribution through its native gxpkg package entry.
[group('build')]
clean-contribute contribution="lambda-episteme":
    case "{{ contribution }}" in lambda-episteme|lambda-aitia) ;; *) echo "unsupported contribution: {{ contribution }}" >&2; exit 64 ;; esac
    cd "{{ contribution_source_root }}/{{ contribution }}" && GERBIL_PATH="{{ justfile_directory() }}/.gerbil" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} gerbil clean

# Execute one contribution-owned t/<module-name>/ tree directly with gxtest.
[group('test')]
test-contribute contribution="lambda-aitia" module="sdlc":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ contribution }}" in lambda-episteme|lambda-aitia) ;; *) echo "unsupported contribution: {{ contribution }}" >&2; exit 64 ;; esac
    test_root="$(mktemp -d "${TMPDIR:-/tmp}/agentic-ai-lab-{{ contribution }}-module-test.XXXXXX")"
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
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="$test_root" GERBIL_LOADPATH="{{ contribution_source_root }}/{{ contribution }}:{{ justfile_directory() }}:$test_root/lib:{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 120s gxi {{ gerbil_test_runtime_options }} "$runner" "$test_directory"

# Replay a previously compiled exact test under the opt-in native heap monitor.
[group('test')]
observe-contribute-import-memory contribution="lambda-aitia" module="sdlc" test_file="unit/nasa-certification-test.ss":
    case "{{ contribution }}" in lambda-episteme|lambda-aitia) ;; *) echo "unsupported contribution: {{ contribution }}" >&2; exit 64 ;; esac
    test -f "packages/{{ contribution }}/t/{{ module }}/{{ test_file }}"
    echo "[agentic-ai-lab-observability] phase=import-observer-start owner={{ contribution }} module={{ module }} test={{ test_file }} budget=15s"
    GERBIL_PATH="{{ justfile_directory() }}/.gerbil/contributions/{{ contribution }}/atomic-test" GERBIL_LOADPATH="{{ justfile_directory() }}/.gerbil/contributions/{{ contribution }}/atomic-test/lib:{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=2s 15s gxi {{ gerbil_test_runtime_options }} ./observe-contribute-import.ss "{{ contribution }}" "{{ module }}" "{{ test_file }}"

# Execute one exact test file. Source admission belongs to the native gxtest
# lifecycle and is enabled declaratively by its POO Testing Profile.
[group('test')]
test-contribute-atomic contribution="lambda-aitia" module="sdlc" test_file="unit/nasa-certification-test.ss":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ contribution }}" in lambda-episteme|lambda-aitia) ;; *) echo "unsupported contribution: {{ contribution }}" >&2; exit 64 ;; esac
    test_root="$(mktemp -d "${TMPDIR:-/tmp}/agentic-ai-lab-{{ contribution }}-atomic-test.XXXXXX")"
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
    GERBIL_BUILD_VERBOSE=1 GERBIL_PATH="$test_root" GERBIL_LOADPATH="{{ contribution_source_root }}/{{ contribution }}:{{ justfile_directory() }}:$test_root/lib:{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=3s 60s gxi {{ gerbil_test_runtime_options }} "$runner" "$test_path"

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
