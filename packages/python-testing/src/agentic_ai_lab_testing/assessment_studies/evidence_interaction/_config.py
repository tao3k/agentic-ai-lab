# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the evidence interaction study."""

from pathlib import Path
import sys

ROOT = Path.cwd().resolve()

sys.path.insert(0, str(ROOT / "python/src"))


RUNTIME = ROOT / ".cache/ascent/evidence-interaction/runtime"

KERNEL = ROOT / ".cache/ascent/crosspath-search/snapshot"

SOLVER_TOOLS = [
    {
        "type": "function",
        "name": "expand",
        "description": "Select and expand exactly one unvisited child of the supplied parent.",
        "parameters": {
            "type": "object",
            "properties": {"optionId": {"type": "integer"}},
            "required": ["optionId"],
            "additionalProperties": False,
        },
    }
]

RUBRIC = """Extract atomic reasoning episodes ONLY from the supplied external model reasoning. Return exact contiguous quotes, zero-based occurrence, a single concluded atom [relation, integer arguments], the ordered premises EXPLICITLY stated in that quote as atoms, and kind derive/reuse/mention/conditional_recheck/uncertain. Relations are edge, path, ready. ready f means both paths of needs row f. Option IDs are not fragment IDs. A derive episode must contain an inference and actual support, not just an asserted result or a reference to evidence. A reuse episode cites an established result without deriving it. Empty premises are allowed for references and uncertainty, but do not invent edges or fill support from source. Alternative edge chains stay different. Changed value/resource checks are conditional_recheck, not source-path repetitions. Use uncertain for ambiguity. A quoted literal fragment ID must agree with the atom; never silently repair a model's wrong ID. Path endpoints and premise numbers must occur in the quote. Extract explicit negative claims too, using polarity false; absence of derivation is not evidence of absence of thinking. You are blind to arm, score and cost, although reasoning can reveal supplied evidence. Do not invent an episode to fill a category. Native source truth is checked independently after extraction. Quotes must occur verbatim. Return every explicit relevant episode you identify; completeness and independent-rater agreement are unvalidated."""

LABEL_TOOL = {
    "type": "function",
    "name": "annotate",
    "description": "Record exact atomic reasoning episodes.",
    "parameters": {
        "type": "object",
        "properties": {
            "episodes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "quote": {"type": "string"},
                        "occurrence": {"type": "integer"},
                        "atom": {
                            "type": "array",
                            "items": {"type": ["string", "integer"]},
                        },
                        "premises": {
                            "type": "array",
                            "items": {
                                "type": "array",
                                "items": {"type": ["string", "integer"]},
                            },
                        },
                        "polarity": {"type": "boolean"},
                        "kind": {
                            "type": "string",
                            "enum": [
                                "derive",
                                "reuse",
                                "mention",
                                "conditional_recheck",
                                "uncertain",
                            ],
                        },
                    },
                    "required": [
                        "quote",
                        "occurrence",
                        "atom",
                        "premises",
                        "polarity",
                        "kind",
                    ],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["episodes"],
        "additionalProperties": False,
    },
}
