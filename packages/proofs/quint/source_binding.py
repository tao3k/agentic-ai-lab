# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Check the exact Quint source identity retained by the separate Lean contract.

This checks metadata freshness, not semantic refinement or governance authority.
"""
import hashlib
from pathlib import Path
import re


def check_binding(source: Path, lean: Path, *, digest_name: str = "quintSourceDigest",
                  inventory_name: str = "quintInvariantNames") -> str:
    digest = 'sha256:' + hashlib.sha256(source.read_bytes()).hexdigest()
    text = lean.read_text()
    bound = re.search(r'def ' + re.escape(digest_name) + r' : String :=\s*"([^"]+)"', text)
    if bound is None or bound[1] != digest:
        raise AssertionError('Lean contract retains a stale Quint source digest')
    predicates = re.search(r'def ' + re.escape(inventory_name) + r' : List String :=\s*\[(.*?)\]', text, re.S)
    if predicates is None:
        raise AssertionError('Lean contract omitted its Quint invariant inventory')
    names = re.findall(r'"([^"]+)"', predicates[1])
    qnt = source.read_text()
    if not names or any(not re.search(r'\bval ' + re.escape(n) + r'\s*=', qnt) for n in names):
        raise AssertionError('Lean contract names an absent Quint invariant')
    return digest


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[3]
    digest = check_binding(
        root / 'packages/proofs/quint/HealthcareStandardMigration.qnt',
        root / 'packages/proofs/lean/AgenticAILabProof/Vertical/Healthcare/StandardMigrationRefinement.lean')
    print('QUINT-LEAN-SOURCE-BINDING-OK ' + digest, flush=True)

    delta_digest = check_binding(
        root / 'packages/proofs/quint/ContextDelta.qnt',
        root / 'packages/proofs/lean-poo/ContextDelta.lean')
    print('CONTEXT-DELTA-SOURCE-BINDING-OK ' + delta_digest, flush=True)

    coverage_digest = check_binding(
        root / 'packages/proofs/quint/ContextCoverage.qnt',
        root / 'packages/proofs/lean-poo/ContextDelta.lean',
        digest_name="coverageSourceDigest", inventory_name="coverageInvariantNames")
    print('CONTEXT-COVERAGE-SOURCE-BINDING-OK ' + coverage_digest, flush=True)

    attempt_digest = check_binding(
        root / 'packages/proofs/quint/SessionAttempt.qnt',
        root / 'packages/proofs/lean-poo/SessionAttempt.lean')
    print('SESSION-ATTEMPT-SOURCE-BINDING-OK ' + attempt_digest, flush=True)

    claim_digest = check_binding(
        root / 'packages/proofs/quint/ContextSessionClaim.qnt',
        root / 'packages/proofs/lean-poo/ContextSessionClaim.lean')
    print('CONTEXT-SESSION-CLAIM-SOURCE-BINDING-OK ' + claim_digest, flush=True)

    lifecycle_digest = check_binding(
        root / 'packages/proofs/quint/ContextTemporalLifecycle.qnt',
        root / 'packages/proofs/lean-poo/ContextTemporalPolicy.lean')
    print('CONTEXT-TEMPORAL-LIFECYCLE-SOURCE-BINDING-OK ' + lifecycle_digest, flush=True)

    search_digest = check_binding(
        root / 'packages/proofs/quint/SearchAttempt.qnt',
        root / 'proofs/Composition/SearchAttempt.lean')
    print('SEARCH-ATTEMPT-SOURCE-BINDING-OK ' + search_digest, flush=True)

    readiness_digest = check_binding(
        root / "packages/proofs/quint/SearchReadiness.qnt",
        root / "proofs/Composition/SearchReadiness.lean")
    print("SEARCH-READINESS-SOURCE-BINDING-OK " + readiness_digest, flush=True)

    evidence_digest = check_binding(
        root / "packages/proofs/quint/SearchEvidence.qnt",
        root / "proofs/Composition/SearchEvidence.lean")
    print("SEARCH-EVIDENCE-SOURCE-BINDING-OK " + evidence_digest, flush=True)

    inputs_digest = check_binding(
        root / "packages/proofs/quint/SearchInputs.qnt",
        root / "proofs/Composition/SearchEvidence.lean",
        digest_name="inputsQuintSourceDigest", inventory_name="inputsQuintInvariantNames")
    print("SEARCH-INPUTS-SOURCE-BINDING-OK " + inputs_digest, flush=True)

    history_digest = check_binding(
        root / "packages/proofs/quint/SearchEvidenceHistory.qnt",
        root / "proofs/Composition/SearchEvidenceHistory.lean",
        digest_name="historySourceDigest", inventory_name="historyInvariantNames")
    print("SEARCH-EVIDENCE-HISTORY-SOURCE-BINDING-OK " + history_digest, flush=True)

    dag_digest = check_binding(
        root / "packages/proofs/quint/SearchDag.qnt",
        root / "proofs/Composition/SearchDag.lean")
    print("SEARCH-DAG-SOURCE-BINDING-OK " + dag_digest, flush=True)
