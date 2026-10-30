# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from pathlib import Path
from types import SimpleNamespace

import pytest

from agentic_ai_lab_proof import axle_exact_closure
from agentic_ai_lab_proof.axle_exact_closure import (
    AxleExactClosureError,
    ExactAxleClosure,
    SourceDeclaration,
    build_exact_axle_closure,
    source_declaration_closure,
)
from agentic_ai_lab_proof.lean_declaration_closure import (
    LeanDeclarationClosure,
    LeanOwnerSource,
)


@dataclass
class FakeDocument:
    name: str
    local_type_dependencies: list[str] = field(default_factory=list)
    local_value_dependencies: list[str] = field(default_factory=list)
    local_syntactic_dependencies: list[str] = field(default_factory=list)


def documents(*values: FakeDocument) -> dict[str, FakeDocument]:
    return {value.name: value for value in values}


def test_generated_lean_constants_collapse_to_source_declaration() -> None:
    result = source_declaration_closure(
        lean_declarations=(
            "Example.Policy",
            "Example.Policy.mk",
            "Example.Policy.authority",
            "Example.admit",
        ),
        root_declarations=("Example.admit",),
        documents=documents(
            FakeDocument("Example.Policy"),
            FakeDocument(
                "Example.admit",
                local_type_dependencies=["Example.Policy"],
                local_value_dependencies=["Example.Policy.authority"],
            ),
        ),
    )

    assert result == ("Example.Policy", "Example.admit")


def test_inaccessible_generated_instance_normalizes_to_source_owner() -> None:
    assert (
        axle_exact_closure._normalized_source_declaration_name(
            "«_Example.instDecidableEqThing»",
            {"Example.Thing": "Example.Thing"},
        )
        == "Example.Thing"
    )


def test_source_range_aliases_collapse_generated_document_cycle() -> None:
    result = source_declaration_closure(
        lean_declarations=("Example.Policy", "Example.Policy.mk"),
        root_declarations=("Example.Policy",),
        documents=documents(
            FakeDocument(
                "Example.Policy",
                local_value_dependencies=[
                    "Example.Policy.mk",
                    "Example.instReprPolicy",
                ],
                local_syntactic_dependencies=["Example.Policy.unlistedGeneratedField"],
            ),
            FakeDocument(
                "Example.Policy.mk",
                local_type_dependencies=["Example.Policy"],
            ),
            FakeDocument(
                "Example.instReprPolicy",
                local_type_dependencies=["Example.Policy"],
            ),
        ),
        declaration_aliases={
            "Example.Policy": "Example.Policy",
            "Example.Policy.mk": "Example.Policy",
        },
    )

    assert result == ("Example.Policy",)


def test_axle_local_dependencies_extend_the_lean_seed_to_a_fixed_point() -> None:
    result = source_declaration_closure(
        lean_declarations=("Example.root",),
        root_declarations=("Example.root",),
        documents=documents(
            FakeDocument("Example.base"),
            FakeDocument(
                "Example.middle",
                local_syntactic_dependencies=["Example.base"],
            ),
            FakeDocument(
                "Example.root",
                local_value_dependencies=["Example.middle"],
            ),
        ),
    )

    assert result == ("Example.base", "Example.middle", "Example.root")


def test_unmapped_local_dependency_fails_closed() -> None:
    with pytest.raises(
        AxleExactClosureError,
        match="local-dependency-without-source-declaration",
    ):
        source_declaration_closure(
            lean_declarations=("Example.root",),
            root_declarations=("Example.root",),
            documents=documents(
                FakeDocument(
                    "Example.root",
                    local_value_dependencies=["Example.missing"],
                )
            ),
        )


def test_source_declaration_cycle_fails_closed() -> None:
    with pytest.raises(AxleExactClosureError, match="source-declaration-cycle"):
        source_declaration_closure(
            lean_declarations=("Example.left", "Example.right"),
            root_declarations=("Example.left",),
            documents=documents(
                FakeDocument(
                    "Example.left",
                    local_value_dependencies=["Example.right"],
                ),
                FakeDocument(
                    "Example.right",
                    local_value_dependencies=["Example.left"],
                ),
            ),
        )


def test_bundle_identity_excludes_runtime_verification_receipts() -> None:
    declaration = SourceDeclaration(
        name="Example.safe",
        kind="theorem",
        declaration="theorem safe : True := by trivial",
        local_dependencies=(),
    )
    shared = {
        "lean_closure_digest": "sha256:" + "a" * 64,
        "environment": "lean-4.31.0",
        "root_declarations": ("Example.safe",),
        "source_declarations": ("Example.safe",),
        "declarations": (declaration,),
        "canonical_source": "theorem Example.safe : True := by trivial\n",
    }

    first = ExactAxleClosure(
        **shared,
        theorem2sorry={"request": {"id": "first"}},
        verification={"okay": True, "timings": {"total": 1}},
    )
    second = ExactAxleClosure(
        **shared,
        theorem2sorry={"request": {"id": "second"}},
        verification={"okay": True, "timings": {"total": 999}},
    )

    assert first.bundle_digest == second.bundle_digest
    assert first.canonical_manifest() != second.canonical_manifest()


