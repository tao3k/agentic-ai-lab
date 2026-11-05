# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Check both source generations against independent finite oracles before live calls."

import copy
from agentic_ai_lab_runtime.reasoning import EvidenceInteraction
from ..consumption_study import oracle as balanced_oracle
from ._cases import tagged_oracle


def _qualify_source_versions(engine, case):
    """Own the qualify source versions phase and retain its evidence checks."""
    for sources in (case["sources"], case["changed"]):
        with EvidenceInteraction(engine, sources, case["operations"]) as preflight:
            p = copy.deepcopy(case["base"])
            p["relations"] = [
                copy.deepcopy(next((s for s in sources if s["name"] == r["name"]), r))
                if r["source"]
                else r
                for r in p["relations"]
            ]
            receipt = preflight.chain.query(p)
            if case["family"] == "context-balanced-paths":
                expected = balanced_oracle(sources)
                assert (
                    set(map(tuple, receipt["result"]["relations"]["balanced"]))
                    == expected
                )
            else:
                expected = tagged_oracle(sources)
                assert (
                    set(map(tuple, receipt["result"]["relations"]["flow"]))
                    == expected[0]
                )
                assert (
                    set(map(tuple, receipt["result"]["relations"]["permit"]))
                    == expected[1]
                )
