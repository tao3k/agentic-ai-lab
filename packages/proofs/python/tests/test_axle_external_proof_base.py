# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import asyncio
from pathlib import Path

from agentic_ai_lab_proof.axle_exact_closure import (
    AxleExactClosureError,
    build_exact_axle_closure,
)
from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanDeclaration,
    LeanDeclarationClosure,
    LeanOwnerSource,
    LeanSourceRange,
)


def test_external_owner_requires_explicit_proof_base() -> None:
    declaration = LeanDeclaration(
        name="Poo.Root",
        kind="theorem",
        owner_module="Poo",
        local_dependencies=(),
        source_range=LeanSourceRange(
            start_line=1,
            start_column=0,
            start_char_utf16=0,
            end_line=1,
            end_column=1,
            end_char_utf16=1,
        ),
    )
    closure = LeanDeclarationClosure(
        lean_version="4.31.0",
        root_module="Poo",
        root_declarations=("Poo.Root",),
        base_imports=("Init",),
        proof_base_imports=(),
        proof_base_interface=(),
        owner_modules=("Poo",),
        declarations=(declaration,),
    )
    source = LeanOwnerSource(
        module="Cedar.Spec",
        path=Path("unused"),
        owner_path="unused",
        source_digest="sha256:unused",
    )

    async def run() -> AxleExactClosureError:
        try:
            await build_exact_axle_closure(
                closure=closure,
                sources=(source,),
                environment="lean-4.31.0",
                client=object(),
            )
        except AxleExactClosureError as error:
            return error
        raise AssertionError("expected an external-proof-base-required error")

    error = asyncio.run(run())
    assert error.code == "external-proof-base-required"
    assert "Cedar.Spec" in error.detail
