# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Contracts for the iterative inference study study."""

from .. import inference_reuse_study as study
from ..query_contract import output_format


def action_format(assisted, initial=False):
    def obj(properties):
        return {
            "type": "object",
            "properties": properties,
            "required": list(properties),
            "additionalProperties": False,
        }

    text = {"type": "string"}
    relation_name = {"type": "string", "pattern": "^[A-Za-z_][A-Za-z0-9_-]*$"}
    choices = [
        obj(
            {
                "action": {"enum": ["scan"]},
                "relations": {
                    "type": "array",
                    "items": {"enum": list(study.SCHEMA)},
                    "minItems": 1,
                },
            }
        ),
        obj(
            {"action": {"enum": ["answer"]}, "answer": {"type": "array", "items": text}}
        ),
    ]
    if assisted:
        choices.append(
            obj(
                {
                    "action": {"enum": ["query"]},
                    "contract": output_format()["schema"],
                    "queries": {
                        "type": "array",
                        "items": relation_name,
                        "minItems": 1,
                        "maxItems": 16,
                    },
                }
            )
        )
    if initial:
        choices = [
            choice
            for choice in choices
            if choice["properties"]["action"]["enum"] != ["answer"]
        ]
    return {
        "type": "json_schema",
        "name": "ascent_inference_action",
        "schema": {"anyOf": choices},
    }


def evidence_program(source, action):
    p = study.program(source, action["contract"])
    p["queries"] = action["queries"]
    derived = {r["name"]: r for r in p["relations"] if not r["source"]}
    for name in p["queries"]:
        if "(" in name or ")" in name:
            raise ValueError(
                'queries requires bare relation names, e.g. ["witness"], not ["witness(X,Y,T)"]; full rows are returned'
            )
    if any(name not in derived for name in p["queries"]):
        raise ValueError(
            "use scan for raw relations; query must build derived evidence"
        )
    return p
