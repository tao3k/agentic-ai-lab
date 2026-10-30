# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Tools for the iterative tool inference study study."""

import copy
from .. import iterative_inference_study as loop


def tool_definitions(assisted):
    choices = loop.action_format(assisted)["schema"]["anyOf"]
    result = []
    names = {"scan": "scan_facts", "query": "check_evidence", "answer": "submit_answer"}
    descriptions = {
        "scan": "Read only the named finite source relations.",
        "query": "Check and retain executable claims in Scheme, returning source-bound evidence and aliases. Compile intent without manually enumerating joins. contract.relations contains ONLY new derived declarations, never sources or the already declared answer relation. Rules have head arrays. Query selectors are bare names. Evidence certifies rule consequences, not natural-language intent.",
        "answer": "Submit unique actor identifiers for independent verification. Only verified/not_verified is returned.",
    }
    for choice in choices:
        kind = choice["properties"]["action"]["enum"][0]
        parameters = copy.deepcopy(choice)
        parameters["properties"].pop("action")
        parameters["required"].remove("action")
        result.append(
            {
                "type": "function",
                "name": names[kind],
                "description": descriptions[kind],
                "parameters": parameters,
            }
        )
    return result
