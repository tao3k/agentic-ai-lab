# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Qualification for the complex movie study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import importlib.util
import copy
import hashlib
import json
from pathlib import Path
import time
from ascent import Engine
from agentic_ai_lab_runtime.reasoning import rows_equal
from ._config import TYPES
from ._contracts import declaration, program, view_contract
from ._workload import case_program, gold, materialize


def qualify(corpus, library, output):
    extension = Path(importlib.util.find_spec("ascent._core").origin).resolve()
    if library.resolve() != extension:
        raise ValueError("qualification requires the installed PyO3 extension")
    observations = json.loads(corpus.read_text())
    checked = 0
    if len(observations) != 3072:
        raise ValueError("finite corpus bound")

    def contract(reuse):
        result = {"relations": [], "rules": [] if reuse else view_contract()["rules"]}
        for mode in range(6):
            c = {
                "combine": "all" if mode // 3 == 0 else "any",
                "scope": ["left", "both", "none"][mode % 3],
                "country": "country",
                "anchor": "a0",
            }
            part = gold(c, True)
            names = {n: f"{n}{mode}" for n in ("left", "right", "answer")}
            result["relations"] += [
                {"name": names[n], "types": ["Actor"]} for n in names
            ]
            for r in part["rules"]:
                for a in r["head"] + r["body"]:
                    a["relation"] = names.get(a["relation"], a["relation"])
                result["rules"].append(r)
        return result

    def make_source(sid):
        bits = sid % 256
        return {
            "domains": {
                "Film": ["f0", "f1"],
                "Actor": ["a0", "a1", "a2"],
                "Director": ["d0", "d1"],
                "Country": ["country"],
            },
            "rows": {
                "cast": [
                    [f"f{f}", f"a{a}"]
                    for f in range(2)
                    for a in range(3)
                    if bits & (1 << (f * 3 + a))
                    and not (sid // 256 == 1 and f == 1 and a == 1)
                ],
                "directed": [["f0", "d0"], ["f1", "d1"]],
                "citizen": [
                    [f"d{f}", "country"] for f in range(2) if bits & (1 << (6 + f))
                ],
                "anchor": [["a0"]],
                "omitted_film": [["f0"]],
                "blocked": [["a0"]],
            },
        }

    def combined(source, reuse, views=None):
        types = {**TYPES, "omitted_film": ["Film"], "blocked": ["Actor"]}
        # program() intentionally frames question sources separately elsewhere.
        base = copy.deepcopy(source)
        base["rows"] = {
            k: v
            for k, v in source["rows"].items()
            if k not in ("omitted_film", "blocked")
        }
        p = program(base, contract(reuse), views)
        p["relations"] += [
            declaration(n, types[n], True, source["rows"][n], source["domains"])
            for n in ("omitted_film", "blocked")
        ]
        p["queries"] = ["eligible", "coactor"] + [f"answer{m}" for m in range(6)]
        return p

    started = time.monotonic()
    with Engine() as engine:
        first = make_source(0)
        with (
            engine.open(combined(first, False)) as fresh,
            engine.open(
                combined(first, True, {"eligible": [], "coactor": []})
            ) as reused,
        ):
            for sid in range(512):
                source = make_source(sid)
                if sid:
                    fresh.replace(source["rows"])
                result = fresh.run()
                if not result["complete"]:
                    raise RuntimeError("fresh incomplete")
                views = {n: result["relations"][n] for n in ("eligible", "coactor")}
                if sid:
                    reused.replace({**source["rows"], **views})
                retained = reused.run()
                if not retained["complete"] or not all(
                    rows_equal(rows, retained["relations"][name])
                    for name, rows in result["relations"].items()
                ):
                    raise RuntimeError(
                        f"retained source/view replacement differs {sid}"
                    )
                for mode in range(6):
                    n = sid * 6 + mode
                    answer = result["relations"][f"answer{mode}"]
                    actual = [
                        n,
                        sum(
                            1 << (int(r[1][-1]) * 3 + int(r[3][-1]))
                            for r in views["eligible"]
                        ),
                        sum(
                            1 << (int(r[1][-1]) * 3 + int(r[2][-1]))
                            for r in views["coactor"]
                        ),
                        sum(1 << int(r[0][-1]) for r in answer),
                    ]
                    if actual != observations[n]:
                        raise RuntimeError(f"Scheme/Quint mismatch {n}: {actual}")
                    checked += 1
                if sid % 8 == 7:
                    report_text("COMPLEX-CORRESPONDENCE", checked, "/3072", flush=True)
        source = make_source(255)
        views = materialize(
            engine,
            {
                **source,
                "rows": {
                    n: r
                    for n, r in source["rows"].items()
                    if n not in ("omitted_film", "blocked")
                },
            },
        )
        c = {
            "country": "country",
            "anchor": "a0",
            "omittedFilm": "f0",
            "blocked": "a0",
            "combine": "any",
            "scope": "left",
        }
        clean = {
            **source,
            "rows": {
                n: r
                for n, r in source["rows"].items()
                if n not in ("omitted_film", "blocked")
            },
        }
        correct = case_program(engine, clean, c, gold(c, True), views)
        wrong = case_program(
            engine,
            clean,
            {**c, "scope": "both"},
            gold({**c, "scope": "both"}, True),
            views,
        )
        if rows_equal(wrong, correct):
            raise RuntimeError("global exclusion mutation survived")
        join = {**c, "combine": "all"}
        correct = case_program(engine, clean, join, gold(join, True), views)
        if rows_equal(case_program(engine, clean, c, gold(c, True), views), correct):
            raise RuntimeError("union mutation survived")
        updated = make_source(511)
        updated["rows"] = {
            n: r
            for n, r in updated["rows"].items()
            if n not in ("omitted_film", "blocked")
        }
        correct = case_program(engine, updated, join, gold(join))
        stale = case_program(engine, updated, join, gold(join, True), views)
        if rows_equal(stale, correct):
            raise RuntimeError("stale materialized views survived")
        report_text(
            "COMPLEX-FAULT-CONTROLS global-exclusion union-for-join stale-views detected=3",
            flush=True,
        )
    output.write_text(
        json.dumps(
            {
                "schema": "ascent.materialized-movie-correspondence.v1",
                "observations": checked,
                "allEqual": True,
                "retainedSessions": 2,
                "sourceSnapshots": 512,
                "faultControlsDetected": [
                    "global-exclusion",
                    "union-for-join",
                    "stale-views",
                ],
                "seconds": time.monotonic() - started,
                "corpusSha256": hashlib.sha256(corpus.read_bytes()).hexdigest(),
                "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
            }
        )
        + "\n"
    )
