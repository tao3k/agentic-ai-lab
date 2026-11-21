# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from dataclasses import replace

from agentic_ai_lab_runtime.protocol_person_abi import (
    ContractArtifactProjectionReceipt,
    RuntimeLanguageAdmissionReceipt,
    SourceQueryReceipt,
)


def source_query_receipt(
    *,
    representation: str = "json",
    selected_node_identities: tuple[str, ...] = ("node-17", "node-23"),
    result_digest: str = "query-result-digest-json-1",
) -> SourceQueryReceipt:
    return SourceQueryReceipt(
        source_language="org",
        source_content_id="org-content-blake3-1",
        source_version="7",
        parser_id="orgize",
        parser_version="0.10",
        query_id="promotion-candidates",
        query_version="3",
        selected_node_identities=selected_node_identities,
        representation=representation,
        provenance_root="org-provenance-root-1",
        result_digest=result_digest,
    )


def test_org_query_json_and_ast_data_remain_valid_ingress_data() -> None:
    json_result = source_query_receipt()
    ast_result = source_query_receipt(
        representation="ast-data",
        result_digest="query-result-digest-ast-1",
    )
    assert json_result.valid
    assert ast_result.valid
    assert json_result.source_language == "org"


def test_source_query_identity_and_provenance_fail_closed() -> None:
    missing_nodes = source_query_receipt(
        selected_node_identities=(), result_digest=""
    )
    unsupported = source_query_receipt(representation="raw-text")
    numeric_version = replace(source_query_receipt(), source_version=7)
    assert not missing_nodes.valid
    assert "missing-selected-node-identities" in missing_nodes.failures
    assert "missing-query-result-digest" in missing_nodes.failures
    assert not unsupported.valid
    assert "unsupported-source-representation" in unsupported.failures
    assert not numeric_version.valid
    assert "missing-source-version" in numeric_version.failures


def test_runtime_language_admission_requires_poo_contract() -> None:
    query = source_query_receipt()
    python = RuntimeLanguageAdmissionReceipt(
        source_query_receipt=query,
        contract_id="agentic-ai-lab.runtime-language.promotion-request.1",
        contract_version="1",
        adapter_id="agentic-ai-lab-python-runtime",
        adapter_version="0.1",
        target_language="python",
        normalized_semantic_digest="normalized-contract-semantics-1",
        admission_outcome="admitted",
    )
    marlin = RuntimeLanguageAdmissionReceipt(
        source_query_receipt=query,
        contract_id="agentic-ai-lab.runtime-language.promotion-request.1",
        contract_version="1",
        adapter_id="marlin-gerbil-scheme",
        adapter_version="0.1",
        target_language="rust",
        normalized_semantic_digest="normalized-contract-semantics-1",
        admission_outcome="admitted",
    )
    illegal = RuntimeLanguageAdmissionReceipt(
        source_query_receipt=query,
        contract_id="",
        contract_version="1",
        adapter_id="agentic-ai-lab-python-runtime",
        adapter_version="0.1",
        target_language="python",
        normalized_semantic_digest="normalized-contract-semantics-1",
        admission_outcome="admitted",
        failure_codes=("ignored-failure",),
    )
    assert python.admitted
    assert marlin.admitted
    assert python.normalized_semantics == marlin.normalized_semantics
    assert not illegal.valid
    assert illegal.failures == (
        "missing-contract-id",
        "admitted-projection-has-failures",
    )


def test_contract_artifact_projection_does_not_require_source_query() -> None:
    vector = ContractArtifactProjectionReceipt(
        projection_id="promotion-request-vector-v1",
        contract_id="agentic-ai-lab.runtime-language.promotion-request.1",
        contract_version="1",
        source_contract_digest="poo-contract-digest-1",
        projector_id="agentic-ai-lab-runtime-v0-abi-projector",
        projector_version="0.3",
        artifact_kind="abi-vector",
        artifact_id=(
            "t/fixtures/runtime-language-abi/promotion-request-v1.vector"
        ),
        output_digest="promotion-vector-digest-1",
    )
    header = ContractArtifactProjectionReceipt(
        projection_id="runtime-v0-c-header-v3",
        contract_id="agentic-ai-lab.runtime-v0.abi-schema.1",
        contract_version="1",
        source_contract_digest="runtime-v0-contract-digest-1",
        projector_id="agentic-ai-lab-runtime-v0-abi-projector",
        projector_version="0.3",
        artifact_kind="c-header",
        artifact_id=(
            "bindings/runtime-c/include/agentic_ai_lab/runtime_v0_contract.h"
        ),
        output_digest="runtime-v0-header-digest-1",
    )
    invalid = ContractArtifactProjectionReceipt(
        projection_id="invalid-projection",
        contract_id="agentic-ai-lab.runtime-language.promotion-request.1",
        contract_version="1",
        source_contract_digest="poo-contract-digest-1",
        projector_id="agentic-ai-lab-runtime-v0-abi-projector",
        projector_version="0.3",
        artifact_kind="raw-text",
        artifact_id="invalid-artifact",
        output_digest="",
    )
    assert vector.valid
    assert header.valid
    assert vector.semantic_source_identity == (
        "agentic-ai-lab.runtime-language.promotion-request.1",
        "1",
        "poo-contract-digest-1",
    )
    assert not invalid.valid
    assert invalid.failures == (
        "missing-output-digest",
        "unsupported-artifact-kind",
    )
