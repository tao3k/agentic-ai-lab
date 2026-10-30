# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Workload for the inference reuse study study."""

import copy
from ..complex_movie_study import atom, rule, var, declaration
from ._config import SCHEMA, STRUCTURES


def workload(index):
    """Independent synthetic entities and four structures withheld from movie pilot."""
    prefix = f"holdout{index}_"
    actors = [prefix + f"actor{i}" for i in range(12)]
    films = [prefix + f"film{i}" for i in range(6)]
    directors = [prefix + f"director{i}" for i in range(3)]
    countries = [prefix + f"country{i}" for i in range(2)]
    rows = {
        "cast": [
            [films[f], actors[a]]
            for f, a in [
                (0, 0),
                (0, 1),
                (0, 2),
                (1, 1),
                (1, 3),
                (2, 2),
                (2, 4),
                (3, 5),
                (3, 6),
                (4, 6),
                (4, 7),
                (5, 8),
                (5, 9),
            ]
        ],
        "directed": [[f, directors[i % 3]] for i, f in enumerate(films)],
        "citizen": [
            [directors[0], countries[0]],
            [directors[1], countries[1]],
            [directors[2], countries[0]],
        ],
        "mentor": [
            [actors[a], actors[b]]
            for a, b in [
                (10, 11),
                (11, 0),
                (9, 1),
                (8, 9),
                (7, 8),
                (6, 7),
                (5, 6),
                (4, 5),
                (3, 4),
                (2, 3),
                (1, 2),
                (0, 1),
            ]
        ],
        "actor_domain": [[a] for a in actors],
        "banned_film": [[films[0]]],
        "selected_country": [[countries[0]]],
        "target": [[actors[0]]],
    }
    if index == 3:
        rows["mentor"].remove([actors[9], actors[1]])
        rows["mentor"].append([actors[9], actors[10]])
    source = {
        "domains": dict(
            Film=films, Actor=actors, Director=directors, Country=countries
        ),
        "rows": rows,
    }
    structure = STRUCTURES[index]
    questions = {
        "mentor-chain": "Return actors x with a directed mentor edge x->y and y->z, where z acts in a film whose director has the selected_country. The two mentor edges must share y; cast, directed and citizen must share the same film and director. Actors may repeat along the path; do not require x itself to act.",
        "witness-local-exclusion": "Return actors with at least one film directed by a director with selected_country, with that supporting film not in banned_film. Exclude individual supporting films before projecting actor: acting in a banned film must not exclude an actor who also has another qualifying, unbanned film.",
        "anti-existential": "Return actors in actor_domain with at least one film whose director has selected_country AND with no appearance in any banned_film. The second condition excludes the entire actor if ANY banned-film appearance exists, even if a different film qualifies.",
        "recursive-mentor": "Return actors that can reach an actor in target through ONE OR MORE directed mentor edges. Include any path length, including cycles; zero-length paths alone do not qualify. An actor in target qualifies only if it also has a positive-length path to target.",
    }
    return {
        "name": structure,
        "question": questions[structure]
        + " Use only the supplied finite relations. Return unique actor identifiers.",
        "source": source,
        "withdrawal": {
            "relation": "mentor" if index in (0, 3) else "cast",
            "row": [actors[11], actors[0]]
            if index == 0
            else [actors[0], actors[1]]
            if index == 3
            else [films[2], actors[2]]
            if index == 1
            else [films[0], actors[2]],
        },
    }


def updated(case):
    source = copy.deepcopy(case["source"])
    change = case["withdrawal"]
    source["rows"][change["relation"]].remove(change["row"])
    return source


def expected(case, source):
    """Independent finite set oracle, never imported into model-facing request."""
    rows = source["rows"]
    cast = set(map(tuple, rows["cast"]))
    edges = set(map(tuple, rows["mentor"]))
    selected = {r[0] for r in rows["selected_country"]}
    banned = {r[0] for r in rows["banned_film"]}
    qualifying = {
        f
        for f, d in rows["directed"]
        for dd, c in rows["citizen"]
        if d == dd and c in selected
    }
    eligible = {a for f, a in cast if f in qualifying}
    name = case["name"]
    if name == "mentor-chain":
        answer = {x for x, y in edges for yy, z in edges if y == yy and z in eligible}
    elif name == "witness-local-exclusion":
        answer = {a for f, a in cast if f in qualifying and f not in banned}
    elif name == "anti-existential":
        answer = eligible - {a for f, a in cast if f in banned}
    else:
        paths = set(edges)
        while True:
            more = paths | {(x, z) for x, y in paths for yy, z in edges if y == yy}
            if more == paths:
                break
            paths = more
        target = {r[0] for r in rows["target"]}
        answer = {x for x, y in paths if y in target}
    return [[a] for a in sorted(answer)]


def oracle_contract(case):
    a, b, c, f, d, k = (var(n) for n in ("a", "b", "c", "f", "d", "k"))
    eligible = [
        atom("cast", f, a),
        atom("directed", f, d),
        atom("citizen", d, k),
        atom("selected_country", k),
    ]
    name = case["name"]
    relations = []
    if name == "mentor-chain":
        eligible = [
            atom("mentor", a, b),
            atom("mentor", b, c),
            atom("cast", f, c),
            *eligible[1:],
        ]
        rules = [rule(atom("answer", a), *eligible)]
    elif name == "witness-local-exclusion":
        rules = [
            rule(atom("answer", a), *eligible, atom("banned_film", f, negative=True))
        ]
    elif name == "anti-existential":
        relations = [{"name": "excluded", "types": ["Actor"]}]
        rules = [
            rule(atom("excluded", a), atom("cast", f, a), atom("banned_film", f)),
            rule(atom("answer", a), *eligible, atom("excluded", a, negative=True)),
        ]
    else:
        relations = [{"name": "reachable", "types": ["Actor", "Actor"]}]
        rules = [
            rule(atom("reachable", a, b), atom("mentor", a, b)),
            rule(
                atom("reachable", a, c), atom("reachable", a, b), atom("mentor", b, c)
            ),
            rule(atom("answer", a), atom("reachable", a, b), atom("target", b)),
        ]
    return {"relations": relations, "rules": rules}


def program(source, contract):
    if set(contract) != {"relations", "rules"}:
        raise ValueError("contract shape")
    names = set(SCHEMA) | {"answer"}
    extra = []
    for r in contract["relations"]:
        if set(r) != {"name", "types"} or r["name"] in names:
            raise ValueError("source/declaration collision")
        names.add(r["name"])
        extra.append(declaration(r["name"], r["types"], False, [], source["domains"]))
    allowed = {r["name"] for r in extra} | {"answer"}
    for r in contract["rules"]:
        if not isinstance(r.get("head"), list) or not r["head"]:
            raise ValueError("head must be nonempty atom array")
        if any(a["relation"] not in allowed for a in r["head"]):
            raise ValueError("source authority")
    sources = [
        declaration(n, SCHEMA[n], True, rows, source["domains"])
        for n, rows in source["rows"].items()
    ]
    return {
        "relations": sources
        + [declaration("answer", ["Actor"], False, [], source["domains"])]
        + extra,
        "rules": contract["rules"],
        "queries": ["answer"],
    }
