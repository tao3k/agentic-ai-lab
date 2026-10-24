# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Scheme candidate boundary checks owned by the Ascent target."""

from __future__ import annotations

import re

from ..ascent.candidate import SchemeChecker, candidate_text
from ..model import CaseContext

PATH_CANDIDATE = (
    "(candidate (relation path 2) "
    "(rule (path ?x ?y) (edge ?x ?y)) "
    "(rule (path ?x ?z) (edge ?x ?y) (path ?y ?z)) "
    "(query path ?x ?y) (limits 16 64 64))"
)


def candidate_boundary(_context: CaseContext) -> None:
    valid = "(candidate (relation path 2) (query path ?x ?y) (limits 8 8 8))"
    if candidate_text(valid) != valid:
        raise AssertionError("valid inert candidate was rejected")
    for unsafe in ("#.(delete-file \"x\")", valid + " (second)",
                   valid.replace("path", "#.(run)"), "before\n" + valid,
                   "(candidate (relation path 2)"):
        if candidate_text(unsafe) is not None:
            raise AssertionError("unsafe candidate text was accepted")


def native_withdrawal(context: CaseContext) -> None:
    checker = SchemeChecker(context.module_root("gerbil-ascent"))
    try:
        rejected = checker.attempt(PATH_CANDIDATE.replace(
            "(relation path 2)", "(relation edge 2) (relation path 2)"))
        receipt = checker.attempt(PATH_CANDIDATE)
        repeated = checker.attempt(PATH_CANDIDATE)
    finally:
        checker.close()
    if rejected["status"] != "rejected" or "duplicate-relation" not in rejected["diagnostics"]:
        raise AssertionError("duplicate source declaration escaped admission")
    if repeated != receipt or receipt["status"] != "complete" or receipt["bound"] != "#t":
        raise AssertionError("source snapshot receipt is incomplete or unstable")
    if receipt["diagnostics"] != "()":
        raise AssertionError("complete receipt retained diagnostics")
    rows = set(re.findall(r"\(\d+ \d+\)", receipt["rows"]))
    if rows != {"(0 1)", "(0 2)", "(1 2)"}:
        raise AssertionError("original graph closure differs")
    if (receipt["after-status"], receipt["after-rows"], receipt["after-bound"]) != (
            "complete", "((0 1))", "#t"):
        raise AssertionError("withdrawn source was not reflected")
