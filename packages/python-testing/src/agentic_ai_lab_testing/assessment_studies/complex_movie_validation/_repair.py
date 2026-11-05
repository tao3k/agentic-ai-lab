# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Repair for the complex movie validation study."""

import copy
from .. import complex_movie_study as study


def singleton_heads(contract):
    """One syntactic projection only; no operator, constant or body changes."""
    repaired = copy.deepcopy(contract)
    count = 0
    if not isinstance(repaired, dict) or set(repaired) != {"relations", "rules"}:
        raise ValueError("contract shape")
    for rule in repaired["rules"]:
        if isinstance(rule.get("head"), dict):
            rule["head"] = [rule["head"]]
            count += 1
    return repaired, count


def witnesses(engine, source, case):
    contract = study.gold(case)
    a, f, d, g, e = (study.var(n) for n in ("a", "f", "d", "g", "e"))
    left = [
        study.atom("answer", a),
        study.atom("eligible", study.const(case["country"]), f, d, a),
        study.atom("omitted_film", f, negative=True),
    ]
    right = [
        study.atom("answer", a),
        study.atom("coactor", study.const(case["anchor"]), g, a),
    ]
    right_terms = [a, g, study.const(case["anchor"])]
    right_types = ["Actor", "Film", "Actor"]
    if case.get("rightCountry"):
        right.append(study.atom("eligible", study.const(case["rightCountry"]), g, e, a))
        right_terms += [e, study.const(case["rightCountry"])]
        right_types += ["Director", "Country"]
    if case["scope"] in ("left", "both"):
        left.append(study.atom("blocked", a, negative=True))
    if case["scope"] == "both":
        right.append(study.atom("blocked", a, negative=True))
    contract["relations"] += [
        {"name": "audit_left", "types": ["Actor", "Film", "Director", "Country"]},
        {"name": "audit_right", "types": right_types},
    ]
    contract["rules"] += [
        study.rule(
            study.atom("audit_left", a, f, d, study.const(case["country"])), *left
        ),
        study.rule(study.atom("audit_right", *right_terms), *right),
    ]
    p = study.program(source, contract)
    p["relations"] += [
        study.declaration(
            "omitted_film", ["Film"], True, [[case["omittedFilm"]]], source["domains"]
        ),
        study.declaration(
            "blocked", ["Actor"], True, [[case["blocked"]]], source["domains"]
        ),
    ]
    p["queries"] = ["answer", "audit_left", "audit_right"]
    with engine.open(p) as session:
        result = session.run()
        if not result["complete"]:
            raise RuntimeError("witness evaluation incomplete")
    index = {}
    for claim in source["claims"]:
        index.setdefault((claim["relation"], tuple(claim["row"])), []).append(
            claim["statement"]
        )
    receipt = {"answers": result["relations"]["answer"], "left": [], "right": []}
    for actor, film, director, country in result["relations"]["audit_left"]:
        receipt["left"].append(
            {
                "row": [actor, film, director, country],
                "statements": [
                    index[("cast", (film, actor))],
                    index[("directed", (film, director))],
                    index[("citizen", (director, country))],
                ],
            }
        )
    for row in result["relations"]["audit_right"]:
        actor, film, anchor = row[:3]
        statements = [index[("cast", (film, actor))], index[("cast", (film, anchor))]]
        if len(row) == 5:
            director, country = row[3:]
            statements += [
                index[("directed", (film, director))],
                index[("citizen", (director, country))],
            ]
        receipt["right"].append({"row": row, "statements": statements})
    return receipt
