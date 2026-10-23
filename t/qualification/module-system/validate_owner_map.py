#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Validate the source-owned RFC45 qualification map without stored receipts."""

from __future__ import annotations

import ast
import re
from pathlib import Path
from typing import Any

SCHEMA = "agentic-ai-lab.module-system-qualification-ownership.v1"
ROW_IDS = tuple(
    f"rfc45-{index:02d}-{suffix}"
    for index, suffix in (
        (1, "mix-module-expansion"),
        (2, "g0-decision"),
        (3, "runtime-context-recovery"),
        (4, "observability-snapshot"),
        (6, "gerbil-poo-consumption"),
        (7, "public-composition"),
    )
)
ROW_FIELDS = {
    "row_id",
    "rfc",
    "source_path",
    "source_symbol",
    "source_kind",
    "test_path",
    "test_symbol",
    "target_name",
}
SYMBOL_KINDS = {"function", "macro", "test-binding"}
RELATIVE_PATH = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_./-]*$")
TARGET_NAME = re.compile(r"^rfc45_[0-9]{2}_[a-z0-9_]+$")


class OwnerMapValidationError(ValueError):
    pass


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise OwnerMapValidationError(message)


def load_manifest(path: Path) -> dict[str, Any]:
    """Read literal assignments from the Starlark/Python-compatible manifest."""
    parsed = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    values: dict[str, Any] = {}
    for node in parsed.body:
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant):
            continue
        _require(
            isinstance(node, ast.Assign),
            "manifest may contain only literal assignments",
        )
        _require(len(node.targets) == 1, "manifest assignment must have one target")
        target = node.targets[0]
        _require(
            isinstance(target, ast.Name), "manifest assignment target must be a name"
        )
        try:
            values[target.id] = ast.literal_eval(node.value)
        except (ValueError, TypeError) as error:
            raise OwnerMapValidationError(
                f"{target.id}: manifest value must be literal"
            ) from error
    _require(
        set(values)
        == {
            "OWNER_MAP_SCHEMA",
            "DESCENDANT_BOUNDARIES",
            "OWNER_MAP_ROWS",
            "QUALIFICATION_TARGET",
        },
        "manifest declarations drift",
    )
    return values


def _symbol_pattern(symbol: str, kind: str) -> re.Pattern[str]:
    if kind == "macro":
        return re.compile(
            r"\((?:defsyntax|defrules|defsyntax-call)\s+\(?"
            + re.escape(symbol)
            + r"(?:\s|\))"
        )
    if kind == "test-binding":
        return re.compile(r"\(def\s+\(?" + re.escape(symbol) + r"(?:\s|\))")
    return re.compile(r"\(def\s+\(" + re.escape(symbol) + r"(?:\s|\))")


def _validate_owner(
    path: Any, symbol: Any, kind: Any, role: str, repo_root: Path
) -> None:
    _require(
        isinstance(path, str) and RELATIVE_PATH.fullmatch(path) is not None,
        f"{role}: invalid path",
    )
    _require(path.endswith(".ss"), f"{role}: owner must be Gerbil source")
    _require(isinstance(symbol, str) and symbol, f"{role}: missing symbol")
    _require(kind in SYMBOL_KINDS, f"{role}: invalid symbol kind")
    owner = repo_root / path
    _require(owner.is_file(), f"{role}: missing owner {path}")
    source = owner.read_text(encoding="utf-8")
    _require(
        _symbol_pattern(symbol, kind).search(source) is not None,
        f"{role}: stale symbol {symbol}",
    )


def validate_manifest(values: dict[str, Any], repo_root: Path) -> None:
    _require(values.get("OWNER_MAP_SCHEMA") == SCHEMA, "schema identity drift")
    boundaries = values.get("DESCENDANT_BOUNDARIES")
    _require(
        isinstance(boundaries, list) and boundaries,
        "descendant boundaries must be non-empty",
    )
    for boundary in boundaries:
        _require(
            isinstance(boundary, str) and RELATIVE_PATH.fullmatch(boundary) is not None,
            "invalid descendant boundary",
        )

    rows = values.get("OWNER_MAP_ROWS")
    _require(isinstance(rows, list), "OWNER_MAP_ROWS must be a list")
    _require(
        tuple(row.get("row_id") for row in rows if isinstance(row, dict)) == ROW_IDS,
        "owner row identities drift",
    )
    target_names: set[str] = set()
    for expected_id, row in zip(ROW_IDS, rows, strict=True):
        _require(isinstance(row, dict), f"{expected_id}: row must be a dictionary")
        _require(set(row) == ROW_FIELDS, f"{expected_id}: row fields drift")
        _require(row["row_id"] == expected_id, f"{expected_id}: row identity drift")
        _require(row["rfc"] == expected_id[3:8], f"{expected_id}: RFC identity drift")
        _validate_owner(
            row["source_path"],
            row["source_symbol"],
            row["source_kind"],
            f"{expected_id}.source",
            repo_root,
        )
        _validate_owner(
            row["test_path"],
            row["test_symbol"],
            "test-binding",
            f"{expected_id}.test",
            repo_root,
        )
        for boundary in boundaries:
            _require(
                not row["source_path"].startswith(f"{boundary}/"),
                f"{expected_id}: descendant source ownership",
            )
            _require(
                not row["test_path"].startswith(f"{boundary}/"),
                f"{expected_id}: descendant test ownership",
            )
        target_name = row["target_name"]
        _require(
            isinstance(target_name, str)
            and TARGET_NAME.fullmatch(target_name) is not None,
            f"{expected_id}: invalid target name",
        )
        _require(
            target_name not in target_names, f"{expected_id}: duplicate target name"
        )
        target_names.add(target_name)

    _require(
        values.get("QUALIFICATION_TARGET")
        == "//t/qualification/module-system:owner_map_tests",
        "qualification target drift",
    )
