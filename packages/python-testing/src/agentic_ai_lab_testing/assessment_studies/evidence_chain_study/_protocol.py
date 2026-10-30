# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Protocol for the evidence chain study study."""

import copy, json
from .. import evidence_chain_workload as workload


def loose_json(text):
    """One JSON payload may be surrounded by prose or a Markdown fence."""
    if isinstance(text, (dict, list)):
        return copy.deepcopy(text)
    try:
        return json.loads(text)
    except (ValueError, TypeError):
        pass
    decoder = json.JSONDecoder()
    values = []
    position = 0
    while position < len(text):
        if text[position] not in "{[":
            position += 1
            continue
        try:
            value, size = decoder.raw_decode(text[position:])
            values.append(value)
            position += size
        except ValueError:
            position += 1
    if len(values) != 1:
        raise ValueError(
            "Provide one unambiguous JSON payload; surrounding prose is allowed."
        )
    return values[0]


def tools(assisted):
    definitions = [
        {
            "type": "function",
            "name": "scan_facts",
            "description": "Read named finite source relations; omit relations to read all. Actor indices refer to the ordered Actor domain returned here.",
            "parameters": {
                "type": "object",
                "properties": {
                    "relations": {"type": "array", "items": {"type": "string"}}
                },
            },
        },
        {
            "type": "function",
            "name": "submit_answer",
            "description": "Submit actor identifiers or zero-based Actor indices, OR reference a previously checked unary result using reference and relation. Verification returns verified/not_verified. Sources are checked for identifier membership before grading.",
            "parameters": {
                "type": "object",
                "properties": {
                    "answer": {"type": "array"},
                    "reference": {"type": "string"},
                    "relation": {"type": "string"},
                },
            },
        },
    ]
    if assisted:
        definitions.append(
            {
                "type": "function",
                "name": "check_evidence",
                "description": "Execute expressed relational claims in Scheme. contract has relations (name/types) and rules (head/body atoms with relation/terms). Terms are var or const objects; body atoms may have not:true. A single head object or head array is accepted. Declare only new derived relations; answer already exists. queries selects relation names. Completed components may be reused according to returned retention metadata; re-express a previous definition or extend a retained claim. A check certifies rule consequences, not English intent.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "contract": {"type": "object"},
                        "queries": {"type": "array", "items": {"type": "string"}},
                    },
                },
            }
        )
    return definitions


def grade_answer(args, chain, case, observed):
    if not observed:
        raise ValueError(
            "Acquire source facts or checked evidence before submitting an answer."
        )
    if "reference" in args:
        values = [
            r[0]
            for r in chain.answer(args["reference"], args.get("relation", "answer"))
        ]
    else:
        values = args["answer"]
        if not isinstance(values, list):
            raise ValueError("answer must be a list or a checked result reference")
        domain = case["source"]["domains"]["Actor"]
        values = [
            domain[x] if type(x) == int and 0 <= x < len(domain) else x for x in values
        ]
        if any(not isinstance(x, str) or x not in domain for x in values):
            raise ValueError(
                "Answer contains identifiers outside the supplied Actor domain; original identifiers or zero-based domain indices are accepted."
            )
    return sorted(set(values)) == [
        r[0] for r in workload.expected(case, case["source"])
    ]
