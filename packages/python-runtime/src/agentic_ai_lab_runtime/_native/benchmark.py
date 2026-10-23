# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Benchmark the native batch path loaded from an installed Python wheel."""

from __future__ import annotations

import argparse
import hashlib
from statistics import median
import sys
import time

from .arena import NativeEvent, NativeMediation
from .session import NativeBundleDescriptor, NativeRuntimeSession
from ..evidence import TursoAuthorizedEffectEvidenceStore

BATCH_SIZES = (1, 8, 32, 128, 1024)
DEFAULT_BATCHED_LEAVES = 8


def run(
    iterations: int,
    *,
    mediation: str = "strict",
    batched_leaves: int = DEFAULT_BATCHED_LEAVES,
) -> tuple[str, ...]:
    if iterations <= 0:
        raise ValueError("native benchmark iterations must be positive")
    if mediation not in {"strict", "batched"}:
        raise ValueError("native benchmark mediation must be strict or batched")
    if batched_leaves <= 0:
        raise ValueError("Batched benchmark leaf count must be positive")
    return tuple(
        _benchmark_size(iterations, mediation, batched_leaves, batch_size)
        for batch_size in BATCH_SIZES
    )


def _benchmark_size(iterations, mediation, batched_leaves, batch_size):
    sequence = 1
    root = bytes(32)
    samples: list[int] = []
    bundle = NativeBundleDescriptor(bytes.fromhex("77" * 32), 1, b"benchmark")
    evidence = TursoAuthorizedEffectEvidenceStore()
    with NativeRuntimeSession(
        bundle, batched_evidence=mediation == "batched"
    ) as session:
        with session.arena(bytearray(1024 * 1024)) as arena:
            for _index in range(iterations):
                started = time.perf_counter_ns()
                if mediation == "strict":
                    sequence, root = _strict_effect(
                        arena, evidence, sequence, root, batch_size
                    )
                else:
                    sequence, root = _batched_effects(
                        session, arena, evidence, sequence, root,
                        batch_size, batched_leaves,
                    )
                samples.append(time.perf_counter_ns() - started)
    evidence.close()
    divisor = 1 if mediation == "strict" else batched_leaves
    crossings = (
        4 if mediation == "strict" else 4 * batched_leaves + 2
    ) / (batch_size * divisor)
    return " ".join((
        "schema=agentic-ai-lab.runtime-v0.python-wheel-benchmark.1",
        f"mediation={mediation.title()}",
        "adapter=kernel-vtable",
        "evidence-sink=turso-sync",
        "evidence-protocol=" + (
            "reserve-finalize" if mediation == "strict"
            else "reserve-stage-flush"
        ),
        f"batch={batch_size}",
        f"evidence-batch-leaves={divisor}",
        f"iterations={iterations}",
        f"p50-group-ns={int(median(samples))}",
        f"p50-ns={int(median(samples) / divisor)}",
        f"crossings-per-item={crossings:.9f}",
        "payload-zero-copy=true",
        "lookup-complexity=O(log-n-plus-k)",
        "nonce-lookup=expected-O(1)",
        "merkle-build=O(k)",
        "abi-v1-frozen=false",
    ))


def _strict_effect(arena, evidence, sequence, root, batch_size):
    events, sequence = _events(sequence, batch_size)
    next_root = hashlib.sha256(root + sequence.to_bytes(8, "big")).digest()
    result = arena.roundtrip(
        events,
        _mediation(sequence, root, next_root),
        _sink(evidence, next_root, sequence),
    )
    _require_accepted(result, batch_size)
    return sequence, result.execution_root


def _batched_effects(
    session, arena, evidence, sequence, root, batch_size, leaf_count
):
    sink = _sink(evidence, root, sequence)
    for _index in range(leaf_count):
        events, sequence = _events(sequence, batch_size)
        result = arena.roundtrip(
            events,
            _mediation(sequence, root, root, durability=2),
            sink,
        )
        _require_accepted(result, batch_size)
        if result.mediation_outcome != 2 or result.execution_root != root:
            raise RuntimeError("Batched mediation advanced before flush")
    committed = session.flush_batched(root, sink)
    return sequence, committed.after_execution_root


def _events(sequence: int, batch_size: int):
    events = tuple(NativeEvent(sequence + offset) for offset in range(batch_size))
    return events, sequence + batch_size


def _mediation(sequence, before, after, *, durability=1):
    return NativeMediation(
        nonce=(0, sequence),
        semantic_root=bytes.fromhex("88" * 32),
        before_execution_root=before,
        after_execution_root=after,
        observation_digest=bytes.fromhex("99" * 32),
        input_digest=hashlib.sha256(sequence.to_bytes(8, "big")).digest(),
        durability=durability,
    )


def _sink(evidence, root, sequence):
    return evidence.native_sink(
        session_id="benchmark",
        committed_execution_root=root,
        evidence_reference=f"benchmark-{sequence}",
        kernel_signature=b"benchmark-kernel",
    )


def _require_accepted(result, batch_size: int) -> None:
    if result.accepted_count != batch_size:
        raise RuntimeError("native benchmark batch was not fully accepted")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=20)
    parser.add_argument("--mediation", choices=("strict", "batched"), default="strict")
    parser.add_argument("--batched-leaves", type=int, default=DEFAULT_BATCHED_LEAVES)
    args = parser.parse_args(argv)
    for line in run(
        args.iterations, mediation=args.mediation,
        batched_leaves=args.batched_leaves,
    ):
        sys.stdout.write(line + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
