# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Matched persistent-worker and in-Scheme timing for one exact candidate."""

from __future__ import annotations

import argparse
import json
import statistics
import time
from pathlib import Path

from .repair_native import SCHEME_SOURCE_DIR, NativeTool, score
from .reporting import report_json


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--poo-root", type=Path, required=True)
    parser.add_argument("--ascent-root", type=Path, required=True)
    parser.add_argument("--gerbil-path", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--warm-samples", type=int, default=10)
    args = parser.parse_args()
    if not 1 <= args.warm_samples <= 20:
        parser.error("warm samples must be between 1 and 20")
    if args.output.exists():
        raise FileExistsError(args.output)
    if args.output.resolve().is_relative_to(args.poo_root.resolve()):
        raise ValueError("benchmark receipt must stay outside the repository")
    fixture = (SCHEME_SOURCE_DIR / "repair_reference.sexp").read_text(encoding="utf-8")
    candidate = fixture[fixture.index("(candidate"):]
    worker = NativeTool(args.poo_root, args.ascent_root, args.gerbil_path)
    samples = []
    first_receipt: str | None = None
    try:
        for index in range(args.warm_samples + 1):
            started = time.perf_counter_ns()
            receipt = worker.attempt(candidate)
            wall_ns = time.perf_counter_ns() - started
            if index == 0:
                receipt_path = args.output.with_suffix(".sexp")
                receipt_path.write_text(receipt, encoding="utf-8")
                verdict = score(receipt_path, args.poo_root,
                                args.ascent_root, args.gerbil_path)
                receipt_path.unlink()
                if verdict != "(score (exact #t))":
                    raise RuntimeError("benchmark candidate lost semantic parity")
                first_receipt = receipt
            elif receipt != first_receipt:
                raise RuntimeError("benchmark receipt changed across samples")
            native_ns = worker.last_native_ns
            assert native_ns is not None
            samples.append({"kind": "cold" if index == 0 else "warm",
                            "worker_ns": wall_ns, "scheme_ns": native_ns,
                            "boundary_ns": wall_ns - native_ns,
                            "candidate_bytes": len(candidate.encode()),
                            "receipt_bytes": len(receipt.encode())})
    finally:
        worker.close()
    warm = samples[1:]
    summary = {field: {
        "median_ns": int(statistics.median(item[field] for item in warm)),
        "max_ns": max(item[field] for item in warm),
    } for field in ("worker_ns", "scheme_ns", "boundary_ns")}
    result = {"samples": samples, "warm_summary": summary}
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    report_json({"receipt": str(args.output), "warm_summary": summary})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
