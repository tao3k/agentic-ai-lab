# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Project a verified AXLE closure into the accepted bundle identity model."""

from __future__ import annotations

from agentic_ai_lab_proof.axle_exact_closure import (
    _normalized_source_declaration_name,
    _source_declaration_aliases,
)

import json
from hashlib import sha256
from pathlib import Path
from typing import Sequence

from agentic_ai_lab_proof.axle_exact_closure import ExactAxleClosure
from agentic_ai_lab_proof.independent_bundle import (
    AxleEnvironmentIdentity,
    DeclarationIdentity,
    IndependentDeclarationBundle,
    ProofBaseInterfaceDeclarationIdentity,
    ResolvedSourceIdentity,
    canonical_proof_base_interface_digest,
)
from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanClosureError,
    LeanDeclarationClosure,
    LeanOwnerSource,
)


class IndependentBundleProjectionError(LeanClosureError):
    """Fail-closed projection error with an actionable ownership detail."""


def _digest(payload: bytes) -> str:
    return f"sha256:{sha256(payload).hexdigest()}"


def _root_package_id(manifest: dict[str, object]) -> str:
    value = manifest.get("name")
    if not isinstance(value, str) or not value:
        raise IndependentBundleProjectionError(
            "lake-manifest-package-name-missing",
            "lake-manifest.json",
        )
    return value.removeprefix("«").removesuffix("»")


def _owner_source_tree_digest(sources: Sequence[LeanOwnerSource]) -> str:
    payload = "\n".join(
        f"{source.owner_path}\0{source.source_digest}"
        for source in sorted(sources, key=lambda source: source.owner_path)
    )
    return _digest(payload.encode())


def _owner_source(
    declaration_name: str,
    *,
    closure: LeanDeclarationClosure,
    sources_by_module: dict[str, LeanOwnerSource],
) -> LeanOwnerSource:
    modules = {
        declaration.owner_module
        for declaration in closure.declarations
        if declaration.name == declaration_name
        or declaration.name.startswith(f"{declaration_name}.")
    }
    if not modules:
        raise IndependentBundleProjectionError(
            "source-declaration-owner-missing",
            declaration_name,
        )
    if len(modules) != 1:
        raise IndependentBundleProjectionError(
            "source-declaration-owner-ambiguous",
            f"{declaration_name}: {sorted(modules)}",
        )
    module = next(iter(modules))
    try:
        return sources_by_module[module]
    except KeyError as error:
        raise IndependentBundleProjectionError(
            "owner-module-source-missing",
            module,
        ) from error


