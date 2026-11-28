# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Request for the complex movie study study."""

from ..movie_study import MAX_OUTPUT_TOKENS
from ..query_contract import output_format, compact_request
from ._config import TYPES
from ._contracts import encoded, identity


def request(source, case, arm, views=None, compiler_context="facts"):
    if compiler_context not in ("facts", "intent"):
        raise ValueError("unknown compiler context")
    public = {
        "question": case["question"],
        "bindings": {
            k: case[k] for k in ("country", "anchor", "omittedFilm", "blocked")
        },
        "domains": source["domains"],
        "facts": source["rows"],
        "schema": {**TYPES, "omitted_film": ["Film"], "blocked": ["Actor"]},
    }
    if case.get("rightCountry"):
        public["bindings"]["rightCountry"] = case["rightCountry"]
    if arm == "direct":
        instruction = "Return only a JSON array of actor QIDs answering the question. Use no outside facts."
    else:
        if views is not None:
            public["materializedViews"] = views
        instruction = (
            "Compile the question to a finite relational program, not its answer. Return JSON with exactly "
            "relations and rules. relations declares only additional derived relations as {name,types}, with types "
            "from Film,Actor,Director,Country. answer(Actor) is already declared. Source relations cast(Film,Actor), "
            "directed(Film,Director), citizen(Director,Country), anchor(Actor), omitted_film(Film), blocked(Actor) "
            "are trusted. eligible(Country,Film,Director,Actor) and coactor(Actor,Film,Actor) are already declared: "
            + (
                "they contain supplied materialized rows; do not define their rule heads. "
                if views is not None
                else "they are empty derived relations; define them if used. "
            )
            + 'Each rule is {head:[atom],body:[atoms]}. An atom is {relation,terms:[{var:"x"} or {const:"QID"}],'
            "not:true optionally}. Negation must be stratified and all variables grounded by positive atoms. "
            "Multiple rules for one head implement union; shared variables implement joins. Never put source "
            "relations in heads. ReasoningRuntime queries answer. No Python, Scheme, prose or markdown."
        )
    result = {
        "model": "deepseek-flash",
        "input": [
            {"role": "user", "content": instruction + "\n" + encoded(public).decode()}
        ],
        "reasoning": {"effort": "high"},
        "max_output_tokens": MAX_OUTPUT_TOKENS,
        "stream": True,
        "store": False,
    }
    if arm != "direct":
        result["text"] = {"format": output_format()}
    if arm != "direct" and compiler_context == "intent":
        result = compact_request(result, identity(source))
    return result
