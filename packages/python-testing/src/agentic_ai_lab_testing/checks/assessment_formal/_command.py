# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the assessment formal study."""

from __future__ import annotations

from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import json
import sys
import time
from ..assessment_models import MODEL_ORDER
from ._config import GROUPS, SECONDS
from ._runner import Runner


def renderings_from_batch(output: str, languages: list[str]) -> dict[str, str]:
    """Keep every named source comparison; batching only avoids Lean restarts."""
    try:
        rows = json.loads(output)
    except (json.JSONDecodeError, TypeError) as error:
        raise RuntimeError("malformed Lean source rendering batch") from error
    if not isinstance(rows, list) or any(
        not isinstance(row, list)
        or len(row) != 2
        or not all(isinstance(value, str) for value in row)
        for row in rows
    ):
        raise RuntimeError("malformed Lean source rendering rows")
    result = dict(rows)
    if len(result) != len(rows) or set(result) != set(languages):
        raise RuntimeError("missing, duplicate or extra Lean source rendering")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("quint",))
    parser.add_argument("group", nargs="?", default="all")
    args = parser.parse_args()
    if args.mode == "all" and args.group != "all":
        parser.error("full formal verification requires the complete inventory")
    models = (
        tuple(MODEL_ORDER)
        if args.group == "all"
        else GROUPS.get(args.group, (args.group,))
    )
    if any(model not in MODEL_ORDER for model in models):
        parser.error("unknown Quint feature")
    runner = Runner()
    try:
        results = runner.quint_checks(models)
        (runner.output / "receipt.json").write_text(
            json.dumps(
                {
                    "models": results,
                    "complete": set(results) == set(models),
                    "seconds": time.monotonic() - runner.started,
                    "budgetSeconds": SECONDS,
                },
                indent=2,
            )
            + "\n"
        )
        return 0
    except Exception as failure:
        report_text(str(failure), file=sys.stderr)
        return 1
