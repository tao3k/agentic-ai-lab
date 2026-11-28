# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import PurePosixPath
import re
from typing import Any


SCHEMA_ID = "agentic-ai-lab.independent-declaration-bundle.v1"
_SHA256_PATTERN = re.compile(r"sha256:[0-9a-f]{64}")


class BundleValidationError(ValueError):
    """Fail-closed validation error for an independent declaration bundle."""

    def __init__(self, code: str, detail: str) -> None:
        self.code = code
        self.detail = detail
        super().__init__(f"{code}: {detail}")


def _require_text(value: str, field: str) -> None:
    if not value or not value.strip():
        raise BundleValidationError("missing-field", field)


def _require_sha256(value: str, field: str) -> None:
    if _SHA256_PATTERN.fullmatch(value) is None:
        raise BundleValidationError("invalid-digest", field)


def _require_owner_path(value: str, field: str) -> None:
    _require_text(value, field)
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts:
        raise BundleValidationError("invalid-owner-path", field)


def _sha256(payload: bytes) -> str:
    return f"sha256:{hashlib.sha256(payload).hexdigest()}"


def _canonical_json(value: dict[str, Any]) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


@dataclass(frozen=True)
class AxleEnvironmentIdentity:
    name: str
    lean_toolchain: str
    imports: tuple[str, ...]
    repo_url: str | None = None
    revision: str | None = None
    subdir: str | None = None

    def __post_init__(self) -> None:
        _require_text(self.name, "environment.name")
        _require_text(self.lean_toolchain, "environment.lean_toolchain")
        if not self.imports:
            raise BundleValidationError(
                "missing-environment-imports",
                "environment.imports",
            )
        for index, import_line in enumerate(self.imports):
            _require_text(import_line, f"environment.imports[{index}]")
        if self.repo_url is None and (
            self.revision is not None or self.subdir is not None
        ):
            raise BundleValidationError(
                "incomplete-environment-source",
                "repo_url is required when revision or subdir is present",
            )
        if self.repo_url is not None:
            _require_text(self.repo_url, "environment.repo_url")
            if self.revision is None:
                raise BundleValidationError(
                    "incomplete-environment-source",
                    "revision is required for a project-aware environment",
                )
            _require_text(self.revision, "environment.revision")

    def canonical_record(self) -> dict[str, Any]:
        return {
            "imports": list(self.imports),
            "lean_toolchain": self.lean_toolchain,
            "name": self.name,
            "repo_url": self.repo_url,
            "revision": self.revision,
            "subdir": self.subdir,
        }


@dataclass(frozen=True)
class ResolvedSourceIdentity:
    package_id: str
    revision: str
    source_tree_digest: str
    lake_manifest_digest: str

    def __post_init__(self) -> None:
        _require_text(self.package_id, "resolved_source.package_id")
        _require_text(self.revision, "resolved_source.revision")
        _require_sha256(
            self.source_tree_digest,
            "resolved_source.source_tree_digest",
        )
        _require_sha256(
            self.lake_manifest_digest,
            "resolved_source.lake_manifest_digest",
        )

    def canonical_record(self) -> dict[str, str]:
        return {
            "lake_manifest_digest": self.lake_manifest_digest,
            "package_id": self.package_id,
            "revision": self.revision,
            "source_tree_digest": self.source_tree_digest,
        }


@dataclass(frozen=True)
class DeclarationIdentity:
    name: str
    kind: str
    owner_path: str
    owner_source_digest: str
    local_dependencies: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        _require_text(self.name, "declaration.name")
        _require_text(self.kind, f"declaration[{self.name}].kind")
        _require_owner_path(
            self.owner_path,
            f"declaration[{self.name}].owner_path",
        )
        _require_sha256(
            self.owner_source_digest,
            f"declaration[{self.name}].owner_source_digest",
        )
        if self.name in self.local_dependencies:
            raise BundleValidationError(
                "self-dependency",
                self.name,
            )
        if len(set(self.local_dependencies)) != len(self.local_dependencies):
            raise BundleValidationError(
                "duplicate-dependency",
                self.name,
            )
        for dependency in self.local_dependencies:
            _require_text(
                dependency,
                f"declaration[{self.name}].local_dependencies",
            )

    def canonical_record(self) -> dict[str, Any]:
        return {
            "kind": self.kind,
            "local_dependencies": sorted(self.local_dependencies),
            "name": self.name,
            "owner_path": self.owner_path,
            "owner_source_digest": self.owner_source_digest,
        }