def test_non_theorem_root_uses_exact_roundtrip_without_theorem_pipeline(
    tmp_path: Path,
) -> None:
    import asyncio
    from types import SimpleNamespace

    from agentic_ai_lab_proof.axle_exact_closure import (
        _digest,
        build_exact_axle_closure,
    )
    from agentic_ai_lab_proof.lean_declaration_closure import (
        LeanDeclaration,
        LeanDeclarationClosure,
        LeanOwnerSource,
        LeanProofBaseInterfaceDeclaration,
        LeanSourceRange,
    )

    source = """namespace Example

structure Evidence where
  value : Nat

end Example
"""
    source_path = tmp_path / "Example.lean"
    source_path.write_text(source)
    messages = SimpleNamespace(errors=())
    document = SimpleNamespace(
        name="Example.Evidence",
        kind="structure",
        declaration="structure Example.Evidence where\n  value : Nat",
        local_type_dependencies=(
            "ProofBase.Type",
            "ProofBase.instReprType",
        ),
        local_value_dependencies=(),
        local_syntactic_dependencies=(),
    )
    extraction = SimpleNamespace(
        documents={
            "Example.Evidence": document,
            "ProofBase.Type": SimpleNamespace(
                name="ProofBase.Type",
                kind="axiom",
                declaration="axiom ProofBase.Type : Type",
                local_type_dependencies=(),
                local_value_dependencies=(),
                local_syntactic_dependencies=(),
            ),
            "ProofBase.instReprType": SimpleNamespace(
                name="ProofBase.instReprType",
                kind="axiom",
                declaration="axiom ProofBase.instReprType : Repr ProofBase.Type",
                local_type_dependencies=(),
                local_value_dependencies=(),
                local_syntactic_dependencies=(),
            ),
        },
        lean_messages=messages,
        tool_messages=messages,
    )

    class FakeAxleClient:
        def __init__(self) -> None:
            self.extract_calls = 0
            self.theorem_calls = 0
            self.verify_calls = 0

        async def extract_decls(
            self,
            content: str,
            environment: str,
            *,
            ignore_imports: bool,
            timeout_seconds: float,
        ) -> SimpleNamespace:
            self.extract_calls += 1
            return extraction

        async def theorem2sorry(self, *args: object, **kwargs: object) -> None:
            self.theorem_calls += 1
            raise AssertionError("non-theorem roots must not enter theorem2sorry")

        async def verify_proof(self, *args: object, **kwargs: object) -> None:
            self.verify_calls += 1
            raise AssertionError("non-theorem roots must not enter proof verification")

    closure = LeanDeclarationClosure(
        lean_version="v4.24.0",
        root_module="Example",
        root_declarations=("Example.Evidence",),
        base_imports=("Init",),
        proof_base_imports=("ProofBase",),
        proof_base_interface=(
            LeanProofBaseInterfaceDeclaration(
                name="ProofBase.Type",
                declaration_role="axiom",
                level_params=(),
                type_source="Type",
                value_source=None,
            ),
            LeanProofBaseInterfaceDeclaration(
                name="ProofBase.instReprType",
                declaration_role="instance",
                level_params=(),
                type_source="Repr ProofBase.Type",
                value_source=None,
            ),
        ),
        owner_modules=("Example",),
        declarations=(
            LeanDeclaration(
                name="Example.Evidence",
                kind="structure",
                owner_module="Example",
                local_dependencies=(),
                source_range=LeanSourceRange(
                    start_line=3,
                    start_column=0,
                    start_char_utf16=0,
                    end_line=5,
                    end_column=0,
                    end_char_utf16=0,
                ),
            ),
        ),
    )
    sources = (
        LeanOwnerSource(
            module="Example",
            path=source_path,
            owner_path="Example.lean",
            source_digest=_digest(source.encode()),
        ),
    )
    fake_client = FakeAxleClient()

    exact = asyncio.run(
        build_exact_axle_closure(
            closure=closure,
            sources=sources,
            environment="lean-4.24.0",
            client=fake_client,
            operation_timeout_seconds=7,
            base_timeout_seconds=3,
        )
    )

    assert fake_client.extract_calls == 2
    assert fake_client.theorem_calls == 0
    assert fake_client.verify_calls == 0
    assert exact.theorem2sorry == {
        "schema_id": "agentic-ai-lab.axle-root-theorem-obligation.v1",
        "status": "not-applicable",
        "root_declarations": (),
        "root_declaration_kinds": {"Example.Evidence": "structure"},
    }
    assert exact.verification["status"] == "accepted"
    assert exact.verification["roundtrip"] == "accepted"
    assert exact.verification["theorem_proof"] == "not-applicable"
    assert exact.verification["okay"] is True
    assert {declaration.name for declaration in exact.declarations} == {
        "Example.Evidence",
        "ProofBase.Type",
        "ProofBase.instReprType",
    }


