# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the factor pilot study."""

from pathlib import Path

ROOT = Path.cwd().resolve()

BASE = ROOT / ".cache/ascent/factor-pilot"

SNAP = BASE / "snapshot"


CASES = [
    {
        "id": "fork",
        "edges": [[0, 2], [1, 2], [2, 4], [1, 3], [3, 5], [4, 6], [5, 6]],
        "durations": [3, 2, 4, 1, 3, 2, 1],
        "weights": [[2, 1, 4, 2, 1, 3], [1, 5, 1, 3, 4, 2, 8]],
    },
    {
        "id": "diamond",
        "edges": [[0, 2], [0, 3], [1, 3], [2, 4], [3, 4], [3, 5], [4, 6]],
        "durations": [2, 4, 1, 3, 2, 1, 3],
        "weights": [[1, 3, 2, 4, 1, 2], [5, 1, 4, 1, 3, 7, 2]],
    },
]

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
            "Check whether precedence u -> v is implied by the source graph; true facts must hold in schedules.",
            {"u": {"type": "integer"}, "v": {"type": "integer"}},
        ),
        (
            "evaluate",
            "Check a full schedule and return weighted completion cost; lower is better.",
            {"order": {"type": "array", "items": {"type": "integer"}}},
        ),
        (
            "explore",
            "Check a partial schedule and list feasible next jobs.",
            {"prefix": {"type": "array", "items": {"type": "integer"}}},
        ),
        (
            "submit",
            "Submit your best full schedule and finish the phase.",
            {"order": {"type": "array", "items": {"type": "integer"}}},
        ),
    ]
]

INSTRUCTIONS = "You solve finite scheduling optimization. Minimize sum(weight[j]*completion_time[j]) on a single machine without idle time. All jobs appear once and every implied precedence must hold. Use factor to resolve shared deterministic factors, explore to investigate branches, and evaluate to compare candidate schedules. Finish with submit. You have at most 6 response calls, 24 tool actions and 24576 total output tokens including reasoning per phase. Do not access hidden grading. Some tool replies include retained facts or checked fragments; use them if useful. Cached evidence is confined to the same source digest. Optimize deeply within the budget."
