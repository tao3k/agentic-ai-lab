# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from argparse import Namespace
from contextlib import redirect_stderr, redirect_stdout
from dataclasses import dataclass
from io import StringIO
import json
from pathlib import Path
import re
from tempfile import TemporaryDirectory
from typing import Any, Callable

from .axle_closure_verify import run as run_axle_closure_verify
from .proof_base_receipt_graph import (
    AcceptedReceiptEvidenceV1,
    CanonicalInterfaceV1,
    CanonicalSourceIdentityV1,
    sha256_digest,
)
from .receipt_acceptance_authority import (
    AuthorityVerifiedReceiptEvidenceV1,
    DeclaredReceiptEvidenceV1,
    ReceiptAcceptanceAuthorityError,
)


AXLE_RECEIPT_ENGINE_IDENTITY_V1 = "agentic-ai-lab-axle-verify"
AXLE_PROVIDED_INTERFACE_SCHEMA_V1 = (
    "agentic-ai-lab.axle-provided-interface.v1"
)
AXLE_SOURCE_IDENTITY_SCHEMA_V1 = "agentic-ai-lab.axle-source-identity.v1"

_SHA256_PATTERN = re.compile(r"sha256:[0-9a-f]{64}")

_TOP_LEVEL_KEYS = frozenset(
    {
        "closure",
        "exact_bundle",
        "exact_bundle_digest",
        "independent_declaration_bundle",
        "independent_declaration_bundle_digest",
        "preflight",
    }
)
_CLOSURE_KEYS = frozenset(
    {
        "base_imports",
        "declarations",
        "lean_version",
        "owner_modules",
        "proof_base_imports",
        "proof_base_interface",
        "root_declarations",
        "root_module",
        "schema_id",
    }
)
_PREFLIGHT_KEYS = frozenset(
    {
        "axle_base_timeout_seconds",
        "axle_environment",
        "axle_operation_timeout_seconds",
        "closure_digest",
        "declaration_count",
        "lean_export_timeout_seconds",
        "owner_sources",
        "proof_base_imports",
        "proof_base_interface_count",
        "root_declarations",
        "root_module",
        "schema_id",
    }
)
_EXACT_BUNDLE_KEYS = frozenset(
    {
        "bundle_digest",
        "canonical_source",
        "canonical_source_digest",
        "declarations",
        "environment",
        "lean_closure_digest",
        "root_declarations",
        "schema_id",
        "source_declarations",
        "theorem2sorry",
        "verification",
    }
)
_INDEPENDENT_BUNDLE_KEYS = frozenset(
    {
        "axle_environment",
        "canonical_source_digest",
        "declarations",
        "lean_toolchain",
        "proof_base_declarations",
        "proof_base_imports",
        "proof_base_interface_digest",
        "resolved_sources",
        "root_declarations",
        "root_module",
        "schema_id",
    }
)
_VERIFICATION_KEYS = frozenset(
    {
        "failed_declarations",
        "lean_messages",
        "okay",
        "request",
        "roundtrip",
        "schema_id",
        "status",
        "theorem_proof",
        "timings",
        "tool_messages",
    }
)
_THEOREM2SORRY_KEYS = frozenset(
    {
        "messages",
        "request",
        "root_declaration_kinds",
        "root_declarations",
        "schema_id",
        "status",
    }
)


