# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the candidate model study."""

from pathlib import Path

ROOT = Path.cwd().resolve()

RUNTIME = ROOT / ".cache/ascent/candidate-interaction/runtime"

PREPARED = ROOT / ".cache/ascent/evidence-interaction/runtime/lib"

CANONICAL = ROOT / ".cache/ascent/candidate-interaction/canonical-runtime/lib"


TASKS = [
    {
        "case": 0,
        "meaning": "path(x,y) iff a directed walk of positive length exists from x to y. Cycles can derive path(x,x); zero-length walks alone cannot.",
        "derived": [["path", 2]],
        "query": ["path", "?x", "?y"],
    },
    {
        "case": 1,
        "meaning": "path(x,y) iff a directed walk of positive even length exists from x to y. Walks may repeat vertices. Length zero alone is excluded.",
        "derived": [["path", 2]],
        "query": ["path", "?x", "?y"],
    },
    {
        "case": 2,
        "meaning": "path is directed positive-length reachability. both(z) iff there exist x in left and y in right such that path(x,z) AND path(y,z). left contains 0; right contains 1. Walks may repeat vertices.",
        "derived": [["path", 2], ["both", 1]],
        "query": ["both", "?z"],
    },
]

TOOL = {
    "type": "function",
    "name": "submit_rules",
    "description": "Submit rules for the supplied fixed Datalog specification.",
    "parameters": {
        "type": "object",
        "properties": {
            "rules": {
                "type": "array",
                "minItems": 1,
                "maxItems": 4,
                "items": {
                    "type": "array",
                    "minItems": 2,
                    "maxItems": 5,
                    "items": {
                        "type": "array",
                        "minItems": 2,
                        "maxItems": 3,
                        "items": {"type": ["string", "integer"]},
                    },
                },
            }
        },
        "required": ["rules"],
        "additionalProperties": False,
    },
}
