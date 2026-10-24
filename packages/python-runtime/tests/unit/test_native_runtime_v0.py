# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from pathlib import Path
import os
from typing import NoReturn

import pytest

from agentic_ai_lab_runtime._native.errors import NativeRuntimeError, NativeRuntimeLoadError
from agentic_ai_lab_runtime._native.evidence import NativeEvidenceSink
from agentic_ai_lab_runtime._native.loader import RUNTIME_LIBRARY_ENV, probe_native_runtime
from agentic_ai_lab_runtime._native.session import (
    NativeBundleDescriptor,
    NativeRuntimeSession,
)
from agentic_ai_lab_runtime._native.arena import NativeEvent, NativeMediation
from agentic_ai_lab_runtime import (
    RuntimeGraphProgram,
    RuntimeGraphError,
    RuntimeGraphRegistries,
    RuntimeGraphRuntime,
    TursoAuthorizedEffectEvidenceStore,
    linear_plan,
)


def _repo_library() -> Path:
    configured = os.environ.get(RUNTIME_LIBRARY_ENV)
    if not configured:
        pytest.skip(f"{RUNTIME_LIBRARY_ENV} does not name a Bazel runtime artifact")
    return Path(configured).expanduser().resolve()


def _failing_evidence_sink(_invocation: object) -> NoReturn:
    raise RuntimeError("evidence sink failed")


def test_native_runtime_override_negotiates_runtime_v0() -> None:
    pytest.importorskip("agentic_ai_lab_runtime._native._runtime_v0_cffi")
    library = _repo_library()
    if not library.is_file():
        pytest.skip("focused runtime-C build has not run")
    health = probe_native_runtime(library_path=library)
    assert (health.abi_major, health.abi_minor) == (0, 1)
    assert health.capabilities & 1


def test_native_runtime_missing_library_fails_closed(tmp_path: Path) -> None:
    pytest.importorskip("agentic_ai_lab_runtime._native._runtime_v0_cffi")
    with pytest.raises(NativeRuntimeLoadError, match="absent"):
        probe_native_runtime(library_path=tmp_path / "missing-runtime")


def test_native_runtime_session_owns_and_closes_full_control_chain() -> None:
    pytest.importorskip("agentic_ai_lab_runtime._native._runtime_v0_cffi")
    library = _repo_library()
    if not library.is_file():
        pytest.skip("focused runtime-C build has not run")
    bundle = NativeBundleDescriptor(bytes.fromhex("44" * 32), 7, b"bundle")
    with NativeRuntimeSession(bundle, library_path=library) as session:
        assert session.health.capabilities & 1
        assert not session.closed
    assert session.closed
    session.close()


def test_native_bundle_descriptor_rejects_noncanonical_shape() -> None:
    with pytest.raises(ValueError, match="32 bytes"):
        NativeBundleDescriptor(b"short", 1, b"bundle")
    with pytest.raises(ValueError, match="epoch"):
        NativeBundleDescriptor(bytes(32), -1, b"bundle")
    with pytest.raises(ValueError, match="canonical packet"):
        NativeBundleDescriptor(bytes(32), 1, b"")


def test_native_arena_roundtrip_is_batched_zero_copy_and_recyclable() -> None:
    pytest.importorskip("agentic_ai_lab_runtime._native._runtime_v0_cffi")
    library = _repo_library()
    if not library.is_file():
        pytest.skip("focused runtime-C build has not run")
    bundle = NativeBundleDescriptor(bytes.fromhex("55" * 32), 9, b"bundle")
    scheme_execution_root = bytes.fromhex(
        "e2727ba3af7ffebbe123f9639f58952d33e28390fc52693366f8b4fa1a0155e5"
    )
    with NativeRuntimeSession(bundle, library_path=library) as session:
        evidence = TursoAuthorizedEffectEvidenceStore()
        with session.arena(bytearray(4096)) as arena:
            mediation = NativeMediation(
                nonce=(0, 1),
                semantic_root=bytes.fromhex("55" * 32),
                before_execution_root=bytes(32),
                after_execution_root=scheme_execution_root,
                observation_digest=bytes.fromhex("bb" * 32),
            )
            result = arena.roundtrip(
                (
                    NativeEvent(1, payload_length=16),
                    NativeEvent(2, payload_offset=64, payload_length=32),
                ),
                mediation,
                evidence.native_sink(
                    session_id="native-roundtrip",
                    committed_execution_root=scheme_execution_root,
                    evidence_reference="row-1",
                    kernel_signature=b"kernel-signature",
                    signature_verified=True,
                    inclusion_proof_verified=True,
                ),
            )
            assert result.published_count == 2
            assert result.produced_count == 2
            assert result.accepted_count == 2
            assert result.item_statuses == (0, 0)
            assert result.accepted_bitmap == b"\x03"
            assert result.mediation_outcome == 1
            assert result.adapter_status == 0
            assert result.mediation_sequence == 1
            assert result.execution_root == scheme_execution_root
            assert result.observation_digest == bytes.fromhex("bb" * 32)
            assert result.evidence_status == 0
            assert result.verification_flags == 3
            arena.recycle(2)
            assert arena.generation == 2
        evidence.close()


