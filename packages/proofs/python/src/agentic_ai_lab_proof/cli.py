# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command-line interface for typed Lean artifact generation."""

from __future__ import annotations

import argparse
from pathlib import Path

from .axle_receipt_authority import (
    LiveAxleClosureReceiptAuthorityV1,
)
from .proof_base_receipt_graph_audit import (
    decode_proof_base_receipt_graph_audit_v1,
)

from .lean_emit import manifest_to_lean
from .model import canonical_loop_engine_manifest
from .proof_case_emit import write_generated_artifacts
from .proof_case_manifest import load_proof_case_schema


def _emit_lean(args: argparse.Namespace) -> int:
    output = manifest_to_lean(canonical_loop_engine_manifest(), args.module_name)
    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(output, encoding="utf-8")
    else:
        print(output, end="")
    return 0


def _emit_proof_case_artifacts(args: argparse.Namespace) -> int:
    proof_root = Path(args.proof_root).resolve()
    schema = load_proof_case_schema(proof_root / "proof-case-vector-v1.toml")
    stale = write_generated_artifacts(proof_root, schema, check=args.check)
    if args.check and stale:
        for path in stale:
            print(f"stale generated proof artifact: {path}")
        return 1
    return 0


def _verify_receipt_graph_audit(args: argparse.Namespace) -> int:
    authority = LiveAxleClosureReceiptAuthorityV1(
        lean_root=args.lean_root,
        lean_export_timeout_seconds=args.lean_export_timeout_seconds,
        axle_operation_timeout_seconds=args.axle_operation_timeout_seconds,
        axle_base_timeout_seconds=args.axle_base_timeout_seconds,
    )
    decoded = decode_proof_base_receipt_graph_audit_v1(
        args.input.read_bytes(),
        authority=authority,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(decoded.canonical_audit_bytes)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="agentic-ai-lab-proof")
    subparsers = parser.add_subparsers(dest="command", required=True)

    emit_lean = subparsers.add_parser("emit-lean")
    emit_lean.add_argument("--module-name", default="AgenticAILabProof.Generated.LoopEngine")
    emit_lean.add_argument("--output")
    emit_lean.set_defaults(func=_emit_lean)

    emit_proof_case = subparsers.add_parser("emit-proof-case-artifacts")
    emit_proof_case.add_argument(
        "--proof-root",
        default=str(Path(__file__).resolve().parents[3]),
    )
    emit_proof_case.add_argument("--check", action="store_true")
    emit_proof_case.set_defaults(func=_emit_proof_case_artifacts)
    verify_receipt_graph_audit = subparsers.add_parser(
        "verify-receipt-graph-audit"
    )
    verify_receipt_graph_audit.add_argument(
        "--input",
        type=Path,
        required=True,
    )
    verify_receipt_graph_audit.add_argument(
        "--output",
        type=Path,
        required=True,
    )
    verify_receipt_graph_audit.add_argument(
        "--lean-root",
        type=Path,
        required=True,
    )
    verify_receipt_graph_audit.add_argument(
        "--lean-export-timeout-seconds",
        type=float,
        default=60.0,
    )
    verify_receipt_graph_audit.add_argument(
        "--axle-operation-timeout-seconds",
        type=float,
        default=30.0,
    )
    verify_receipt_graph_audit.add_argument(
        "--axle-base-timeout-seconds",
        type=float,
        default=10.0,
    )
    verify_receipt_graph_audit.set_defaults(
        func=_verify_receipt_graph_audit
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
