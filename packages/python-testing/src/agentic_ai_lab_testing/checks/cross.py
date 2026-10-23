# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Cross-module Runtime graph and Ascent Scheme candidate check."""

from __future__ import annotations

import contextlib
import io

from ..ascent.candidate import SchemeChecker
from ..ascent.live import build_graph
from ..model import CaseContext
from .ascent import PATH_CANDIDATE
from .runtime import fake_client


def runtime_ascent_candidate(context: CaseContext) -> None:
    calls: list[dict] = []
    checker = SchemeChecker(context.module_root("gerbil-ascent"))
    try:
        graph = build_graph(fake_client(PATH_CANDIDATE, calls),
                            "deepseek-flash", checker.attempt)
        with contextlib.redirect_stdout(io.StringIO()):
            state, trace = graph.invoke_with_trace({"messages": [
                {"role": "user", "content": "check the graph"}
            ]})
    finally:
        checker.close()
    receipt = state["receipt"]
    if trace != ["model", "candidate"] or receipt is None:
        raise AssertionError("cross-module graph did not reach Scheme")
    if receipt["status"] != "complete" or receipt["after-status"] != "complete":
        raise AssertionError("cross-module candidate was not solved")
    if receipt["after-rows"] != "((0 1))" or "instructions" in calls[0]:
        raise AssertionError("withdrawal or prompt boundary changed")
