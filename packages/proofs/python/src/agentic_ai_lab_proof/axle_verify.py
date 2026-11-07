# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import argparse
import asyncio
import json
from importlib.metadata import version
from pathlib import Path
from typing import Any


def independent_source(source: str) -> str:
    """Project-local imports are checked by Lean; AXLE checks declarations independently."""
    body = [
        line
        for line in source.splitlines()
        if line != "import Mathlib" and not line.startswith("import AgenticAILabProof.")
    ]
    return "import Mathlib\n" + "\n".join(body) + "\n"


def message_payload(messages: object) -> dict[str, list[Any]]:
    return {
        "errors": list(getattr(messages, "errors", [])),
        "warnings": list(getattr(messages, "warnings", [])),
        "infos": list(getattr(messages, "infos", [])),
    }


async def verify_one(
    client: Any,
    path: Path,
    environment: str,
    preserve_imports: bool,
) -> dict[str, Any]:
    original = path.read_text()
    content = original if preserve_imports else independent_source(original)
    statement = await client.theorem2sorry(
        content,
        environment,
        ignore_imports=not preserve_imports,
        timeout_seconds=120,
    )
    statement_messages = {
        "lean": message_payload(statement.lean_messages),
        "tool": message_payload(statement.tool_messages),
    }
    if statement_messages["lean"]["errors"] or statement_messages["tool"]["errors"]:
        return {
            "path": str(path),
            "mode": "preserved-imports" if preserve_imports else "independent",
            "theorem2sorry": {
                "request": statement.info,
                "messages": statement_messages,
            },
            "verify": None,
        }

    verified = await client.verify_proof(
        statement.content,
        content,
        environment,
        ignore_imports=not preserve_imports,
        timeout_seconds=120,
    )
    return {
        "path": str(path),
        "mode": "preserved-imports" if preserve_imports else "independent",
        "theorem2sorry": {
            "request": statement.info,
            "messages": statement_messages,
        },
        "verify": {
            "okay": verified.okay,
            "failed_declarations": verified.failed_declarations,
            "lean_messages": message_payload(verified.lean_messages),
            "tool_messages": message_payload(verified.tool_messages),
            "timings": verified.timings,
            "request": verified.info,
        },
    }


def receipt_succeeded(receipt: dict[str, Any]) -> bool:
    verification = receipt["verify"]
    return verification is not None and bool(verification["okay"])


async def run(args: argparse.Namespace) -> int:
    from axle import AxleClient

    async with AxleClient(max_concurrency=len(args.paths)) as client:
        receipts = await asyncio.gather(
            *(
                verify_one(client, path, args.environment, args.preserve_imports)
                for path in args.paths
            )
        )
    output = {
        "axle_sdk": {
            "distribution": "axiom-axle",
            "version": version("axiom-axle"),
        },
        "environment": args.environment,
        "mode": "preserved-imports" if args.preserve_imports else "independent",
        "receipts": receipts,
    }
    print(json.dumps(output, indent=2, default=str))
    return 0 if all(receipt_succeeded(receipt) for receipt in receipts) else 1


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify Lean declarations through the UV-managed AXLE client."
    )
    parser.add_argument("paths", nargs="*", type=Path)
    parser.add_argument("--environment", default="lean-4.31.0")
    parser.add_argument("--preserve-imports", action="store_true")
    parser.add_argument("--lean-root", type=Path)
    parser.add_argument("--root-module")
    parser.add_argument(
        "--root-declaration",
        action="append",
        dest="root_declarations",
    )
    parser.add_argument(
        "--base-import",
        action="append",
        dest="base_imports",
        default=[],
    )
    parser.add_argument("--closure-output", type=Path)
    parser.add_argument(
        "--proof-base-import",
        action="append",
        default=[],
        dest="proof_base_imports",
        help=(
            "independently verified local Lean module projected as a "
            "typed proof-base interface; repeatable"
        ),
    )
    parser.add_argument(
        "--lean-export-timeout-seconds",
        type=float,
        default=30.0,
        help=(
            "complete Lean declaration-closure build/export deadline; "
            "default: 30 seconds"
        ),
    )
    parser.add_argument(
        "--axle-operation-timeout-seconds",
        type=float,
        default=10.0,
        help="AXLE server operation timeout; default: 10 seconds",
    )
    parser.add_argument(
        "--axle-base-timeout-seconds",
        type=float,
        default=2.0,
        help="AXLE transport/queue allowance; default: 2 seconds",
    )
    args = parser.parse_args()
    closure_mode = any(
        (
            args.lean_root is not None,
            args.root_module is not None,
            bool(args.root_declarations),
            bool(args.base_imports),
            args.closure_output is not None,
        )
    )
    if closure_mode:
        if (
            args.lean_root is None
            or args.root_module is None
            or not args.root_declarations
        ):
            parser.error(
                "closure mode requires --lean-root, --root-module, "
                "and --root-declaration"
            )
        from agentic_ai_lab_proof.axle_closure_verify import run as run_closure
        from agentic_ai_lab_proof.lean_declaration_closure import LeanClosureError

        try:
            raise SystemExit(run_closure(args))
        except LeanClosureError as error:
            import json
            import sys

            print(
                json.dumps(
                    {
                        "code": error.code,
                        "detail": error.detail,
                        "schema_id": "agentic-ai-lab.axle-closure-preflight.v1",
                        "status": "rejected",
                    },
                    ensure_ascii=False,
                    separators=(",", ":"),
                    sort_keys=True,
                ),
                file=sys.stderr,
            )
            raise SystemExit(2) from error
    if not args.paths:
        parser.error("paths are required outside closure mode")
    import json as json_module
    import sys as sys_module

    deadline_seconds = (
        args.axle_operation_timeout_seconds + args.axle_base_timeout_seconds
    )
    try:
        result = asyncio.run(asyncio.wait_for(run(args), timeout=deadline_seconds))
    except TimeoutError:
        print(
            json_module.dumps(
                {
                    "base_timeout_seconds": args.axle_base_timeout_seconds,
                    "code": "axle-operation-deadline-exceeded",
                    "operation_timeout_seconds": args.axle_operation_timeout_seconds,
                    "schema_id": "agentic-ai-lab.axle-verification.v1",
                    "status": "rejected",
                },
                ensure_ascii=False,
                separators=(",", ":"),
                sort_keys=True,
            ),
            file=sys_module.stderr,
        )
        raise SystemExit(1) from None
    raise SystemExit(result)


if __name__ == "__main__":
    main()
