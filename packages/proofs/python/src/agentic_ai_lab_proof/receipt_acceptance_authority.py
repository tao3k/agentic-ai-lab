# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from .proof_base_receipt_graph import (
    AcceptedReceiptEvidenceV1,
    CanonicalInterfaceV1,
    CanonicalSourceIdentityV1,
    sha256_digest,
)


class ReceiptAcceptanceAuthorityError(ValueError):
    def __init__(self, code: str, detail: str) -> None:
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


@dataclass(frozen=True)
class DeclaredReceiptEvidenceV1:
    engine_identity: str
    canonical_receipt_bytes: bytes
    receipt_digest: str

    def __post_init__(self) -> None:
        if type(self.engine_identity) is not str or not self.engine_identity:
            raise ReceiptAcceptanceAuthorityError(
                "invalid-declared-engine-identity",
                "engine identity must be a non-empty string",
            )
        if type(self.canonical_receipt_bytes) is not bytes:
            raise ReceiptAcceptanceAuthorityError(
                "invalid-declared-receipt-bytes",
                "declared receipt must use canonical bytes",
            )
        computed = sha256_digest(self.canonical_receipt_bytes)
        if self.receipt_digest != computed:
            raise ReceiptAcceptanceAuthorityError(
                "declared-receipt-digest-mismatch",
                f"computed {computed}, declared {self.receipt_digest}",
            )


@dataclass(frozen=True)
class AuthorityVerifiedReceiptEvidenceV1:
    acceptance: AcceptedReceiptEvidenceV1
    source_identity: CanonicalSourceIdentityV1
    independent_bundle_digest: str
    provided_interface: CanonicalInterfaceV1
    root_declarations: tuple[str, ...]

    def __post_init__(self) -> None:
        expected_bindings = (
            self.source_identity.digest,
            self.independent_bundle_digest,
            self.provided_interface.digest,
        )
        actual_bindings = (
            self.acceptance.bound_source_identity_digest,
            self.acceptance.bound_independent_bundle_digest,
            self.acceptance.bound_provided_interface_digest,
        )
        if actual_bindings != expected_bindings:
            raise ReceiptAcceptanceAuthorityError(
                "authority-acceptance-binding-mismatch",
                "authority acceptance must bind its derived identities",
            )
        if type(self.root_declarations) is not tuple:
            raise ReceiptAcceptanceAuthorityError(
                "invalid-authority-root-declarations",
                "authority roots must be a tuple",
            )
        if not self.root_declarations:
            raise ReceiptAcceptanceAuthorityError(
                "empty-authority-root-declarations",
                "authority evidence must bind at least one root declaration",
            )
        if any(
            type(declaration) is not str or not declaration
            for declaration in self.root_declarations
        ):
            raise ReceiptAcceptanceAuthorityError(
                "invalid-authority-root-declaration",
                "authority root declarations must be non-empty strings",
            )
        object.__setattr__(
            self,
            "root_declarations",
            tuple(sorted(self.root_declarations)),
        )


class ReceiptAcceptanceAuthorityV1(Protocol):
    def validate(
        self,
        declared: DeclaredReceiptEvidenceV1,
    ) -> AuthorityVerifiedReceiptEvidenceV1: ...


__all__ = [
    "AuthorityVerifiedReceiptEvidenceV1",
    "DeclaredReceiptEvidenceV1",
    "ReceiptAcceptanceAuthorityError",
    "ReceiptAcceptanceAuthorityV1",
]
