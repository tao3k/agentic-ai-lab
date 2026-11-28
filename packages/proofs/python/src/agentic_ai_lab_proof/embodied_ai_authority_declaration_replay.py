# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import replace
from hashlib import sha256
import json
from pathlib import Path

from agentic_ai_lab_proof.embodied_ai_authority_declaration import (
    AuthorityAct,
    AuthorityActors,
    AuthorityDeclarationRequest,
    AuthorityIssuerKind,
    AuthorityReceipt,
    AuthorizationSubject,
    _provider_fields_match_countermodel,
    _roles_populated_countermodel,
    evaluate_authority_declaration_admission,
)


IMPLEMENTATION_PATH = Path(__file__).with_name("embodied_ai_authority_declaration.py")


def canonical_request(
    requested_act: AuthorityAct = AuthorityAct.EXECUTION,
) -> AuthorityDeclarationRequest:
    subject = AuthorizationSubject(
        architecture_id="humanoid-architecture-v1",
        bundle_digest="sha256:bundle-v1",
        policy_id="motion-safety-policy-v1",
        resource_id="robot-motion-stack",
        action_id=requested_act.value,
        context_epoch=17,
    )
    receipt = AuthorityReceipt(
        receipt_id=f"receipt-{requested_act.value}",
        issuer_id="human-safety-authority-1",
        issuer_kind=AuthorityIssuerKind.HUMAN_AUTHORITY,
        authority_act=requested_act,
        subject=subject,
        valid_from_epoch=10,
        valid_until_epoch=20,
        revoked_at_epoch=None,
        receipt_valid=True,
        delegation_root="delegation-root-v1",
        responsibility_acceptance_digest="sha256:responsibility-v1",
    )
    return AuthorityDeclarationRequest(
        request_id=f"request-{requested_act.value}",
        candidate_id="ai-provider-candidate-1",
        provider_id="ai-provider-candidate-1",
        requested_act=requested_act,
        current_subject=subject,
        current_epoch=17,
        declared_role=requested_act.value,
        receipt=receipt,
        actors=AuthorityActors(
            proposer_id="human-proposer-1",
            approver_id="human-safety-authority-1",
            executor_id="human-executor-1",
        ),
    )


def replay_cases() -> tuple[tuple[str, AuthorityDeclarationRequest], ...]:
    valid = canonical_request()
    return (
        (
            "provider-role-only-rejected",
            replace(
                valid,
                receipt=replace(
                    valid.receipt,
                    issuer_id=valid.provider_id,
                    issuer_kind=AuthorityIssuerKind.AI_PROVIDER,
                ),
            ),
        ),
        (
            "matching-fields-wrong-authority-act",
            replace(
                valid,
                receipt=replace(valid.receipt, authority_act=AuthorityAct.VERIFICATION),
            ),
        ),
        (
            "stale-subject-context-rejected",
            replace(valid, current_epoch=21),
        ),
        (
            "self-approval-rejected",
            replace(
                valid,
                actors=replace(
                    valid.actors,
                    proposer_id=valid.actors.approver_id,
                ),
            ),
        ),
        (
            "invalid-receipt-rejected",
            replace(valid, receipt=replace(valid.receipt, receipt_valid=False)),
        ),
        ("authority-bearing-declaration-admitted", valid),
    )


def canonical_receipt() -> dict[str, object]:
    cases = []
    for case_id, request in replay_cases():
        decision = evaluate_authority_declaration_admission(request)
        cases.append(
            {
                "admitted": decision.admitted,
                "authorityId": decision.authority_id,
                "caseId": case_id,
                "providerFieldsMatch": _provider_fields_match_countermodel(request),
                "reasonKind": decision.reason_kind,
                "requestedAct": decision.requested_act.value,
                "rolesPopulated": _roles_populated_countermodel(request),
            }
        )

    implementation_digest = f"sha256:{sha256(IMPLEMENTATION_PATH.read_bytes()).hexdigest()}"
    payload: dict[str, object] = {
        "cases": cases,
        "claimId": "EASE-002",
        "implementationArtifactDigest": implementation_digest,
        "implementationArtifactId": (
            "src/agentic_ai_lab_proof/embodied_ai_authority_declaration.py"
        ),
        "referenceTransitionId": (
            "python://src/agentic_ai_lab_proof/embodied_ai_authority_declaration.py"
            "#item/function/evaluate_authority_declaration_admission"
        ),
        "schemaId": "agentic-ai-lab.ai-security.ease002-replay-receipt.v1",
    }
    trace_root = sha256(
        json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    return {**payload, "traceRoot": f"sha256:{trace_root}"}


def main() -> None:
    print(json.dumps(canonical_receipt(), sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