def test_native_control_session_does_not_claim_scheme_graph_execution() -> None:
    pytest.importorskip("agentic_ai_lab_runtime._native._runtime_v0_cffi")
    library = _repo_library()
    if not library.is_file():
        pytest.skip("focused runtime-C build has not run")
    bundle = NativeBundleDescriptor(bytes.fromhex("66" * 32), 10, b"bundle")
    with NativeRuntimeSession(bundle, library_path=library) as session:
        runtime = RuntimeGraphRuntime.native(session)
        program = RuntimeGraphProgram(
            plan=linear_plan("native-step"),
            registries=RuntimeGraphRegistries(
                actions={"native-step": lambda state: {"value": state["value"] + 1}}
            ),
            runtime=runtime,
        )

        with pytest.raises(RuntimeGraphError, match="native graph execution is unavailable"):
            program.invoke_with_trace({"value": 1})


def test_native_mediation_replay_and_root_fork_fail_closed() -> None:
    pytest.importorskip("agentic_ai_lab_runtime._native._runtime_v0_cffi")
    library = _repo_library()
    if not library.is_file():
        pytest.skip("focused runtime-C build has not run")
    bundle = NativeBundleDescriptor(bytes.fromhex("77" * 32), 11, b"bundle")
    with NativeRuntimeSession(bundle, library_path=library) as session:
        evidence = TursoAuthorizedEffectEvidenceStore()
        with session.arena(bytearray(4096)) as arena:
            first_root = bytes.fromhex("aa" * 32)
            first = NativeMediation(
                nonce=(0, 9), semantic_root=bytes.fromhex("55" * 32),
                before_execution_root=bytes(32), after_execution_root=first_root,
                observation_digest=bytes.fromhex("bb" * 32),
            )
            first_sink = evidence.native_sink(
                session_id="native-negative",
                committed_execution_root=first_root,
                evidence_reference="row-1",
                kernel_signature=b"kernel-signature",
            )
            arena.roundtrip((NativeEvent(1),), first, first_sink)
            replay = NativeMediation(
                nonce=(0, 9), semantic_root=first.semantic_root,
                before_execution_root=first_root,
                after_execution_root=bytes.fromhex("cc" * 32),
                observation_digest=first.observation_digest,
            )
            with pytest.raises(NativeRuntimeError) as replay_error:
                arena.roundtrip((NativeEvent(2),), replay, first_sink)
            assert replay_error.value.status == 21
            unknown = NativeMediation(
                nonce=(0, 10), semantic_root=first.semantic_root,
                before_execution_root=first_root,
                after_execution_root=bytes.fromhex("cc" * 32),
                observation_digest=first.observation_digest,
                outcome=4,
            )
            unknown_result = arena.roundtrip(
                (NativeEvent(3),),
                unknown,
                evidence.native_sink(
                    session_id="native-negative",
                    committed_execution_root=unknown.after_execution_root,
                    evidence_reference="row-2",
                    kernel_signature=b"kernel-signature",
                ),
            )
            assert unknown_result.mediation_outcome == 4
            assert unknown_result.execution_root == first_root
            sink_failure = NativeMediation(
                nonce=(0, 11), semantic_root=first.semantic_root,
                before_execution_root=first_root,
                after_execution_root=bytes.fromhex("dd" * 32),
                observation_digest=first.observation_digest,
            )
            failed_result = arena.roundtrip(
                (NativeEvent(4),),
                sink_failure,
                NativeEvidenceSink(
                    evidence.native_sink(
                        session_id="native-negative",
                        committed_execution_root=sink_failure.after_execution_root,
                        evidence_reference="row-3",
                        kernel_signature=b"kernel-signature",
                    ).reserve,
                    _failing_evidence_sink,
                ),
            )
            assert failed_result.mediation_outcome == 4
            assert failed_result.evidence_status == 16
            assert failed_result.execution_root == first_root
            recovery = evidence.reconciliation("native-negative")
            assert recovery is not None
            assert recovery.execution_root == first_root
            assert recovery.consumed_nonces == ((0, 9), (0, 10), (0, 11))
            with pytest.raises(NativeRuntimeError) as spent_error:
                arena.roundtrip((NativeEvent(5),), sink_failure, first_sink)
            assert spent_error.value.status == 21
            fork = NativeMediation(
                nonce=(0, 12), semantic_root=first.semantic_root,
                before_execution_root=bytes(32),
                after_execution_root=bytes.fromhex("dd" * 32),
                observation_digest=first.observation_digest,
            )
            with pytest.raises(NativeRuntimeError) as fork_error:
                arena.roundtrip((NativeEvent(6),), fork, first_sink)
            assert fork_error.value.status == 22
        evidence.close()
