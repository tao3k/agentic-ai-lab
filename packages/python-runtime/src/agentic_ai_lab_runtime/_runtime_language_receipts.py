# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""POO Contract receipts for ingress admission and artifact projections."""

from __future__ import annotations

from dataclasses import dataclass

from ._protocol_person_abi_schema import (
    CONTRACT_ARTIFACT_PROJECTION_RECEIPT_SCHEMA,
    RUNTIME_ADMISSION_RECEIPT_SCHEMA,
    SOURCE_QUERY_RECEIPT_SCHEMA,
)

SOURCE_REPRESENTATIONS = frozenset({"json", "ast-data"})
CONTRACT_ARTIFACT_KINDS = frozenset(
    {
        "abi-vector",
        "c-header",
        "json-schema",
        "python-type",
        "rust-type",
        "gerbil-poo",
        "lean-proposition",
    }
)
ADMISSION_OUTCOMES = frozenset({"admitted", "rejected"})


def _present(value: object) -> bool:
    return value not in (None, "", (), [])


def _version_present(value: object) -> bool:
    return isinstance(value, str) and _present(value)


@dataclass(frozen=True)
class SourceQueryReceipt:
    """Receipt for the Org/AST query ingress chain."""
    """Identity-preserving receipt for parser/query output before admission."""

    source_language: str
    source_content_id: str
    source_version: str
    parser_id: str
    parser_version: str
    query_id: str
    query_version: str
    selected_node_identities: tuple[str, ...]
    representation: str
    provenance_root: str
    result_digest: str
    schema: str = SOURCE_QUERY_RECEIPT_SCHEMA

    @property
    def failures(self) -> tuple[str, ...]:
        failures: list[str] = []
        if self.schema != SOURCE_QUERY_RECEIPT_SCHEMA:
            failures.append("invalid-source-query-receipt-schema")
        for field, code in (
            (self.source_language, "missing-source-language"),
            (self.source_content_id, "missing-source-content-id"),
            (self.parser_id, "missing-parser-id"),
            (self.query_id, "missing-query-id"),
        ):
            if not _present(field):
                failures.append(code)
        for field, code in (
            (self.source_version, "missing-source-version"),
            (self.parser_version, "missing-parser-version"),
            (self.query_version, "missing-query-version"),
        ):
            if not _version_present(field):
                failures.append(code)
        if not self.selected_node_identities:
            failures.append("missing-selected-node-identities")
        if self.representation not in SOURCE_REPRESENTATIONS:
            failures.append("unsupported-source-representation")
        if not _present(self.provenance_root):
            failures.append("missing-provenance-root")
        if not _present(self.result_digest):
            failures.append("missing-query-result-digest")
        return tuple(failures)

    @property
    def valid(self) -> bool:
        return not self.failures


@dataclass(frozen=True)
class RuntimeLanguageAdmissionReceipt:
    """Admission receipt binding query data to one identified POO Contract."""

    source_query_receipt: SourceQueryReceipt
    contract_id: str
    contract_version: str
    adapter_id: str
    adapter_version: str
    target_language: str
    normalized_semantic_digest: str | None
    admission_outcome: str
    failure_codes: tuple[str, ...] = ()
    schema: str = RUNTIME_ADMISSION_RECEIPT_SCHEMA

    @property
    def source_query_result_digest(self) -> str:
        return self.source_query_receipt.result_digest

    @property
    def failures(self) -> tuple[str, ...]:
        failures: list[str] = []
        if self.schema != RUNTIME_ADMISSION_RECEIPT_SCHEMA:
            failures.append("invalid-admission-receipt-schema")
        if not self.source_query_receipt.valid:
            failures.append("invalid-source-query-receipt")
        for field, code in (
            (self.contract_id, "missing-contract-id"),
            (self.adapter_id, "missing-adapter-id"),
            (self.target_language, "missing-target-language"),
        ):
            if not _present(field):
                failures.append(code)
        for field, code in (
            (self.contract_version, "missing-contract-version"),
            (self.adapter_version, "missing-adapter-version"),
        ):
            if not _version_present(field):
                failures.append(code)
        if self.admission_outcome not in ADMISSION_OUTCOMES:
            failures.append("unsupported-admission-outcome")
        if self.admission_outcome == "admitted":
            if not _present(self.normalized_semantic_digest):
                failures.append("missing-normalized-semantic-digest")
            if self.failure_codes:
                failures.append("admitted-projection-has-failures")
        if self.admission_outcome == "rejected" and not self.failure_codes:
            failures.append("rejected-projection-missing-failures")
        return tuple(failures)

    @property
    def valid(self) -> bool:
        return not self.failures

    @property
    def admitted(self) -> bool:
        return self.valid and self.admission_outcome == "admitted"

    @property
    def normalized_semantics(self) -> tuple[object, ...]:
        """Implementation-neutral identity used by cross-language qualification."""

        return (
            self.contract_id,
            self.contract_version,
            self.source_query_result_digest,
            self.normalized_semantic_digest,
            self.admission_outcome,
        )


@dataclass(frozen=True)
class ContractArtifactProjectionReceipt:
    """Receipt for a POO Contract-derived ABI or language artifact."""

    projection_id: str
    contract_id: str
    contract_version: str
    source_contract_digest: str
    projector_id: str
    projector_version: str
    artifact_kind: str
    artifact_id: str
    output_digest: str
    schema: str = CONTRACT_ARTIFACT_PROJECTION_RECEIPT_SCHEMA

    @property
    def failures(self) -> tuple[str, ...]:
        failures: list[str] = []
        if self.schema != CONTRACT_ARTIFACT_PROJECTION_RECEIPT_SCHEMA:
            failures.append("invalid-artifact-projection-receipt-schema")
        for field, code in (
            (self.projection_id, "missing-projection-id"),
            (self.contract_id, "missing-contract-id"),
            (self.source_contract_digest, "missing-source-contract-digest"),
            (self.projector_id, "missing-projector-id"),
            (self.artifact_id, "missing-artifact-id"),
            (self.output_digest, "missing-output-digest"),
        ):
            if not _present(field):
                failures.append(code)
        for field, code in (
            (self.contract_version, "missing-contract-version"),
            (self.projector_version, "missing-projector-version"),
        ):
            if not _version_present(field):
                failures.append(code)
        if self.artifact_kind not in CONTRACT_ARTIFACT_KINDS:
            failures.append("unsupported-artifact-kind")
        return tuple(failures)

    @property
    def valid(self) -> bool:
        return not self.failures

    @property
    def semantic_source_identity(self) -> tuple[str, str, str]:
        return (
            self.contract_id,
            self.contract_version,
            self.source_contract_digest,
        )