def build_independent_declaration_bundle(
    *,
    closure: LeanDeclarationClosure,
    exact: ExactAxleClosure,
    sources: Sequence[LeanOwnerSource],
    lean_root: Path,
) -> IndependentDeclarationBundle:
    """Build the RFC bundle without introducing another resolver."""

    manifest_path = lean_root / "lake-manifest.json"
    try:
        manifest_bytes = manifest_path.read_bytes()
        manifest = json.loads(manifest_bytes)
    except (OSError, json.JSONDecodeError) as error:
        raise IndependentBundleProjectionError(
            "lake-manifest-unreadable",
            f"{manifest_path}: {error}",
        ) from error
    if not isinstance(manifest, dict):
        raise IndependentBundleProjectionError(
            "lake-manifest-invalid",
            str(manifest_path),
        )

    source_tree_digest = _owner_source_tree_digest(sources)
    resolved_source = ResolvedSourceIdentity(
        package_id=_root_package_id(manifest),
        revision=f"workspace:{source_tree_digest.removeprefix('sha256:')}",
        source_tree_digest=source_tree_digest,
        lake_manifest_digest=_digest(manifest_bytes),
    )
    sources_by_module = {source.module: source for source in sources}
    if all(declaration.source_range is not None for declaration in closure.declarations):
        declaration_aliases = _source_declaration_aliases(closure)
    else:
        declaration_aliases = {
            declaration.name: declaration.name for declaration in closure.declarations
        }
    owned_source_names = set(declaration_aliases.values())
    proof_base_names = {declaration.name for declaration in closure.proof_base_interface}
    owned_exact_declarations = tuple(
        declaration
        for declaration in exact.declarations
        if _normalized_source_declaration_name(
            declaration.name,
            declaration_aliases,
        )
        in owned_source_names
    )
    proof_base_exact_declarations = tuple(
        declaration for declaration in exact.declarations if declaration.name in proof_base_names
    )
    classified_names = {
        declaration.name
        for declaration in (
            *owned_exact_declarations,
            *proof_base_exact_declarations,
        )
    }
    unclassified_names = sorted(
        declaration.name
        for declaration in exact.declarations
        if declaration.name not in classified_names
    )
    if unclassified_names:
        raise IndependentBundleProjectionError(
            "unclassified-exact-declaration",
            ", ".join(unclassified_names),
        )
    proof_base_exact_by_name = {
        declaration.name: declaration for declaration in proof_base_exact_declarations
    }
    proof_base_declarations_list = []
    for declaration in closure.proof_base_interface:
        exact_declaration = proof_base_exact_by_name.get(declaration.name)
        if exact_declaration is None:
            kind = "def" if declaration.declaration_role in {"abbrev", "definition"} else "axiom"
            local_dependencies: tuple[str, ...] = ()
        else:
            kind = exact_declaration.kind
            local_dependencies = tuple(
                sorted(
                    dependency
                    for dependency in exact_declaration.local_dependencies
                    if dependency in proof_base_names and dependency != declaration.name
                )
            )
        proof_base_declarations_list.append(
            ProofBaseInterfaceDeclarationIdentity(
                name=declaration.name,
                kind=kind,
                level_params=declaration.level_params,
                type_source=declaration.type_source,
                value_source=declaration.value_source,
                local_dependencies=local_dependencies,
            )
        )
    proof_base_declarations = tuple(proof_base_declarations_list)
    proof_base_interface_digest = canonical_proof_base_interface_digest(
        closure.proof_base_imports,
        proof_base_declarations,
    )
    declarations = tuple(
        DeclarationIdentity(
            name=declaration.name,
            kind=declaration.kind,
            owner_path=(
                owner := _owner_source(
                    declaration.name,
                    closure=closure,
                    sources_by_module=sources_by_module,
                )
            ).owner_path,
            owner_source_digest=owner.source_digest,
            local_dependencies=declaration.local_dependencies,
        )
        for declaration in owned_exact_declarations
    )
    declaration_aliases = (
        _source_declaration_aliases(closure)
        if all(declaration.source_range is not None for declaration in closure.declarations)
        else {declaration.name: declaration.name for declaration in closure.declarations}
    )
    declarations = tuple(
        DeclarationIdentity(
            name=declaration.name,
            kind=declaration.kind,
            owner_path=declaration.owner_path,
            owner_source_digest=declaration.owner_source_digest,
            local_dependencies=tuple(
                sorted(
                    {
                        _normalized_source_declaration_name(
                            dependency,
                            declaration_aliases,
                        )
                        for dependency in declaration.local_dependencies
                    }
                    - {declaration.name}
                )
            ),
        )
        for declaration in declarations
    )
    environment = AxleEnvironmentIdentity(
        name=exact.environment,
        lean_toolchain=closure.lean_version,
        imports=closure.base_imports,
    )
    return IndependentDeclarationBundle(
        root_module=closure.root_module,
        root_declarations=exact.root_declarations,
        lean_toolchain=closure.lean_version,
        axle_environment=environment,
        resolved_sources=(resolved_source,),
        proof_base_imports=closure.proof_base_imports,
        proof_base_interface_digest=proof_base_interface_digest,
        proof_base_declarations=proof_base_declarations,
        declarations=declarations,
        canonical_source=exact.canonical_source,
    )
