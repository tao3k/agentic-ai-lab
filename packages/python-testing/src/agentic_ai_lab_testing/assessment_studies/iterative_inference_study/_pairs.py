# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Compare jointly verified trial effort while retaining censored outcomes."

from ..inference_effort import paired_reduction


def _pair_verified_trials(trials, receipt):
    """Own the pair verified trials phase without weakening its checks."""
    pairs = []
    for case, rep in trials:
        baseline = next(
            e["effort"]
            for e in receipt["episodes"]
            if e["case"] == case["name"]
            and e["repetition"] == rep
            and e["arm"] == "raw-fact-reasoning"
        )
        assisted = next(
            e["effort"]
            for e in receipt["episodes"]
            if e["case"] == case["name"]
            and e["repetition"] == rep
            and e["arm"] == "scheme-evidence"
        )
        pairs.append(
            {
                "case": case["name"],
                "repetition": rep,
                "baseline": baseline,
                "assisted": assisted,
                "modelTurnReduction": paired_reduction(
                    baseline, assisted, "modelCalls"
                ),
                "reasoningTokenReduction": paired_reduction(
                    baseline, assisted, "observedReasoningTokens"
                ),
                "allModelTokenReduction": paired_reduction(
                    baseline, assisted, "totalModelTokens"
                ),
            }
        )
    return pairs
