# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Contracts for the complex movie study study."""

import hashlib
import json
from ._config import TYPES


def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True).encode()


def identity(value):
    return hashlib.sha256(encoded(value)).hexdigest()


def var(name):
    return {"var": name}


def const(value):
    return {"const": value}


def atom(name, *terms, negative=False):
    result = {"relation": name, "terms": list(terms)}
    if negative:
        result["not"] = True
    return result


def rule(head, *body):
    return {"head": [head], "body": list(body)}


def declaration(name, types, source, rows, domains):
    return {
        "name": name,
        "source": source,
        "rows": rows,
        "columns": [{"kind": "symbol", "domain": domains[t]} for t in types],
    }


def program(source, contract, views=None):
    """Frame model rules with trusted finite domains and source authority."""
    if set(contract) != {"relations", "rules"}:
        raise ValueError("contract shape")
    names = {
        "cast",
        "directed",
        "citizen",
        "anchor",
        "answer",
        "eligible",
        "coactor",
        "blocked",
        "omitted_film",
    }
    extra = []
    for relation in contract["relations"]:
        if set(relation) != {"name", "types"} or relation["name"] in names:
            raise ValueError("derived declaration collision")
        names.add(relation["name"])
        extra.append(
            declaration(
                relation["name"], relation["types"], False, [], source["domains"]
            )
        )
    allowed_heads = {"answer"} | {r["name"] for r in contract["relations"]}
    if views is None:
        allowed_heads |= {"eligible", "coactor"}
    for index, r in enumerate(contract["rules"]):
        if not isinstance(r.get("head"), list):
            raise ValueError(f"rules[{index}].head must be an array of atoms")
        if any(a["relation"] not in allowed_heads for a in r["head"]):
            raise ValueError("model rule changes source authority")
    declarations = [
        declaration(n, TYPES[n], True, rows, source["domains"])
        for n, rows in source["rows"].items()
    ]
    for name in ("eligible", "coactor"):
        declarations.append(
            declaration(
                name,
                TYPES[name],
                views is not None,
                [] if views is None else views[name],
                source["domains"],
            )
        )
    declarations.append(
        declaration("answer", TYPES["answer"], False, [], source["domains"])
    )
    return {
        "relations": declarations + extra,
        "rules": contract["rules"],
        "queries": ["answer"],
    }


def view_contract():
    f, d, c, a, g, x = (var(n) for n in ("f", "d", "c", "a", "g", "x"))
    return {
        "relations": [],
        "rules": [
            rule(
                atom("eligible", c, f, d, a),
                atom("cast", f, a),
                atom("directed", f, d),
                atom("citizen", d, c),
            ),
            rule(
                atom("coactor", x, g, a),
                atom("anchor", x),
                atom("cast", g, x),
                atom("cast", g, a),
            ),
        ],
    }