@dataclass(frozen=True)
class ProofBaseInterfaceDeclarationIdentity:
    name: str
    kind: str
    level_params: tuple[str, ...]
    type_source: str
    value_source: str | None
    local_dependencies: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        _require_text(self.name, "proof_base_declaration.name")
        _require_text(
            self.kind,
            f"proof_base_declaration[{self.name}].kind",
        )
        _require_text(
            self.type_source,
            f"proof_base_declaration[{self.name}].type_source",
        )
        if self.value_source is not None:
            _require_text(
                self.value_source,
                f"proof_base_declaration[{self.name}].value_source",
            )
        if len(set(self.level_params)) != len(self.level_params):
            raise BundleValidationError(
                "proof-base-duplicate-level-parameter",
                self.name,
            )
        for level_param in self.level_params:
            _require_text(
                level_param,
                f"proof_base_declaration[{self.name}].level_params",
            )
        if self.name in self.local_dependencies:
            raise BundleValidationError(
                "proof-base-self-dependency",
                self.name,
            )
        if len(set(self.local_dependencies)) != len(self.local_dependencies):
            raise BundleValidationError(
                "proof-base-duplicate-dependency",
                self.name,
            )
        for dependency in self.local_dependencies:
            _require_text(
                dependency,
                f"proof_base_declaration[{self.name}].local_dependencies",
            )

    def canonical_record(self) -> dict[str, Any]:
        return {
            "kind": self.kind,
            "level_params": list(self.level_params),
            "local_dependencies": sorted(self.local_dependencies),
            "name": self.name,
            "type_source": self.type_source,
            "value_source": self.value_source,
        }

    def canonical_interface_record(self) -> dict[str, Any]:
        return {
            "level_params": list(self.level_params),
            "name": self.name,
            "type_source": self.type_source,
            "value_source": self.value_source,
        }


