# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Request for the inference reuse study study."""

import json
from ..query_contract import output_format
from ..movie_study import MAX_OUTPUT_TOKENS
from ._config import SCHEMA


def request(case, source, arm):
    public = {
        "question": case["question"],
        "schema": SCHEMA,
        "relationMeaning": {
            "cast": "film appearance by actor",
            "directed": "film director",
            "citizen": "director nationality",
            "mentor": "directed actor-to-actor mentoring edge",
            "actor_domain": "all actors",
            "banned_film": "excluded supporting films",
            "selected_country": "selected nationality",
            "target": "target actor set",
        },
    }
    if arm == "direct":
        public.update(facts=source["rows"], domains=source["domains"])
        instruction = (
            "Return only a JSON array of actor identifiers, using no outside facts."
        )
    else:
        instruction = (
            "Compile question intent, not answer values. Return {relations,rules}. Sources in schema are trusted; "
            "never define source heads. answer(Actor) is already declared. Additional derived relations are {name,types}. "
            "Every rule has head:[{relation,terms}] and body:[{relation,terms,not:true optionally}]. "
            "Terms are {var:name} or {const:value}. Shared variables join; multiple rules union. "
            "Negation must be stratified, with all variables bound by positive atoms. "
            "Recursion computes the least fixed point. Data and entity identifiers stay in Scheme. "
            "Do not hardcode actors or enumerate answers. Use source relations for bindings."
        )
    req = {
        "model": "deepseek-flash",
        "input": [
            {
                "role": "user",
                "content": instruction + "\n" + json.dumps(public, sort_keys=True),
            }
        ],
        "reasoning": {"effort": "high"},
        "max_output_tokens": MAX_OUTPUT_TOKENS,
        "stream": True,
        "store": False,
    }
    if arm != "direct":
        req["text"] = {"format": output_format()}
    return req


def price(usage):
    if not usage:
        raise ValueError("missing usage")
    cached = usage.get("input_tokens_details", {}).get("cached_tokens", 0)
    return (
        (usage["input_tokens"] - cached) * 0.3
        + cached * 0.006
        + usage["output_tokens"] * 1.2
    ) / 1e6


def completed_contract(contract, outcome):
    if outcome != "completed_ungraded":
        raise ValueError(f"provider contract not completed: {outcome}")
    if not isinstance(contract, dict):
        raise ValueError("completed provider response is not a contract object")
    return contract
