# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Exact AXLE projection for a Lean-owned declaration closure.

Lean remains the authority for constant dependency closure.  AXLE is used only
to collapse generated Lean constants to their owning source declarations,
canonicalize those declarations, and verify the resulting independent source.
"""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from time import monotonic
from typing import Any, Awaitable, Callable, Mapping, Sequence, TypeVar

from axle import AxleClient

from agentic_ai_lab_proof.axle_verify import message_payload
from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanClosureError,
    LeanDeclarationClosure,
    LeanOwnerSource,
    LeanSourceRange,
)

SCHEMA_ID = "agentic-ai-lab.axle-exact-declaration-closure.v1"
PHASE_SCHEMA_ID = "agentic-ai-lab.axle-phase.v1"
DEFAULT_OPERATION_TIMEOUT_SECONDS = 10.0
DEFAULT_BASE_TIMEOUT_SECONDS = 2.0

PhaseObserver = Callable[[Mapping[str, object]], None]
PhaseResult = TypeVar("PhaseResult")


class AxleExactClosureError(LeanClosureError):
    """Fail-closed error raised while projecting or verifying the AXLE bundle."""


@dataclass(frozen=True)
class SourceDeclaration:
    name: str
    kind: str
    declaration: str
    local_dependencies: tuple[str, ...]


@dataclass(frozen=True)
class ExactAxleClosure:
    lean_closure_digest: str
    environment: str
    root_declarations: tuple[str, ...]
    source_declarations: tuple[str, ...]
    declarations: tuple[SourceDeclaration, ...]
    canonical_source: str
    theorem2sorry: Mapping[str, Any]
    verification: Mapping[str, Any]
    schema_id: str = SCHEMA_ID

    @property
    def canonical_source_digest(self) -> str:
        return _digest(self.canonical_source.encode())

    @property
    def bundle_digest(self) -> str:
        return _digest(_canonical_json(self.identity_manifest()).encode())

    def identity_manifest(self) -> dict[str, Any]:
        return {
            "schema_id": self.schema_id,
            "lean_closure_digest": self.lean_closure_digest,
            "environment": self.environment,
            "root_declarations": list(self.root_declarations),
            "source_declarations": list(self.source_declarations),
            "declarations": [
                {
                    "name": declaration.name,
                    "kind": declaration.kind,
                    "local_dependencies": list(declaration.local_dependencies),
                }
                for declaration in self.declarations
            ],
            "canonical_source_digest": self.canonical_source_digest,
        }

    def canonical_manifest(self) -> dict[str, Any]:
        return {
            **self.identity_manifest(),
            "bundle_digest": self.bundle_digest,
            "canonical_source": self.canonical_source,
            "theorem2sorry": dict(self.theorem2sorry),
            "verification": dict(self.verification),
        }


def _digest(payload: bytes) -> str:
    return f"sha256:{sha256(payload).hexdigest()}"


def _canonical_json(value: Mapping[str, Any]) -> str:
    import json

    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)


def _errors(response: Any) -> tuple[str, ...]:
    return tuple(response.lean_messages.errors) + tuple(response.tool_messages.errors)


def _require_clean(response: Any, operation: str) -> None:
    errors = _errors(response)
    if errors:
        raise AxleExactClosureError(
            "axle-projection-failed",
            f"{operation}: {' | '.join(errors)}",
        )


async def _run_phase(
    phase: str,
    *,
    payload_bytes: int,
    observer: PhaseObserver | None,
    operation: Awaitable[PhaseResult],
) -> PhaseResult:
    started = monotonic()
    if observer is not None:
        observer(
            {
                "schema_id": PHASE_SCHEMA_ID,
                "phase": phase,
                "state": "started",
                "payload_bytes": payload_bytes,
                "elapsed_ms": 0,
            }
        )
    try:
        result = await operation
    except BaseException as error:
        if observer is not None:
            observer(
                {
                    "schema_id": PHASE_SCHEMA_ID,
                    "phase": phase,
                    "state": "failed",
                    "payload_bytes": payload_bytes,
                    "elapsed_ms": round((monotonic() - started) * 1000),
                    "error_type": type(error).__name__,
                }
            )
        raise
    if observer is not None:
        observer(
            {
                "schema_id": PHASE_SCHEMA_ID,
                "phase": phase,
                "state": "completed",
                "payload_bytes": payload_bytes,
                "elapsed_ms": round((monotonic() - started) * 1000),
            }
        )
    return result


def _document_dependencies(document: Any) -> tuple[str, ...]:
    return tuple(
        dict.fromkeys(
            [
                *document.local_type_dependencies,
                *document.local_value_dependencies,
                *document.local_syntactic_dependencies,
            ]
        )
    )


def _covering_document(name: str, document_names: Sequence[str]) -> str | None:
    candidates = [
        document_name
        for document_name in document_names
        if name == document_name or name.startswith(f"{document_name}.")
    ]
    return max(candidates, key=len, default=None)


def _normalized_source_declaration_name(
    name: str,
    declaration_aliases: Mapping[str, str],
) -> str:
    candidates = [
        declaration_name
        for declaration_name in declaration_aliases
        if name == declaration_name or name.startswith(f"{declaration_name}.")
    ]
    if candidates:
        return declaration_aliases[max(candidates, key=len)]

    if name.startswith("«_") and "»" in name:
        internal_owner = name[2:].split("»", maxsplit=1)[0]
        normalized_internal_owner = _normalized_source_declaration_name(
            internal_owner,
            declaration_aliases,
        )
        if (
            normalized_internal_owner != internal_owner
            or internal_owner in declaration_aliases.values()
        ):
            return normalized_internal_owner

    generated_instance_anchors = []
    for anchor in set(declaration_aliases.values()):
        anchor_namespace, _, anchor_base_name = anchor.rpartition(".")
        generated_head = name.removeprefix(f"{anchor_namespace}.").split(
            ".",
            maxsplit=1,
        )[0]
        if (
            anchor_namespace
            and name.startswith(f"{anchor_namespace}.inst")
            and generated_head.endswith(anchor_base_name)
        ):
            generated_instance_anchors.append(anchor)
    if generated_instance_anchors:
        return max(generated_instance_anchors, key=len)
    return name


def source_declaration_closure(
    *,
    lean_declarations: Sequence[str],
    root_declarations: Sequence[str],
    documents: Mapping[str, Any],
    declaration_aliases: Mapping[str, str] | None = None,
) -> tuple[str, ...]:
    """Collapse Lean constants and AXLE dependencies to source declarations."""

    aliases = declaration_aliases or {}

    def source_name(name: str) -> str:
        candidates = [
            declaration_name
            for declaration_name in aliases
            if name == declaration_name or name.startswith(f"{declaration_name}.")
        ]
        if candidates:
            owner = max(candidates, key=len)
            return aliases[owner]
        generated_instance_anchors = [
            anchor
            for anchor in set(aliases.values())
            if (
                name.startswith(f"{(anchor_namespace := anchor.rpartition('.')[0])}.inst")
                and name.removeprefix(f"{anchor_namespace}.")
                .split(".", maxsplit=1)[0]
                .endswith(anchor.removeprefix(f"{anchor_namespace}."))
            )
        ]
        if generated_instance_anchors:
            return max(generated_instance_anchors, key=len)
        return name

    by_name = {document.name: document for document in documents.values()}
    document_names = tuple(by_name)
    selected: set[str] = set()

    for declaration in lean_declarations:
        owner = _covering_document(source_name(declaration), document_names)
        if owner is None:
            raise AxleExactClosureError(
                "lean-constant-without-source-declaration",
                declaration,
            )
        selected.add(owner)

    for root in root_declarations:
        owner = _covering_document(source_name(root), document_names)
        if owner is None:
            raise AxleExactClosureError("root-without-source-declaration", root)
        selected.add(owner)

    pending = list(selected)
    while pending:
        name = pending.pop()
        for dependency in _document_dependencies(by_name[name]):
            owner = _covering_document(source_name(dependency), document_names)
            if owner is None:
                raise AxleExactClosureError(
                    "local-dependency-without-source-declaration",
                    f"{name} -> {dependency}",
                )
            if owner not in selected:
                selected.add(owner)
                pending.append(owner)

    dependencies = {
        name: {
            owner
            for dependency in _document_dependencies(by_name[name])
            if (
                owner := _covering_document(
                    source_name(dependency),
                    document_names,
                )
            )
            in selected
            and owner != name
        }
        for name in selected
    }
    return _topological_order(dependencies)


def _topological_order(dependencies: Mapping[str, set[str]]) -> tuple[str, ...]:
    ordered: list[str] = []
    visiting: list[str] = []
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visited:
            return
        if name in visiting:
            cycle_start = visiting.index(name)
            cycle = (*visiting[cycle_start:], name)
            raise AxleExactClosureError(
                "source-declaration-cycle",
                " -> ".join(cycle),
            )
        visiting.append(name)
        for dependency in sorted(dependencies[name]):
            visit(dependency)
        visiting.pop()
        visited.add(name)
        ordered.append(name)

    for name in sorted(dependencies):
        visit(name)
    return tuple(ordered)


def _utf16_prefix(text: str, units: int) -> str:
    encoded = text.encode("utf-16-le")
    boundary = units * 2
    if boundary > len(encoded):
        raise AxleExactClosureError(
            "source-range-outside-line",
            f"utf16={units}; available={len(encoded) // 2}",
        )
    try:
        return encoded[:boundary].decode("utf-16-le")
    except UnicodeDecodeError as error:
        raise AxleExactClosureError(
            "source-range-splits-codepoint",
            f"utf16={units}",
        ) from error


def _slice_source_range(source: str, source_range: LeanSourceRange) -> str:
    lines = source.splitlines(keepends=True)
    if source_range.end_line > len(lines):
        raise AxleExactClosureError(
            "source-range-outside-file",
            f"end-line={source_range.end_line}; lines={len(lines)}",
        )
    start_index = source_range.start_line - 1
    end_index = source_range.end_line - 1
    start_line = lines[start_index]
    end_line = lines[end_index]
    start_prefix = _utf16_prefix(start_line, source_range.start_char_utf16)
    end_prefix = _utf16_prefix(end_line, source_range.end_char_utf16)
    if start_index == end_index:
        return end_prefix[len(start_prefix) :]
    return "".join(
        (
            start_line[len(start_prefix) :],
            *lines[start_index + 1 : end_index],
            end_prefix,
        )
    )


def _range_key(source_range: LeanSourceRange) -> tuple[int, int]:
    return (source_range.start_line, source_range.start_char_utf16)


def _range_end_key(source_range: LeanSourceRange) -> tuple[int, int]:
    return (source_range.end_line, source_range.end_char_utf16)


def _range_contains(
    outer: LeanSourceRange,
    inner: LeanSourceRange,
) -> bool:
    return _range_key(outer) <= _range_key(inner) and _range_end_key(inner) <= _range_end_key(outer)


def _coalesce_source_ranges(
    ranged_declarations: Mapping[LeanSourceRange, Sequence[str]],
) -> tuple[tuple[LeanSourceRange, tuple[str, ...]], ...]:
    coalesced: list[tuple[LeanSourceRange, list[str]]] = []
    ordered = sorted(
        ranged_declarations,
        key=lambda source_range: (
            source_range.start_line,
            source_range.start_char_utf16,
            -source_range.end_line,
            -source_range.end_char_utf16,
        ),
    )
    for source_range in ordered:
        names = list(ranged_declarations[source_range])
        containing = next(
            (
                existing_names
                for existing_range, existing_names in coalesced
                if _range_contains(existing_range, source_range)
            ),
            None,
        )
        if containing is not None:
            containing.extend(names)
            continue
        overlapping = next(
            (
                existing_range
                for existing_range, _ in coalesced
                if _range_key(source_range) < _range_end_key(existing_range)
            ),
            None,
        )
        if overlapping is not None:
            raise AxleExactClosureError(
                "partially-overlapping-source-ranges",
                f"{overlapping} <> {source_range}",
            )
        coalesced.append((source_range, names))
    return tuple((source_range, tuple(dict.fromkeys(names))) for source_range, names in coalesced)


def _source_declaration_aliases(
    closure: LeanDeclarationClosure,
) -> dict[str, str]:
    declarations_by_module: dict[
        str,
        dict[LeanSourceRange, list[str]],
    ] = {}
    declaration_by_name = {declaration.name: declaration for declaration in closure.declarations}
    for declaration in closure.declarations:
        if declaration.source_range is None:
            raise AxleExactClosureError(
                "declaration-source-range-missing",
                declaration.name,
            )
        declarations_by_module.setdefault(
            declaration.owner_module,
            {},
        ).setdefault(declaration.source_range, []).append(declaration.name)

    aliases: dict[str, str] = {}
    for ranged_declarations in declarations_by_module.values():
        for outer_range, names in _coalesce_source_ranges(ranged_declarations):
            outer_names = [
                name for name in names if declaration_by_name[name].source_range == outer_range
            ]
            if not outer_names:
                raise AxleExactClosureError(
                    "source-declaration-anchor-missing",
                    ",".join(names),
                )
            anchor = min(
                outer_names,
                key=lambda name: (name.count("."), len(name), name),
            )
            for name in names:
                aliases[name] = anchor
    return aliases


def _selected_open_commands(
    source_text: str,
    *,
    source_module: str,
    selected_modules: set[str],
) -> tuple[str, ...]:
    parent_namespace, _, _ = source_module.rpartition(".")
    opened: list[str] = []
    for line in source_text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("open "):
            continue
        for target in stripped.removeprefix("open ").split():
            candidates = (
                target,
                f"{parent_namespace}.{target}" if parent_namespace else target,
            )
            resolved = next(
                (candidate for candidate in candidates if candidate in selected_modules),
                None,
            )
            if resolved is not None:
                opened.append(f"open {resolved}")
    return tuple(dict.fromkeys(opened))


def _compose_owner_sources(
    closure: LeanDeclarationClosure,
    sources: Sequence[LeanOwnerSource],
) -> str:
    bodies: list[str] = []
    declarations_by_module: dict[
        str,
        dict[LeanSourceRange, list[str]],
    ] = {}
    for declaration in closure.declarations:
        if declaration.source_range is None:
            raise AxleExactClosureError(
                "declaration-source-range-missing",
                declaration.name,
            )
        declarations_by_module.setdefault(
            declaration.owner_module,
            {},
        ).setdefault(declaration.source_range, []).append(declaration.name)
    selected_modules = set(declarations_by_module)
    proof_base_namespaces = {
        namespace
        for declaration in closure.proof_base_interface
        if (namespace := declaration.name.rpartition(".")[0])
    }
    visible_modules = selected_modules | set(closure.proof_base_imports) | proof_base_namespaces
    for source in sources:
        source_text = source.path.read_text()
        ranged_declarations = declarations_by_module.get(source.module, {})
        coalesced = _coalesce_source_ranges(ranged_declarations)
        if not coalesced:
            raise AxleExactClosureError(
                "owner-source-without-ranged-declaration",
                source.module,
            )
        open_commands = "\n".join(
            _selected_open_commands(
                source_text,
                source_module=source.module,
                selected_modules=visible_modules,
            )
        )
        declaration_chunks = [
            _slice_source_range(source_text, source_range).strip() for source_range, _ in coalesced
        ]
        declarations = "\n\n".join(declaration_chunks)
        context = f"{open_commands}\n\n" if open_commands else ""
        declarations_are_fully_qualified = all(
            any(declaration_name in declaration_chunk for declaration_name in declaration_names)
            for (_source_range, declaration_names), declaration_chunk in zip(
                coalesced,
                declaration_chunks,
                strict=True,
            )
        )
        if declarations_are_fully_qualified:
            bodies.append(f"{context}{declarations}")
        else:
            bodies.append(
                f"namespace {source.module}\n\n{context}{declarations}\n\nend {source.module}"
            )
    imports = "\n".join(f"import {base_import}" for base_import in closure.base_imports)
    namespace_prelude = "\n".join(
        f"namespace {module}\nend {module}"
        for module in sorted(visible_modules | proof_base_namespaces)
    )
    proof_base_universes = sorted(
        {
            level_param
            for declaration in closure.proof_base_interface
            for level_param in declaration.level_params
        }
    )
    universe_prelude = f"universe {' '.join(proof_base_universes)}" if proof_base_universes else ""
    proof_base_declarations = "\n\n".join(
        (
            f"{'abbrev' if declaration.declaration_role == 'abbrev' else 'def' if declaration.declaration_role == 'definition' else 'axiom'} "
            f"{declaration.name}"
            f" : {declaration.type_source}"
            f"{' := ' + declaration.value_source if declaration.value_source is not None else ''}"
        )
        for declaration in closure.proof_base_interface
    )
    proof_base_instances = tuple(
        declaration.name
        for declaration in closure.proof_base_interface
        if declaration.declaration_role == "instance"
    )
    proof_base_instance_attributes = "\n".join(
        f"attribute [local instance] {name}" for name in proof_base_instances
    )
    noncomputable_projection = "noncomputable section" if proof_base_instances else ""
    proof_base_prelude = "\n\n".join(
        part
        for part in (
            universe_prelude,
            proof_base_declarations,
            proof_base_instance_attributes,
            noncomputable_projection,
        )
        if part
    )
    return (
        f"{imports}\n\n{namespace_prelude}\n\n{proof_base_prelude}\n\n" + "\n\n".join(bodies) + "\n"
    )


def _compose_source_declarations(
    names: Sequence[str],
    documents: Mapping[str, Any],
    base_imports: Sequence[str],
) -> str:
    declarations: list[str] = []
    known_names = tuple(names)
    for name in names:
        namespace, separator, _ = name.rpartition(".")
        declaration = documents[name].declaration.strip()
        dependency_namespaces = {
            owner.rpartition(".")[0]
            for dependency in _document_dependencies(documents[name])
            if (owner := _covering_document(dependency, known_names)) is not None
            and owner != name
            and owner.rpartition(".")[0] != namespace
        }
        opened = "\n".join(
            f"open {dependency_namespace}" for dependency_namespace in sorted(dependency_namespaces)
        )
        declaration_head = declaration.splitlines()[0]
        if name in declaration_head:
            declarations.append(f"{opened}\n\n{declaration}" if opened else declaration)
        elif separator:
            context = f"\n{opened}\n" if opened else "\n"
            declarations.append(f"namespace {namespace}\n{context}{declaration}\n\nend {namespace}")
        else:
            declarations.append(f"{opened}\n\n{declaration}" if opened else declaration)
    imports = "\n".join(f"import {base_import}" for base_import in base_imports)
    return f"{imports}\n\n" + "\n\n".join(declarations) + "\n"


async def build_exact_axle_closure(
    *,
    closure: LeanDeclarationClosure,
    sources: Sequence[LeanOwnerSource],
    environment: str,
    client: AxleClient | None = None,
    operation_timeout_seconds: float = DEFAULT_OPERATION_TIMEOUT_SECONDS,
    base_timeout_seconds: float = DEFAULT_BASE_TIMEOUT_SECONDS,
    phase_observer: PhaseObserver | None = None,
) -> ExactAxleClosure:
    """Build and verify an exact source-level bundle in one AXLE event loop."""

    if operation_timeout_seconds <= 0 or base_timeout_seconds <= 0:
        raise AxleExactClosureError(
            "invalid-axle-timeout",
            (f"operation={operation_timeout_seconds};base={base_timeout_seconds}"),
        )
    owned_client = client is None
    active_client = client or AxleClient(base_timeout_seconds=base_timeout_seconds)
    try:
        root_package = closure.root_module.partition(".")[0]
        external_owner_modules = tuple(
            sorted(
                {
                    source.module
                    for source in sources
                    if source.module.partition(".")[0] != root_package
                }
            )
        )
        if external_owner_modules:
            raise AxleExactClosureError(
                "external-proof-base-required",
                (
                    f"root_package={root_package}; "
                    f"external_owner_modules={external_owner_modules}; "
                    "declare external dependencies through --base-import or "
                    "--proof-base-import"
                ),
            )
        combined_source = _compose_owner_sources(closure, sources)
        extracted = await _run_phase(
            "owner-source-extract",
            payload_bytes=len(combined_source.encode()),
            observer=phase_observer,
            operation=active_client.extract_decls(
                combined_source,
                environment,
                ignore_imports=False,
                timeout_seconds=operation_timeout_seconds,
            ),
        )
        _require_clean(extracted, "extract composed owner sources")
        declaration_aliases = _source_declaration_aliases(closure)
        proof_base_names = {declaration.name for declaration in closure.proof_base_interface}

        source_names = tuple(
            name
            for name in source_declaration_closure(
                lean_declarations=[declaration.name for declaration in closure.declarations],
                root_declarations=closure.root_declarations,
                documents=extracted.documents,
                declaration_aliases=declaration_aliases,
            )
            if name not in proof_base_names
        )
        canonical_source = combined_source
        canonical_roots = tuple(
            _covering_document(root, source_names) or _raise_root_without_source(root)
            for root in closure.root_declarations
        )
        canonical_payload_bytes = len(canonical_source.encode())
        roundtrip = await _run_phase(
            "canonical-roundtrip-extract",
            payload_bytes=canonical_payload_bytes,
            observer=phase_observer,
            operation=active_client.extract_decls(
                canonical_source,
                environment,
                ignore_imports=False,
                timeout_seconds=operation_timeout_seconds,
            ),
        )
        _require_clean(roundtrip, "extract exact merged closure")
        roundtrip_by_name = {document.name: document for document in roundtrip.documents.values()}
        actual_names = tuple(document.name for document in roundtrip.documents.values())
        expected_names = source_names
        actual_names = tuple(
            sorted(
                {
                    normalized_name
                    for name in actual_names
                    if (
                        normalized_name := _normalized_source_declaration_name(
                            name,
                            declaration_aliases,
                        )
                    )
                    not in proof_base_names
                }
            )
        )
        if set(actual_names) != set(expected_names):
            missing = sorted(set(expected_names) - set(actual_names))
            extra = sorted(set(actual_names) - set(expected_names))
            raise AxleExactClosureError(
                "exact-roundtrip-mismatch",
                f"missing={missing}; extra={extra}",
            )

        root_declaration_kinds = {root: roundtrip_by_name[root].kind for root in canonical_roots}
        if any(not kind.strip() for kind in root_declaration_kinds.values()):
            raise AxleExactClosureError(
                "invalid-root-declaration-kind",
                repr(root_declaration_kinds),
            )
        theorem_roots = tuple(
            root for root, kind in root_declaration_kinds.items() if kind == "theorem"
        )

        if theorem_roots:
            statement = await _run_phase(
                "root-theorem2sorry",
                payload_bytes=canonical_payload_bytes,
                observer=phase_observer,
                operation=active_client.theorem2sorry(
                    canonical_source,
                    environment,
                    names=list(theorem_roots),
                    ignore_imports=False,
                    timeout_seconds=operation_timeout_seconds,
                ),
            )
            _require_clean(statement, "theorem2sorry exact closure roots")

            verified = await _run_phase(
                "root-proof-verify",
                payload_bytes=canonical_payload_bytes + len(statement.content.encode()),
                observer=phase_observer,
                operation=active_client.verify_proof(
                    statement.content,
                    canonical_source,
                    environment,
                    ignore_imports=False,
                    timeout_seconds=operation_timeout_seconds,
                ),
            )
            _require_clean(verified, "verify exact declaration closure")
            if not verified.okay or verified.failed_declarations:
                raise AxleExactClosureError(
                    "exact-proof-verification-failed",
                    ", ".join(verified.failed_declarations),
                )

            theorem2sorry_receipt = {
                "schema_id": "agentic-ai-lab.axle-root-theorem-obligation.v1",
                "status": "generated",
                "root_declarations": theorem_roots,
                "root_declaration_kinds": root_declaration_kinds,
                "request": statement.info,
                "messages": {
                    "lean": message_payload(statement.lean_messages),
                    "tool": message_payload(statement.tool_messages),
                },
            }
            verification_receipt = {
                "schema_id": "agentic-ai-lab.axle-root-declaration-validation.v1",
                "status": "accepted",
                "roundtrip": "accepted",
                "theorem_proof": "accepted",
                "okay": verified.okay,
                "failed_declarations": verified.failed_declarations,
                "lean_messages": message_payload(verified.lean_messages),
                "tool_messages": message_payload(verified.tool_messages),
                "timings": verified.timings,
                "request": verified.info,
            }
        else:
            theorem2sorry_receipt = {
                "schema_id": "agentic-ai-lab.axle-root-theorem-obligation.v1",
                "status": "not-applicable",
                "root_declarations": (),
                "root_declaration_kinds": root_declaration_kinds,
            }
            verification_receipt = {
                "schema_id": "agentic-ai-lab.axle-root-declaration-validation.v1",
                "status": "accepted",
                "roundtrip": "accepted",
                "theorem_proof": "not-applicable",
                "okay": True,
                "failed_declarations": (),
                "lean_messages": (),
                "tool_messages": (),
                "timings": {},
                "request": {
                    "root_declarations": canonical_roots,
                    "root_declaration_kinds": root_declaration_kinds,
                },
            }

        exact_declaration_names = tuple(
            dict.fromkeys(
                (
                    *expected_names,
                    *(name for name in sorted(proof_base_names) if name in roundtrip_by_name),
                )
            )
        )
        declarations = tuple(
            SourceDeclaration(
                name=name,
                kind=roundtrip_by_name[name].kind,
                declaration=roundtrip_by_name[name].declaration,
                local_dependencies=tuple(
                    dependency
                    for dependency in _document_dependencies(roundtrip_by_name[name])
                    if dependency in roundtrip_by_name
                ),
            )
            for name in exact_declaration_names
        )
        return ExactAxleClosure(
            lean_closure_digest=closure.closure_digest,
            environment=environment,
            root_declarations=canonical_roots,
            source_declarations=source_names,
            declarations=declarations,
            canonical_source=canonical_source,
            theorem2sorry=theorem2sorry_receipt,
            verification=verification_receipt,
        )
    finally:
        if owned_client:
            await active_client.close()


def _raise_root_without_source(root: str) -> str:
    raise AxleExactClosureError("root-without-source-declaration", root)
