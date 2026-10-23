# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Build one Lean module and exactly its import closure.  This is the normal
# proof-development gate; it never traverses the AgenticAILabProof aggregate root.
[group('check')]
check-lean-module module:
    [[ "{{ module }}" =~ ^AgenticAILabProof(\.[A-Za-z0-9_]+)+$ ]]
    cd "{{ lean_proof_dir }}" && lake build "{{ module }}"

[group('check')]
check-governance-lean:
    cd "{{ lean_proof_dir }}" && lake build AgenticAILabModuleGovernanceProof

# Prove the shared Object/Entity/Element/Relation/Query ownership laws without
# traversing the repository-wide Lean aggregate.
[group('check')]
check-native-semantic-query-lean:
    cd "{{ lean_proof_dir }}" && lake build YuanxuProof.ModuleSystem.Schema.Query

[group('check')]
check-native-semantic-query-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group query

# Explore the module-owned hypothesis family both to exhaustion and under a
# tighter bound. Each configuration checks every candidate selection order.
[group('check')]
check-temporal-family-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group family

# Model-check append-only temporal evidence revisions and stable as-of cuts.
[group('check')]
check-temporal-revisions-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group revision

# Check the finite reverse-dependency model and the separate LeanPoo 4.34
# certificate target without changing the Cedar-bound Lean 4.31 project.
[group('check')]
check-temporal-invalidation-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group invalidation

[group('check')]
check-temporal-evidence-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group evidence

# Explore both orders of competing conclusion-selection proposals. The
# checked transition is an abstract atomic CAS, not a runtime pointer write.
[group('check')]
check-temporal-conclusion-selection-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group selection

[group('check')]
check-temporal-poo-lean:
    cd "{{ temporal_poo_proof_dir }}" && PATH="{{ justfile_directory() }}/.devenv/profile/bin:$PATH" timeout 120s lake build AgenticAILabTemporalPooProof

# Session lifecycle, WorkTree sharing, and explicit C4 policy proofs belong to
# Agentic AI Lab. MRR receipts are external inputs to these contracts.
[group('check')]
check-session-poo-lean:
    cd "{{ temporal_poo_proof_dir }}" && PATH="{{ justfile_directory() }}/.devenv/profile/bin:$PATH" timeout 120s lake build AgenticAILabSessionProof

# Canonical bytes for the existing cross-language differential test. The VM
# budget precedes the first fixture import, like the normal test entry.
[group('test')]
emit-proof-case-vector:
    GERBIL_PATH="{{ agentic_ai_lab_gerbil_path }}" GERBIL_LOADPATH="{{ agentic_ai_lab_library_path }}" {{ gerbil_darwin_env }} timeout --foreground --signal=TERM --kill-after=5s 60s gxi {{ gerbil_test_runtime_options }} packages/proofs/t/fixtures/emit-proof-case-vector.ss

[group('check')]
check-session-context-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group session

[group('check')]
check-session-proof: check-session-poo-lean check-session-context-quint

[group('check')]
check-context-delta-lean:
    cd "{{ temporal_poo_proof_dir }}" && timeout 120s lean ContextDelta.lean

[group('check')]
check-context-delta-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group context-delta

[group('check')]
check-context-delta-proof: check-context-delta-lean check-context-delta-quint check-context-coverage-quint

[group('check')]
check-context-coverage-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group context-coverage

[group('check')]
check-session-attempt-lean:
    cd "{{ temporal_poo_proof_dir }}" && timeout 120s lean SessionAttempt.lean

[group('check')]
check-session-attempt-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group session-attempt

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
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group context-session-claim

[group('check')]
check-context-session-claim-proof: check-context-org-anchor-lean check-context-session-claim-lean check-context-session-claim-quint

[group('check')]
check-context-temporal-policy-lean:
    cd "{{ temporal_poo_proof_dir }}" && timeout 120s lean ContextTemporalPolicy.lean

[group('check')]
check-context-temporal-lifecycle-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group context-temporal-lifecycle

[group('check')]
check-context-temporal-policy-proof: check-context-temporal-policy-lean check-context-temporal-lifecycle-quint

# Full aggregation is an explicit integration qualification, never the default
# local or pull-request proof gate.
[group('check')]
check-lean-all: check-temporal-poo-lean check-session-poo-lean
    cd "{{ lean_proof_dir }}" && lake build AgenticAILabProof

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
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group all

# Producer mathematical qualification; consumer binding proofs remain in MRR.
check-composition-proof:
    cd proofs/Composition && lake build && lake env lean --run CompositionChecks.lean && lake env lean --run SearchTemporalChecks.lean && lake env lean --run SearchReadinessChecks.lean && lake env lean --run SearchDagChecks.lean && lake env lean CompositionAxioms.lean

# Reuse the existing finite-model runner and exact negative-control admission.
[group('check')]
check-search-attempt-quint:
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group search-attempt
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group search-readiness
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group search-dag
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group search-evidence
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group search-evidence-history
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.quint --group search-inputs

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

# Assessment source and all original falsifying mutations migrated from ASCENT.
[group('check')]
check-assessment-quint: prepare-quint
    PYTHONPATH="{{ justfile_directory() }}/packages/python-testing/src" python3 -m agentic_ai_lab_testing.checks.assessment_formal quint all

[group('check')]
check-assessment-lean:
    cd "{{ lean_proof_dir }}" && lake build AgenticAILabModuleEvidenceAssessmentProof

# Core owns one Lean project; LeanPoo is its pinned dependency.
[group('proof')]
check-core-lean:
    cd "{{ justfile_directory() }}/core" && just proofs-lean
