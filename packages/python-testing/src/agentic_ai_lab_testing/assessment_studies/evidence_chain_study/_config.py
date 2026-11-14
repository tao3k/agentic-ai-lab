# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the evidence chain study study."""

ARMS = ("raw-fact-reasoning", "scheme-fresh-execution", "scheme-retained-chain")


# Minimal shared-premise diagnostic in the existing Python project consumer.
SHARED_CANDIDATE = [
    "candidate",
    ["relation", "path", 2],
    ["relation", "ready", 1],
    ["rule", ["path", "?x", "?y"], ["edge", "?x", "?y"]],
    ["rule", ["path", "?x", "?z"], ["path", "?x", "?y"], ["edge", "?y", "?z"]],
    [
        "rule",
        ["ready", "?f"],
        ["need", "?f", "?a", "?b", "?c", "?d"],
        ["path", "?a", "?b"],
        ["path", "?c", "?d"],
    ],
    ["query", "ready", "?f"],
    ["limits", 256, 1024, 1024],
]

SHARED_QUESTION = (
    "Which of the listed transitions are permitted by the rules? Return their IDs."
)

SHARED_TOOL = {
    "type": "function",
    "name": "submit_answer",
    "description": "Return the permitted transition IDs.",
    "parameters": {
        "type": "object",
        "properties": {"permitted": {"type": "array", "items": {"type": "integer"}}},
        "required": ["permitted"],
        "additionalProperties": False,
    },
}

SHARED_RUBRIC = """Label only explicit atomic episodes in supplied visible reasoning. Each label has a verbatim contiguous quote, zero-based occurrence, category, concluded atom and explicitly stated ordered premises. Categories: premise_consumed (uses established evidence without proving it again), positive_derivation (an actual supported inference), absence_recheck (explicit argument that a path or transition is absent), new_residual (a supported inference about the current downstream obligation), arithmetic (resource/objective computation), ambiguous (unsupported or unclear). Relations: edge, path, ready. ready ID requires both paths of that needs row. Atom and premise endpoints must appear literally in the quote. No edges or premises may be supplied from your own source knowledge. A reference/assertion alone is not a derivation. For arithmetic and ambiguous, atom and premises may be empty. Do not infer unexposed reasoning. Do not add labels merely to populate a category. Do not repair wrong IDs. Include explicit negative reasoning, but do not infer absence from missing text. You are not given arm, score or cost; supplied reasoning can still reveal its condition. Return labels in text order. Completeness is not guaranteed."""

SHARED_LABEL_TOOL = {
    "type": "function",
    "name": "annotate",
    "description": "Record literal reasoning episodes.",
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
                        "category": {
                            "type": "string",
                            "enum": [
                                "premise_consumed",
                                "absent_premise_consumed",
                                "positive_derivation",
                                "absence_recheck",
                                "new_residual",
                                "arithmetic",
                                "ambiguous",
                            ],
                        },
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
                    },
                    "required": ["quote", "occurrence", "category", "atom", "premises"],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["episodes"],
        "additionalProperties": False,
    },
}


# Sibling branches are a research consumer, not a Library search scheduler.
BRANCH_QUESTION = (
    "Choose four item IDs maximizing sum of values plus bonuses for selected pairs. "
    "Every selected item must have both of its directed paths. Respect this branch's weight and risk limits, "
    "include at least three groups, include its required item, and omit its excluded item. "
    'Return {"selected":[IDs]}.'
)

BRANCH_SUBMIT = {
    "type": "function",
    "name": "submit_selection",
    "description": "Submit four selected item IDs.",
    "parameters": {
        "type": "object",
        "properties": {"selected": {"type": "array", "items": {"type": "integer"}}},
        "required": ["selected"],
        "additionalProperties": False,
    },
}

BRANCH_READ = {
    "type": "function",
    "name": "read_paths",
    "description": "Read directed path conclusions from the current Scheme-checked finite source. Each pair is [from,to].",
    "parameters": {
        "type": "object",
        "properties": {
            "pairs": {
                "type": "array",
                "items": {"type": "array", "items": {"type": "integer"}},
            }
        },
        "required": ["pairs"],
        "additionalProperties": False,
    },
}


SEMANTIC_LINE_CATEGORIES = [
    "premise_use",
    "path_derivation",
    "absence_argument",
    "optimization",
    "other",
    "unresolved",
]


SEMANTIC_BLOCK_TAGS = [
    "positive_fact_use",
    "negative_fact_use",
    "positive_derivation",
    "negative_argument",
    "downstream_inference",
    "optimization",
    "task_interpretation",
    "unclear",
]
