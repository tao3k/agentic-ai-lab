# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the factor budget study."""

from pathlib import Path

ROOT = Path.cwd().resolve()

BASE = ROOT / ".cache/ascent/factor-budget"

SNAP = BASE / "snapshot"

TOOLS = [
    {
        "type": "function",
        "name": name,
        "description": desc,
        "parameters": {
            "type": "object",
            "properties": props,
            "required": list(props),
            "additionalProperties": False,
        },
    }
    for name, desc, props in [
        (
            "factor",
            "Check source-bound implied precedence. The same evidence packet supports all returned facts.",
            {"u": {"type": "integer"}, "v": {"type": "integer"}},
        ),
        (
            "evaluate",
            "Check full schedule; return weighted completion objective, lower is better.",
            {"order": {"type": "array", "items": {"type": "integer"}}},
        ),
        (
            "explore",
            "Check partial schedule and list feasible next jobs.",
            {"prefix": {"type": "array", "items": {"type": "integer"}}},
        ),
        (
            "submit",
            "Finish with your best full schedule.",
            {"order": {"type": "array", "items": {"type": "integer"}}},
        ),
    ]
]

INSTRUCTIONS = "Minimize sum(weight[j]*completion_time[j]) plus sum(transitionPenalties[order[k]][order[k+1]]) for adjacent job pairs, on one machine without idle time. Transition penalties are additive costs; they do not change completion times. Do not manually sum full schedule or transition costs: evaluate computes them exactly; propose useful candidates and compare returned costs. There is no penalty before the first job. Include each job exactly once; obey direct and implied precedence among jobs in this phase. Source edges involving jobs outside the current phase do not constrain this phase. Evidence contains independently admitted facts and a derivation DAG; reuse it. Resolve useful factors, explore genuinely different feasible branches, evaluate candidates and submit best found. No hidden oracle access. Total budget is 98304 billed tokens including every input and all output/thinking across calls; repeated conversation inputs count again. Conservative input reservation may stop requests early. At most 3 calls, 32 tool actions, 32768 output tokens per call. Evidence validity is limited to its source digest. Your objective is a good best-found schedule, not an internal proof of the global optimum. In your FIRST response, call evaluate on at least one feasible full schedule before prolonged refinement. Do not mentally execute an exhaustive subset DP. After the first candidate, use explore on at least two alternative partial schedules at an uncertain branch, compare genuinely different feasible full schedules, and submit your best result. Prefer tool feedback over repeatedly deriving already supplied precedence facts. The first two responses are for candidate construction and branch exploration. Your THIRD response must submit the best evaluated schedule without additional optimization. The final response uses non-thinking mode; the controller gives you the best validated candidate observed, never the hidden optimum."