def canonical_proof_base_interface_digest(
    proof_base_imports: tuple[str, ...],
    proof_base_declarations: tuple[
        ProofBaseInterfaceDeclarationIdentity, ...
    ],
) -> str:
    payload = json.dumps(
        {
            "declarations": [
                declaration.canonical_interface_record()
                for declaration in proof_base_declarations
            ],
            "imports": list(proof_base_imports),
        },
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return _sha256(payload)


@dataclass(frozen=True)
class IndependentDeclarationBundle:
    root_module: str
    root_declarations: tuple[str, ...]
    lean_toolchain: str
    axle_environment: AxleEnvironmentIdentity
    resolved_sources: tuple[ResolvedSourceIdentity, ...]
    proof_base_imports: tuple[str, ...]
    proof_base_interface_digest: str
    proof_base_declarations: tuple[
        ProofBaseInterfaceDeclarationIdentity, ...
    ]
    declarations: tuple[DeclarationIdentity, ...]
    canonical_source: str
    schema_id: str = SCHEMA_ID

    def __post_init__(self) -> None:
        if self.schema_id != SCHEMA_ID:
            raise BundleValidationError(
                "unsupported-schema",
                self.schema_id,
            )
        _require_text(self.root_module, "root_module")
        _require_text(self.lean_toolchain, "lean_toolchain")
        if self.lean_toolchain != self.axle_environment.lean_toolchain:
            raise BundleValidationError(
                "toolchain-mismatch",
                "local and AXLE Lean toolchains differ",
            )
        if not self.root_declarations:
            raise BundleValidationError(
                "missing-root-declaration",
                self.root_module,
            )
        if len(set(self.root_declarations)) != len(self.root_declarations):
            raise BundleValidationError(
                "duplicate-root-declaration",
                self.root_module,
            )
        if not self.resolved_sources:
            raise BundleValidationError(
                "missing-resolved-source",
                self.root_module,
            )
        package_ids = [source.package_id for source in self.resolved_sources]
        if len(set(package_ids)) != len(package_ids):
            raise BundleValidationError(
                "ambiguous-resolved-source",
                self.root_module,
            )
        if len(set(self.proof_base_imports)) != len(self.proof_base_imports):
            raise BundleValidationError(
                "duplicate-proof-base-import",
                self.root_module,
            )
        for proof_base_import in self.proof_base_imports:
            _require_text(proof_base_import, "proof_base_imports")
        _require_sha256(
            self.proof_base_interface_digest,
            "proof_base_interface_digest",
        )
        if bool(self.proof_base_imports) != bool(self.proof_base_declarations):
            raise BundleValidationError(
                "proof-base-interface-mismatch",
                self.root_module,
            )
        computed_proof_base_interface_digest = (
            canonical_proof_base_interface_digest(
                self.proof_base_imports,
                self.proof_base_declarations,
            )
        )
        if (
            self.proof_base_interface_digest
            != computed_proof_base_interface_digest
        ):
            raise BundleValidationError(
                "proof-base-interface-digest-mismatch",
                self.root_module,
            )
        if not self.declarations:
            raise BundleValidationError(
                "missing-declaration-closure",
                self.root_module,
            )
        proof_base_declaration_names = [
            declaration.name for declaration in self.proof_base_declarations
        ]
        declaration_names = [
            declaration.name for declaration in self.declarations
        ]
        if len(set(proof_base_declaration_names)) != len(
            proof_base_declaration_names
        ):
            raise BundleValidationError(
                "duplicate-proof-base-declaration",
                self.root_module,
            )
        if len(set(declaration_names)) != len(declaration_names):
            raise BundleValidationError(
                "duplicate-declaration",
                self.root_module,
            )
        proof_base_declaration_set = set(proof_base_declaration_names)
        declaration_set = set(declaration_names)
        if proof_base_declaration_set & declaration_set:
            raise BundleValidationError(
                "proof-base-source-declaration-overlap",
                self.root_module,
            )
        complete_declaration_set = proof_base_declaration_set | declaration_set
        for root in self.root_declarations:
            if root not in declaration_set:
                raise BundleValidationError(
                    "root-outside-closure",
                    root,
                )
        already_emitted: set[str] = set()
        ordered_declarations = (
            *self.proof_base_declarations,
            *self.declarations,
        )
        for declaration in ordered_declarations:
            for dependency in declaration.local_dependencies:
                if dependency not in complete_declaration_set:
                    raise BundleValidationError(
                        "missing-local-dependency",
                        f"{declaration.name} -> {dependency}",
                    )
                if dependency not in already_emitted:
                    raise BundleValidationError(
                        "non-topological-order",
                        f"{declaration.name} -> {dependency}",
                    )
            already_emitted.add(declaration.name)
        _require_text(self.canonical_source, "canonical_source")

    @property
    def canonical_source_digest(self) -> str:
        return _sha256(self.canonical_source.encode("utf-8"))

    def canonical_manifest(self) -> dict[str, Any]:
        return {
            "axle_environment": self.axle_environment.canonical_record(),
            "canonical_source_digest": self.canonical_source_digest,
            "declarations": [
                declaration.canonical_record()
                for declaration in self.declarations
            ],
            "lean_toolchain": self.lean_toolchain,
            "proof_base_declarations": [
                declaration.canonical_record()
                for declaration in self.proof_base_declarations
            ],
            "proof_base_imports": sorted(self.proof_base_imports),
            "proof_base_interface_digest": self.proof_base_interface_digest,
            "resolved_sources": [
                source.canonical_record()
                for source in sorted(
                    self.resolved_sources,
                    key=lambda source: source.package_id,
                )
            ],
            "root_declarations": sorted(self.root_declarations),
            "root_module": self.root_module,
            "schema_id": self.schema_id,
        }

    @property
    def bundle_digest(self) -> str:
        manifest = _canonical_json(self.canonical_manifest())
        source = self.canonical_source.encode("utf-8")
        return _sha256(manifest + b"\0" + source)