def _canonical_json(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def _duplicate_key_rejecting_object(
    pairs: list[tuple[str, Any]],
) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ReceiptAcceptanceAuthorityError(
                "duplicate-axle-receipt-key",
                f"duplicate object key {key}",
            )
        result[key] = value
    return result


def _exact_object(
    value: Any,
    *,
    label: str,
    keys: frozenset[str],
) -> dict[str, Any]:
    if type(value) is not dict:
        raise ReceiptAcceptanceAuthorityError(
            "axle-receipt-type-mismatch",
            f"{label} must be an object",
        )
    actual = frozenset(value)
    if actual != keys:
        raise ReceiptAcceptanceAuthorityError(
            "axle-receipt-shape-mismatch",
            (
                f"{label} missing={sorted(keys - actual)} "
                f"unknown={sorted(actual - keys)}"
            ),
        )
    return value


def _string(value: Any, *, label: str) -> str:
    if type(value) is not str or not value:
        raise ReceiptAcceptanceAuthorityError(
            "axle-receipt-type-mismatch",
            f"{label} must be a non-empty string",
        )
    return value


def _string_tuple(value: Any, *, label: str) -> tuple[str, ...]:
    if type(value) is not list:
        raise ReceiptAcceptanceAuthorityError(
            "axle-receipt-type-mismatch",
            f"{label} must be an array",
        )
    result = tuple(_string(item, label=label) for item in value)
    if len(set(result)) != len(result):
        raise ReceiptAcceptanceAuthorityError(
            "duplicate-axle-receipt-value",
            f"{label} must not repeat values",
        )
    return result


def _digest(value: Any, *, label: str) -> str:
    digest = _string(value, label=label)
    if _SHA256_PATTERN.fullmatch(digest) is None:
        raise ReceiptAcceptanceAuthorityError(
            "invalid-axle-receipt-digest",
            f"{label} must be a canonical sha256 digest",
        )
    return digest


@dataclass(frozen=True)
class AxleClosureVerificationRequestV1:
    environment: str
    root_module: str
    root_declarations: tuple[str, ...]
    base_imports: tuple[str, ...]
    proof_base_imports: tuple[str, ...]


@dataclass(frozen=True)
class ParsedAxleClosureArtifactV1:
    manifest: dict[str, Any]
    canonical_bytes: bytes
    request: AxleClosureVerificationRequestV1
    exact_bundle_digest: str
    independent_bundle_digest: str
    canonical_source_digest: str
    source_identity: CanonicalSourceIdentityV1
    provided_interface: CanonicalInterfaceV1

    def authority_identity_components(self) -> dict[str, Any]:
        return {
            "request": self.request,
            "exact_bundle_digest": self.exact_bundle_digest,
            "independent_bundle_digest": self.independent_bundle_digest,
            "canonical_source_digest": self.canonical_source_digest,
            "source_identity": self.source_identity,
            "provided_interface": self.provided_interface,
        }


def parse_axle_closure_artifact_v1(
    artifact_bytes: bytes,
    *,
    require_canonical_bytes: bool,
) -> ParsedAxleClosureArtifactV1:
    if type(artifact_bytes) is not bytes:
        raise ReceiptAcceptanceAuthorityError(
            "invalid-axle-receipt-bytes",
            "AXLE receipt artifact must be bytes",
        )
    try:
        manifest = json.loads(
            artifact_bytes.decode("utf-8"),
            object_pairs_hook=_duplicate_key_rejecting_object,
        )
    except ReceiptAcceptanceAuthorityError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ReceiptAcceptanceAuthorityError(
            "invalid-axle-receipt-json",
            str(error),
        ) from error

    artifact = _exact_object(
        manifest,
        label="artifact",
        keys=_TOP_LEVEL_KEYS,
    )
    closure = _exact_object(
        artifact["closure"],
        label="closure",
        keys=_CLOSURE_KEYS,
    )
    preflight = _exact_object(
        artifact["preflight"],
        label="preflight",
        keys=_PREFLIGHT_KEYS,
    )
    exact = _exact_object(
        artifact["exact_bundle"],
        label="exact_bundle",
        keys=_EXACT_BUNDLE_KEYS,
    )
    independent = _exact_object(
        artifact["independent_declaration_bundle"],
        label="independent_declaration_bundle",
        keys=_INDEPENDENT_BUNDLE_KEYS,
    )
    verification = _exact_object(
        exact["verification"],
        label="exact_bundle.verification",
        keys=_VERIFICATION_KEYS,
    )
    _exact_object(
        exact["theorem2sorry"],
        label="exact_bundle.theorem2sorry",
        keys=_THEOREM2SORRY_KEYS,
    )

    expected_schemas = (
        (
            closure,
            "agentic-ai-lab.lean-declaration-closure.v1",
            "closure",
        ),
        (
            preflight,
            "agentic-ai-lab.axle-closure-preflight.v1",
            "preflight",
        ),
        (
            exact,
            "agentic-ai-lab.axle-exact-declaration-closure.v1",
            "exact_bundle",
        ),
        (
            independent,
            "agentic-ai-lab.independent-declaration-bundle.v1",
            "independent_declaration_bundle",
        ),
        (
            verification,
            "agentic-ai-lab.axle-root-declaration-validation.v1",
            "exact_bundle.verification",
        ),
    )
    for value, expected_schema, label in expected_schemas:
        if value["schema_id"] != expected_schema:
            raise ReceiptAcceptanceAuthorityError(
                "invalid-axle-receipt-schema",
                f"{label} expected {expected_schema}",
            )

    if verification["status"] != "accepted":
        raise ReceiptAcceptanceAuthorityError(
            "axle-receipt-not-accepted",
            "AXLE verification status must be accepted",
        )
    if verification["okay"] is not True:
        raise ReceiptAcceptanceAuthorityError(
            "axle-receipt-not-okay",
            "AXLE verification okay must be true",
        )
    if verification["failed_declarations"] != []:
        raise ReceiptAcceptanceAuthorityError(
            "axle-receipt-has-failures",
            "AXLE verification must have zero failed declarations",
        )

    root_sets = (
        _string_tuple(
            closure["root_declarations"],
            label="closure.root_declarations",
        ),
        _string_tuple(
            preflight["root_declarations"],
            label="preflight.root_declarations",
        ),
        _string_tuple(
            exact["root_declarations"],
            label="exact_bundle.root_declarations",
        ),
        _string_tuple(
            independent["root_declarations"],
            label="independent.root_declarations",
        ),
    )
    canonical_roots = tuple(sorted(root_sets[0]))
    if any(
        tuple(sorted(root_declarations)) != canonical_roots
        for root_declarations in root_sets[1:]
    ):
        raise ReceiptAcceptanceAuthorityError(
            "axle-root-declaration-mismatch",
            "all AXLE owner artifacts must bind the same roots",
        )

    root_module = _string(
        closure["root_module"],
        label="closure.root_module",
    )
    if (
        preflight["root_module"] != root_module
        or independent["root_module"] != root_module
    ):
        raise ReceiptAcceptanceAuthorityError(
            "axle-root-module-mismatch",
            "closure, preflight, and independent bundle roots must agree",
        )

    proof_base_imports = _string_tuple(
        closure["proof_base_imports"],
        label="closure.proof_base_imports",
    )
    if (
        _string_tuple(
            preflight["proof_base_imports"],
            label="preflight.proof_base_imports",
        )
        != proof_base_imports
        or _string_tuple(
            independent["proof_base_imports"],
            label="independent.proof_base_imports",
        )
        != proof_base_imports
    ):
        raise ReceiptAcceptanceAuthorityError(
            "axle-proof-base-import-mismatch",
            "all AXLE owner artifacts must bind the same proof-base imports",
        )

    canonical_source_digest = _digest(
        exact["canonical_source_digest"],
        label="exact_bundle.canonical_source_digest",
    )
    if (
        independent["canonical_source_digest"]
        != canonical_source_digest
    ):
        raise ReceiptAcceptanceAuthorityError(
            "axle-canonical-source-digest-mismatch",
            "exact and independent bundles must bind the same source",
        )

    exact_bundle_digest = _digest(
        artifact["exact_bundle_digest"],
        label="exact_bundle_digest",
    )
    if exact["bundle_digest"] != exact_bundle_digest:
        raise ReceiptAcceptanceAuthorityError(
            "axle-exact-bundle-digest-mismatch",
            "top-level and exact bundle digests must agree",
        )
    independent_bundle_digest = _digest(
        artifact["independent_declaration_bundle_digest"],
        label="independent_declaration_bundle_digest",
    )

    canonical_bytes = _canonical_json(artifact)
    if require_canonical_bytes and artifact_bytes != canonical_bytes:
        raise ReceiptAcceptanceAuthorityError(
            "noncanonical-axle-receipt-bytes",
            "AXLE authority receipt must use the unique v1 JSON encoding",
        )

    source_identity_bytes = _canonical_json(
        {
            "canonical_source": exact["canonical_source"],
            "canonical_source_digest": canonical_source_digest,
            "resolved_sources": independent["resolved_sources"],
            "root_module": root_module,
            "schema_id": AXLE_SOURCE_IDENTITY_SCHEMA_V1,
        }
    )
    provided_interface_bytes = _canonical_json(
        {
            "canonical_source": exact["canonical_source"],
            "canonical_source_digest": canonical_source_digest,
            "declarations": exact["declarations"],
            "exact_bundle_digest": exact_bundle_digest,
            "root_declarations": list(canonical_roots),
            "schema_id": AXLE_PROVIDED_INTERFACE_SCHEMA_V1,
            "source_declarations": exact["source_declarations"],
        }
    )

    return ParsedAxleClosureArtifactV1(
        manifest=artifact,
        canonical_bytes=canonical_bytes,
        request=AxleClosureVerificationRequestV1(
            environment=_string(
                exact["environment"],
                label="exact_bundle.environment",
            ),
            root_module=root_module,
            root_declarations=root_sets[0],
            base_imports=_string_tuple(
                closure["base_imports"],
                label="closure.base_imports",
            ),
            proof_base_imports=proof_base_imports,
        ),
        exact_bundle_digest=exact_bundle_digest,
        independent_bundle_digest=independent_bundle_digest,
        canonical_source_digest=canonical_source_digest,
        source_identity=CanonicalSourceIdentityV1(
            canonical_bytes=source_identity_bytes,
            digest=sha256_digest(source_identity_bytes),
        ),
        provided_interface=CanonicalInterfaceV1(
            canonical_bytes=provided_interface_bytes,
            digest=sha256_digest(provided_interface_bytes),
        ),
    )


def declare_axle_closure_receipt_v1(
    artifact_bytes: bytes,
) -> DeclaredReceiptEvidenceV1:
    parsed = parse_axle_closure_artifact_v1(
        artifact_bytes,
        require_canonical_bytes=False,
    )
    return DeclaredReceiptEvidenceV1(
        engine_identity=AXLE_RECEIPT_ENGINE_IDENTITY_V1,
        canonical_receipt_bytes=parsed.canonical_bytes,
        receipt_digest=sha256_digest(parsed.canonical_bytes),
    )


@dataclass(frozen=True)
class AxleClosureReceiptAuthorityV1:
    reverify: Callable[[AxleClosureVerificationRequestV1], bytes]

    def validate(
        self,
        declared: DeclaredReceiptEvidenceV1,
    ) -> AuthorityVerifiedReceiptEvidenceV1:
        if declared.engine_identity != AXLE_RECEIPT_ENGINE_IDENTITY_V1:
            raise ReceiptAcceptanceAuthorityError(
                "wrong-receipt-authority",
                f"expected {AXLE_RECEIPT_ENGINE_IDENTITY_V1}",
            )
        claimed = parse_axle_closure_artifact_v1(
            declared.canonical_receipt_bytes,
            require_canonical_bytes=True,
        )
        fresh_bytes = self.reverify(claimed.request)
        fresh = parse_axle_closure_artifact_v1(
            fresh_bytes,
            require_canonical_bytes=False,
        )
        claimed_identity = claimed.authority_identity_components()
        fresh_identity = fresh.authority_identity_components()
        mismatched_components = sorted(
            key
            for key in claimed_identity
            if claimed_identity[key] != fresh_identity[key]
        )
        if mismatched_components:
            raise ReceiptAcceptanceAuthorityError(
                "axle-owner-reverification-mismatch",
                (
                    "fresh AXLE owner result differs in "
                    f"{mismatched_components}"
                ),
            )

        acceptance = AcceptedReceiptEvidenceV1(
            engine_identity=AXLE_RECEIPT_ENGINE_IDENTITY_V1,
            canonical_receipt_bytes=declared.canonical_receipt_bytes,
            receipt_digest=declared.receipt_digest,
            bound_source_identity_digest=fresh.source_identity.digest,
            bound_independent_bundle_digest=(
                fresh.independent_bundle_digest
            ),
            bound_provided_interface_digest=fresh.provided_interface.digest,
            decision="accepted",
        )
        return AuthorityVerifiedReceiptEvidenceV1(
            acceptance=acceptance,
            source_identity=fresh.source_identity,
            independent_bundle_digest=fresh.independent_bundle_digest,
            provided_interface=fresh.provided_interface,
            root_declarations=fresh.request.root_declarations,
        )


@dataclass(frozen=True)
class LiveAxleClosureReceiptAuthorityV1:
    lean_root: Path
    lean_export_timeout_seconds: float
    axle_operation_timeout_seconds: float
    axle_base_timeout_seconds: float

    def validate(
        self,
        declared: DeclaredReceiptEvidenceV1,
    ) -> AuthorityVerifiedReceiptEvidenceV1:
        authority = AxleClosureReceiptAuthorityV1(
            reverify=self._reverify,
        )
        return authority.validate(declared)

    def _reverify(
        self,
        request: AxleClosureVerificationRequestV1,
    ) -> bytes:
        with TemporaryDirectory(
            prefix="agentic-ai-lab-axle-receipt-authority-"
        ) as temporary_directory:
            output = Path(temporary_directory) / "closure.json"
            owner_stdout = StringIO()
            owner_stderr = StringIO()
            with (
                redirect_stdout(owner_stdout),
                redirect_stderr(owner_stderr),
            ):
                result = run_axle_closure_verify(
                    Namespace(
                        paths=[],
                        environment=request.environment,
                        lean_root=self.lean_root,
                        root_module=request.root_module,
                        root_declarations=list(request.root_declarations),
                        base_imports=list(request.base_imports),
                        closure_output=output,
                        proof_base_imports=list(request.proof_base_imports),
                        lean_export_timeout_seconds=(
                            self.lean_export_timeout_seconds
                        ),
                        axle_operation_timeout_seconds=(
                            self.axle_operation_timeout_seconds
                        ),
                        axle_base_timeout_seconds=(
                            self.axle_base_timeout_seconds
                        ),
                    )
                )
            if result != 0:
                raise ReceiptAcceptanceAuthorityError(
                    "axle-owner-reverification-failed",
                    (
                        f"AXLE closure verification returned {result}; "
                        f"stderr_digest={sha256_digest(owner_stderr.getvalue().encode())}"
                    ),
                )
            if not output.is_file():
                raise ReceiptAcceptanceAuthorityError(
                    "axle-owner-receipt-missing",
                    "AXLE closure verification did not emit its artifact",
                )
            return output.read_bytes()


__all__ = [
    "AXLE_PROVIDED_INTERFACE_SCHEMA_V1",
    "AXLE_RECEIPT_ENGINE_IDENTITY_V1",
    "AXLE_SOURCE_IDENTITY_SCHEMA_V1",
    "AxleClosureReceiptAuthorityV1",
    "AxleClosureVerificationRequestV1",
    "LiveAxleClosureReceiptAuthorityV1",
    "ParsedAxleClosureArtifactV1",
    "declare_axle_closure_receipt_v1",
    "parse_axle_closure_artifact_v1",
]
