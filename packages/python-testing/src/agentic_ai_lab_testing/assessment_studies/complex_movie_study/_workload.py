# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Workload for the complex movie study study."""

import copy
from ._contracts import atom, const, declaration, program, rule, var, view_contract


def execute(engine, source, contract, views=None):
    with engine.open(program(source, contract, views)) as session:
        result = session.run()
        if not result["complete"]:
            raise RuntimeError("Scheme query incomplete")
        return result["relations"]["answer"]


def materialize(engine, source):
    p = program(source, view_contract())
    p["queries"] = ["eligible", "coactor"]
    with engine.open(p) as session:
        result = session.run()
        if not result["complete"]:
            raise RuntimeError("Scheme views incomplete")
        # Verify retained completed evaluation, without recomputing answers.
        retained = session.run()
        if retained["relations"] != result["relations"]:
            raise RuntimeError("retained view differs")
        return result["relations"]


def gold(case, reuse=False):
    f, d, a, g, e = (var(n) for n in ("f", "d", "a", "g", "e"))
    left = [
        atom("eligible", const(case["country"]), f, d, a),
        atom("omitted_film", f, negative=True),
    ]
    right = [atom("coactor", const(case["anchor"]), g, a)]
    if case.get("rightCountry"):
        right.append(atom("eligible", const(case["rightCountry"]), g, e, a))
    blocked = atom("blocked", a, negative=True)
    if case["scope"] in ("left", "both"):
        left.append(blocked)
    if case["scope"] == "both":
        right.append(blocked)
    rules = [] if reuse else view_contract()["rules"]
    rules += [rule(atom("left", a), *left), rule(atom("right", a), *right)]
    if case["combine"] == "all":
        rules.append(rule(atom("answer", a), atom("left", a), atom("right", a)))
    else:
        rules += [
            rule(atom("answer", a), atom(branch, a)) for branch in ("left", "right")
        ]
    return {
        "relations": [{"name": n, "types": ["Actor"]} for n in ("left", "right")],
        "rules": rules,
    }


def source_for(source, case):
    value = copy.deepcopy(source)
    if case["withdrawal"]:
        value["rows"]["cast"] = [
            r for r in value["rows"]["cast"] if r != case["withdrawal"]
        ]
    return value


def case_program(engine, source, case, contract, views=None):
    # Question bindings are sources; their types remain declared and checked.
    p = program(source, contract, views)
    p["relations"] += [
        declaration(
            "omitted_film", ["Film"], True, [[case["omittedFilm"]]], source["domains"]
        ),
        declaration("blocked", ["Actor"], True, [[case["blocked"]]], source["domains"]),
    ]
    with engine.open(p) as session:
        result = session.run()
        if not result["complete"]:
            raise RuntimeError("Scheme query incomplete")
        return result["relations"]["answer"]


def cases(stratum="shared-actor"):
    values = []
    for combine, scope in [
        ("all", "left"),
        ("any", "left"),
        ("all", "none"),
        ("any", "both"),
        ("all", "both"),
        ("any", "none"),
    ]:
        values.append(
            {
                "name": f"{combine}-{scope}",
                "country": "Q145",
                "anchor": "Q38111",
                "omittedFilm": "Q25188",
                "blocked": "Q38111",
                "combine": combine,
                "scope": scope,
                "withdrawal": None,
            }
        )
    for name, row in [
        ("withdraw-hardy", ["Q18002795", "Q208026"]),
        ("withdraw-inception-caine", ["Q25188", "Q123351"]),
    ]:
        values.append({**values[0], "name": name, "withdrawal": row})
    for c in values:
        op = "同时满足 L 和 R" if c["combine"] == "all" else "满足 L 或 R"
        exclusion = {
            "left": "只在 L 排除莱昂纳多",
            "both": "在 L 和 R 都排除莱昂纳多",
            "none": "不排除任何演员",
        }[c["scope"]]
        c["question"] = (
            f"仅使用冻结事实。L：演员出演某部电影，该电影导演具有英国国籍，且电影不是《盗梦空间》。"
            f"R：演员出演某部电影，该电影的演员列表也包含莱昂纳多。演员可以就是莱昂纳多本人。"
            f"找出{op}的演员；{exclusion}。L 与 R 可以由不同电影支持，必须连接同一演员。"
            f"按演员 QID 去重。事实缺失只表示在本有限提取中不存在。"
        )
        if c["withdrawal"]:
            c["question"] += f"本题使用撤回 cast{c['withdrawal']} 后的快照。"
    if stratum == "shared-actor":
        return values
    if stratum != "country-qualified":
        raise ValueError("unknown query stratum")
    union = {
        **values[1],
        "name": "country-scoped-union",
        "blocked": "Q208026",
        "rightCountry": "Q96",
    }
    join = {
        **union,
        "name": "country-qualified-join",
        "combine": "all",
        "scope": "none",
    }
    withdrawal = {
        **union,
        "name": "country-support-withdrawal",
        "withdrawal": ["Q18002795", "Q208026"],
    }
    result = [union, join, withdrawal]
    for c in result:
        c["question"] = (
            "仅使用冻结事实。L：演员出演某部电影，电影导演具有英国国籍(Q145)，"
            "电影不是《盗梦空间》(Q25188)。R：演员与莱昂纳多(Q38111)出演同一部电影，"
            "且这部共同出演电影的导演具有墨西哥国籍(Q96)。L 和 R 可以使用不同电影，"
            "但必须连接同一演员；R 的共同出演与导演国籍必须由同一部电影支持。"
            + (
                "找出满足 L 或 R 的演员，只在 L 排除 Tom Hardy(Q208026)，R 不排除他。"
                if c["combine"] == "any"
                else "找出同时满足 L 和 R 的演员，不排除任何演员。"
            )
            + "演员可以就是莱昂纳多本人。按演员 QID 去重，事实缺失只表示在本有限提取中不存在。"
        )
        if c["withdrawal"]:
            c["question"] += (
                "本题已撤回 cast(荒野猎人 Q18002795,Tom Hardy Q208026)，其余事实保持不变。"
            )
    return result