def test_exact_closure_classifies_roots_before_theorem_phases_and_emits_receipts(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    closure = LeanDeclarationClosure.from_mapping(
        {
            "base_imports": ["Init"],
            "proof_base_imports": [],
            "proof_base_interface": [],
            "declarations": [
                {
                    "kind": "theorem",
                    "local_dependencies": [],
                    "name": "Example.safe",
                    "owner_module": "Example.Root",
                    "source_range": {
                        "start_line": 1,
                        "start_column": 0,
                        "start_char_utf16": 0,
                        "end_line": 1,
                        "end_column": 42,
                        "end_char_utf16": 42,
                    },
                }
            ],
            "lean_version": "4.31.0",
            "owner_modules": ["Example.Root"],
            "root_declarations": ["Example.safe"],
            "root_module": "Example.Root",
            "schema_id": "agentic-ai-lab.lean-declaration-closure.v1",
        }
    )
    source_path = tmp_path / "Example" / "Root.lean"
    source_path.parent.mkdir()
    source_path.write_text("theorem Example.safe : True := by trivial\n")
    source = LeanOwnerSource(
        module="Example.Root",
        path=source_path,
        owner_path="Example/Root.lean",
        source_digest="sha256:" + "a" * 64,
    )
    document = SimpleNamespace(
        name="Example.safe",
        kind="theorem",
        declaration="theorem Example.safe : True := by trivial",
        local_type_dependencies=[],
        local_value_dependencies=[],
        local_syntactic_dependencies=[],
    )
    messages = SimpleNamespace(errors=[])
    extraction = SimpleNamespace(
        documents={"Example.safe": document},
        lean_messages=messages,
        tool_messages=messages,
    )

    class FakeAxleClient:
        def __init__(self) -> None:
            self.extract_calls = 0
            self.roundtrip_started = asyncio.Event()
            self.theorem_started = asyncio.Event()
            self.timeouts: list[float] = []

        async def extract_decls(
            self,
            _content: str,
            _environment: str,
            *,
            ignore_imports: bool,
            timeout_seconds: float,
        ) -> object:
            assert ignore_imports is False
            self.timeouts.append(timeout_seconds)
            self.extract_calls += 1
            if self.extract_calls == 1:
                return extraction
            return extraction

        async def theorem2sorry(
            self,
            _content: str,
            _environment: str,
            *,
            names: list[str],
            ignore_imports: bool,
            timeout_seconds: float,
        ) -> object:
            assert names == ["Example.safe"]
            assert ignore_imports is False
            self.timeouts.append(timeout_seconds)
            return SimpleNamespace(
                content="theorem Example.safe : True := by sorry",
                info={"operation": "theorem2sorry"},
                lean_messages=messages,
                tool_messages=messages,
            )

        async def verify_proof(
            self,
            _statement: str,
            _content: str,
            _environment: str,
            *,
            ignore_imports: bool,
            timeout_seconds: float,
        ) -> object:
            assert ignore_imports is False
            self.timeouts.append(timeout_seconds)
            return SimpleNamespace(
                okay=True,
                failed_declarations=[],
                lean_messages=messages,
                tool_messages=messages,
                timings={"total": 1},
                info={"operation": "verify_proof"},
            )

    fake_client = FakeAxleClient()
    receipts: list[dict[str, object]] = []
    monkeypatch.setattr(
        axle_exact_closure,
        "_compose_owner_sources",
        lambda _closure, _sources: "theorem Example.safe : True := by trivial\n",
    )
    monkeypatch.setattr(
        axle_exact_closure,
        "_compose_source_declarations",
        lambda _names, _documents, _base_imports: ("theorem Example.safe : True := by trivial\n"),
    )

    exact = asyncio.run(
        build_exact_axle_closure(
            closure=closure,
            sources=(source,),
            environment="lean-4.31.0",
            client=fake_client,  # type: ignore[arg-type]
            operation_timeout_seconds=7,
            base_timeout_seconds=2,
            phase_observer=lambda receipt: receipts.append(dict(receipt)),
        )
    )

    assert exact.verification["okay"] is True
    assert fake_client.timeouts == [7, 7, 7, 7]
    states_by_phase = {
        phase: [receipt["state"] for receipt in receipts if receipt["phase"] == phase]
        for phase in {
            "owner-source-extract",
            "canonical-roundtrip-extract",
            "root-theorem2sorry",
            "root-proof-verify",
        }
    }
    assert states_by_phase == {
        "owner-source-extract": ["started", "completed"],
        "canonical-roundtrip-extract": ["started", "completed"],
        "root-theorem2sorry": ["started", "completed"],
        "root-proof-verify": ["started", "completed"],
    }


def test_owner_source_envelope_uses_declared_base_imports(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "Example" / "Root.lean"
    source_path.parent.mkdir()
    source_path.write_text("theorem Example.safe : True := by trivial\n")
    closure = LeanDeclarationClosure.from_mapping(
        {
            "base_imports": ["Init", "Batteries.Data.List.Perm"],
            "proof_base_imports": [],
            "proof_base_interface": [],
            "declarations": [
                {
                    "kind": "theorem",
                    "local_dependencies": [],
                    "name": "Example.safe",
                    "owner_module": "Example.Root",
                    "source_range": {
                        "start_line": 1,
                        "start_column": 0,
                        "start_char_utf16": 0,
                        "end_line": 1,
                        "end_column": 42,
                        "end_char_utf16": 42,
                    },
                }
            ],
            "lean_version": "4.31.0",
            "owner_modules": ["Example.Root"],
            "root_declarations": ["Example.safe"],
            "root_module": "Example.Root",
            "schema_id": "agentic-ai-lab.lean-declaration-closure.v1",
        }
    )
    source = LeanOwnerSource(
        module="Example.Root",
        path=source_path,
        owner_path="Example/Root.lean",
        source_digest="sha256:" + "a" * 64,
    )

    envelope = axle_exact_closure._compose_owner_sources(closure, (source,))

    assert envelope.startswith("import Init\nimport Batteries.Data.List.Perm\n\n")
    assert "import Mathlib" not in envelope
    assert "theorem Example.safe : True := by trivial" in envelope


def test_owner_source_envelope_preserves_typed_proof_base_roles(
    tmp_path: Path,
) -> None:
    source_path = tmp_path / "Example" / "Root.lean"
    source_path.parent.mkdir()
    source_path.write_text("theorem Example.safe : True := by trivial\n")
    closure = LeanDeclarationClosure.from_mapping(
        {
            "base_imports": ["Init"],
            "proof_base_imports": ["ProofBase"],
            "proof_base_interface": [
                {
                    "declaration_role": "axiom",
                    "level_params": ["proof_u"],
                    "name": "ProofBase.Type",
                    "type_source": "Type proof_u",
                    "value_source": None,
                },
                {
                    "declaration_role": "abbrev",
                    "level_params": [],
                    "name": "ProofBase.Alias",
                    "type_source": "Type",
                    "value_source": "String",
                },
                {
                    "declaration_role": "definition",
                    "level_params": [],
                    "name": "ProofBase.Defined",
                    "type_source": "Type",
                    "value_source": "Nat",
                },
                {
                    "declaration_role": "instance",
                    "level_params": [],
                    "name": "ProofBase.instReprType",
                    "type_source": "Repr ProofBase.Type",
                    "value_source": None,
                },
            ],
            "declarations": [
                {
                    "kind": "theorem",
                    "local_dependencies": [],
                    "name": "Example.safe",
                    "owner_module": "Example.Root",
                    "source_range": {
                        "start_line": 1,
                        "start_column": 0,
                        "start_char_utf16": 0,
                        "end_line": 1,
                        "end_column": 42,
                        "end_char_utf16": 42,
                    },
                }
            ],
            "lean_version": "4.31.0",
            "owner_modules": ["Example.Root"],
            "root_declarations": ["Example.safe"],
            "root_module": "Example.Root",
            "schema_id": "agentic-ai-lab.lean-declaration-closure.v1",
        }
    )
    source = LeanOwnerSource(
        module="Example.Root",
        path=source_path,
        owner_path="Example/Root.lean",
        source_digest="sha256:" + "a" * 64,
    )

    envelope = axle_exact_closure._compose_owner_sources(closure, (source,))

    assert "universe proof_u" in envelope
    assert "ProofBase.Type.{proof_u}" not in envelope
    assert "axiom ProofBase.Type : Type proof_u" in envelope
    assert "abbrev ProofBase.Alias : Type := String" in envelope
    assert "def ProofBase.Defined : Type := Nat" in envelope
    assert "axiom ProofBase.instReprType : Repr ProofBase.Type" in envelope
    assert "attribute [local instance] ProofBase.instReprType" in envelope
    assert "noncomputable section" in envelope
