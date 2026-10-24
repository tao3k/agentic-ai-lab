# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import argparse
import platform
from pathlib import Path
from struct import pack_into
from time import perf_counter_ns

from agentic_ai_lab_proof.generated.proof_case_vector import (
    DURABILITY_PROFILES,
    FIELD_OFFSETS,
    VECTOR_SIZE,
)
from agentic_ai_lab_proof.proof_case_runtime import NativeProofCaseRuntime


def percentile(samples: list[int], numerator: int) -> int:
    ordered = sorted(samples)
    return ordered[(len(ordered) * numerator - 1) // 100]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--library", type=Path, required=True)
    parser.add_argument("--vector", type=Path, required=True)
    parser.add_argument("--iterations", type=int, default=100)
    parser.add_argument("--max-batch", type=int, default=1024)
    args = parser.parse_args()
    if args.iterations <= 0 or args.max_batch <= 0:
        raise ValueError("iterations and max-batch must be positive")

    canonical = bytes.fromhex(args.vector.read_text(encoding="ascii"))
    runtime = NativeProofCaseRuntime(args.library)
    warmup = bytearray(VECTOR_SIZE)
    runtime.validate_and_write(canonical, warmup)

    for profile in ("strict", "batched"):
        vector = bytearray(canonical)
        pack_into(
            "<I",
            vector,
            FIELD_OFFSETS["durability_profile"],
            DURABILITY_PROFILES[profile],
        )
        vector = bytes(vector)
        for batch_size in (1, 8, 32, 128, 1024):
            if batch_size > args.max_batch:
                continue
            outputs = [bytearray(VECTOR_SIZE) for _ in range(batch_size)]
            samples: list[int] = []
            for _ in range(args.iterations):
                started = perf_counter_ns()
                for output in outputs:
                    runtime.validate_and_write(vector, output)
                samples.append(perf_counter_ns() - started)
            print("schema=agentic-ai-lab.proof-case-cffi.benchmark.1")
            print("path=installed-wheel-caller-owned")
            print(f"profile={profile}")
            print(f"batch={batch_size}")
            print(f"iterations={args.iterations}")
            print("crossings-per-item-steady=3")
            print(f"layout-measurements={runtime.layout_measurements}")
            print("caller-output-allocations-per-item=0")
            print(f"p50-ns={percentile(samples, 50)}")
            print(f"p99-ns={percentile(samples, 99)}")
            print(f"python={platform.python_version()}")
            print(f"system={platform.system()}")
            print(f"machine={platform.machine()}")
            print("abi-v1-frozen=false")
            print("--")


if __name__ == "__main__":
    main()
