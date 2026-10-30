# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Cases for the correction study study."""

import json, random
from ._balanced import balanced
from ._tagged import tagged


def corpus():
    return [
        tagged(2026103301),
        tagged(2026103302, True),
        balanced(2026103303),
        balanced(2026103304, 28, 3),
    ]


def holdout_corpus():
    cases = [
        tagged(2026104301, True),
        balanced(2026104302, 28, 3, 128),
        balanced(2026104303, 32, 3, 128),
        balanced(2026104304, 32, 4, 160),
    ]
    for case in cases:
        rng = random.Random(case["seed"] + 991)
        jobs = [
            r[0]
            for r in next(s for s in case["sources"] if s["name"] == "needs")["rows"]
        ]
        ids = rng.sample(range(1 << 48), len(jobs))
        rename = {job: f"job_{value:012x}" for job, value in zip(jobs, ids)}
        for source in case["sources"]:
            source["rows"] = [
                [rename.get(value, value) for value in row] for row in source["rows"]
            ]
        case["gold"] = [sorted(rename[x] for x in gold) for gold in case["gold"]]
        case["question"] = (
            case["question"].split("\n", 1)[0]
            + "\n"
            + json.dumps(case["program"], separators=(",", ":"))
        )
        case["construction"] = (
            "Satisfiable/unsatisfied candidates are mixed; opaque shuffled job identifiers are independent of class/construction index."
        )
    return cases
