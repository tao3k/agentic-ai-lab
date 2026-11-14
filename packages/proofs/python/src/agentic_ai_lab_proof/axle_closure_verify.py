# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import argparse
import asyncio
from collections.abc import Callable
import json
from pathlib import Path
import sys
from typing import Sequence

from agentic_ai_lab_proof import axle_verify as axle_verify  # noqa: F401
from agentic_ai_lab_proof.axle_exact_closure import build_exact_axle_closure
from agentic_ai_lab_proof.independent_bundle_projection import (
    build_independent_declaration_bundle,
)
from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanClosureError,
    LeanDeclarationClosure,
    LeanOwnerSource,
    export_declaration_closure,
    resolve_owner_sources,
)


RECEIPT_SCHEMA_ID = "agentic-ai-lab.axle-closure-preflight.v1"


def _environment_version(environment: str) -> str | None:
    prefix = "lean-"
    if environment.startswith(prefix):
        return environment.removeprefix(prefix)
    return None


def _verify_environment(
    closure: LeanDeclarationClosure,
    environment: str,
) -> None:
    expected = _environment_version(environment)
    if expected is not None and expected != closure.lean_version:
        raise LeanClosureError(
            "axle-environment-toolchain-mismatch",
            f"{environment} != Lean {closure.lean_version}",
        )


def _verify_paths(
    provided: Sequence[Path],
    sources: Sequence[LeanOwnerSource],
) -> tuple[Path, ...]:
    expected = tuple(source.path.resolve() for source in sources)
    if not provided:
        return expected
    actual = tuple(path.resolve() for path in provided)
    if set(actual) != set(expected) or len(actual) != len(expected):
        raise LeanClosureError(
            "axle-source-set-mismatch",
            (f"expected={','.join(map(str, expected))};actual={','.join(map(str, actual))}"),
        )
    order = {path: index for index, path in enumerate(expected)}
    return tuple(sorted(actual, key=order.__getitem__))


def _preflight_receipt(
    closure: LeanDeclarationClosure,
    sources: Sequence[LeanOwnerSource],
    environment: str,
    lean_export_timeout_seconds: float,
    operation_timeout_seconds: float,
    base_timeout_seconds: float,
) -> dict[str, object]:
    return {
        "axle_environment": environment,
        "axle_base_timeout_seconds": base_timeout_seconds,
        "axle_operation_timeout_seconds": operation_timeout_seconds,
        "lean_export_timeout_seconds": lean_export_timeout_seconds,
        "proof_base_imports": list(closure.proof_base_imports),
        "proof_base_interface_count": len(closure.proof_base_interface),
        "closure_digest": closure.closure_digest,
        "declaration_count": len(closure.declarations),
        "owner_sources": [
            {
                "module": source.module,
                "owner_path": source.owner_path,
                "source_digest": source.source_digest,
            }
            for source in sources
        ],
        "root_declarations": list(closure.root_declarations),
        "root_module": closure.root_module,
        "schema_id": RECEIPT_SCHEMA_ID,
    }


def _observe_phase(receipt: object) -> None:
    print(
        json.dumps(
            receipt,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        ),
        file=sys.stderr,
        flush=True,
    )


async def _build_exact_axle_closure_with_deadline(
    *,
    closure: LeanDeclarationClosure,
    sources: Sequence[LeanOwnerSource],
    environment: str,
    operation_timeout_seconds: float = 10.0,
    base_timeout_seconds: float = 2.0,
    phase_observer: Callable[[object], None] | None = None,
) -> object:
    deadline_seconds = operation_timeout_seconds + base_timeout_seconds
    try:
        return await asyncio.wait_for(
            build_exact_axle_closure(
                closure=closure,
                sources=sources,
                environment=environment,
                operation_timeout_seconds=operation_timeout_seconds,
                base_timeout_seconds=base_timeout_seconds,
                phase_observer=phase_observer,
            ),
            timeout=deadline_seconds,
        )
    except TimeoutError:
        raise LeanClosureError(
            "axle-operation-deadline-exceeded",
            f"AXLE verification exceeded the configured {deadline_seconds:g}-second deadline",
        ) from None


def run(args: argparse.Namespace) -> int:
    lean_export_timeout_seconds = args.lean_export_timeout_seconds
    operation_timeout_seconds = args.axle_operation_timeout_seconds
    base_timeout_seconds = args.axle_base_timeout_seconds
    closure = export_declaration_closure(
        lean_root=args.lean_root,
        root_module=args.root_module,
        root_declarations=tuple(args.root_declarations),
        base_imports=("Init", *tuple(args.base_imports)),
        proof_base_imports=tuple(args.proof_base_imports),
        timeout_seconds=lean_export_timeout_seconds,
        phase_observer=_observe_phase,
    )
    _verify_environment(closure, args.environment)
    sources = resolve_owner_sources(
        closure=closure,
        lean_root=args.lean_root,
    )
    _verify_paths(args.paths, sources)
    receipt = _preflight_receipt(
        closure,
        sources,
        args.environment,
        lean_export_timeout_seconds,
        operation_timeout_seconds,
        base_timeout_seconds,
    )
    canonical_receipt = json.dumps(
        receipt,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )
    if args.closure_output is not None:
        artifact = {
            "closure": closure.canonical_manifest(),
            "preflight": receipt,
        }
        args.closure_output.write_text(
            json.dumps(
                artifact,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
            + "\n"
        )
    print(canonical_receipt)
    exact = asyncio.run(
        _build_exact_axle_closure_with_deadline(
            closure=closure,
            sources=sources,
            environment=args.environment,
            operation_timeout_seconds=operation_timeout_seconds,
            base_timeout_seconds=base_timeout_seconds,
            phase_observer=_observe_phase,
        )
    )
    independent_bundle = build_independent_declaration_bundle(
        closure=closure,
        exact=exact,
        sources=sources,
        lean_root=args.lean_root,
    )
    artifact = {
        "closure": closure.canonical_manifest(),
        "preflight": receipt,
        "exact_bundle": exact.canonical_manifest(),
        "exact_bundle_digest": exact.bundle_digest,
        "independent_declaration_bundle": independent_bundle.canonical_manifest(),
        "independent_declaration_bundle_digest": independent_bundle.bundle_digest,
    }
    if args.closure_output is not None:
        args.closure_output.write_text(
            json.dumps(artifact, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        )
    print(
        json.dumps(
            {
                "schema_id": exact.schema_id,
                "bundle_digest": exact.bundle_digest,
                "canonical_source_digest": exact.canonical_source_digest,
                "environment_declaration_count": len(exact.declarations),
                "proof_base_declaration_count": len(independent_bundle.proof_base_declarations),
                "source_declaration_count": len(independent_bundle.declarations),
                "root_declarations": list(exact.root_declarations),
                "independent_declaration_bundle_digest": (independent_bundle.bundle_digest),
                "verification": exact.verification,
            },
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0
