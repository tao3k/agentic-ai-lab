# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Snapshot for the complex movie study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_label

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib
import json
from pathlib import Path
import shutil
from ascent import Engine
from ..movie_study import MAX_OUTPUT_TOKENS
from ..query_contract import output_format
from agentic_ai_lab_runtime.reasoning import rows_equal
from ._config import FIXTURE, ROOT
from ._contracts import encoded, identity
from ._request import request
from ._workload import case_program, cases, gold, materialize, source_for


def prepare(directory, library, stratum="shared-actor", compiler_context="facts"):
    source = json.loads(FIXTURE.read_text())
    directory.mkdir(parents=True, exist_ok=False)
    shutil.copyfile(library, directory / library.name)
    plan = {
        "schema": "ascent.complex-movie-plan.v1",
        "purpose": "multi-hop feasibility pilot, not powered main evaluation",
        "maxCalls": len(cases(stratum)) * 3,
        "stratum": stratum,
        "retries": 0,
        "maxOutputTokens": MAX_OUTPUT_TOKENS,
        "arms": ["direct", "execute", "reuse"],
        "source": source,
        "sourceSha256": identity(source),
        "driverSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "library": library.name,
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
        "cases": cases(stratum),
        "contractSchemaSha256": identity(output_format()),
        "compilerContext": compiler_context,
        "producerHashes": _source_hashes(
            {
                str(_source_label(p, ROOT)): p
                for p in [
                    Path(__file__),
                    Path(__file__).parent.parent / "query_contract.py",
                    Path(__file__).parent.parent / "model_study/__init__.py",
                    Path(__file__).parent.parent / "movie_study/__init__.py",
                    ROOT / "rust/ascent-python/src/api/exports.rs",
                ]
            }
        ),
        "primaryMetrics": [
            "exact answer sets",
            "source withdrawal freshness",
            "total provider usage",
        ],
        "reuseBoundary": "Whole-source identity; exact materialized typed views; conservative full invalidation on change",
        "order": [],
        "gold": {},
        "offline": [],
    }
    with Engine() as engine:
        cache = {}
        for i, case in enumerate(plan["cases"]):
            s = source_for(source, case)
            key = identity(s)
            fresh = materialize(engine, s)
            hit = key in cache
            views = cache.setdefault(key, fresh)
            if views != fresh:
                raise RuntimeError("view cache stale")
            expected = case_program(engine, s, case, gold(case))
            reused = case_program(engine, s, case, gold(case, True), views)
            if not rows_equal(expected, reused):
                raise RuntimeError("materialized substitution differs")
            plan["gold"][case["name"]] = expected
            plan["offline"].append(
                {
                    "case": case["name"],
                    "answers": len(expected),
                    "viewCacheHit": hit,
                    "freshMatchesReused": True,
                    "viewRows": {n: len(r) for n, r in views.items()},
                }
            )
            arms = plan["arms"][i % 3 :] + plan["arms"][: i % 3]
            for arm in arms:
                req = request(
                    s, case, arm, views if arm == "reuse" else None, compiler_context
                )
                name = f"{case['name']}.{arm}.request.json"
                data = encoded(req)
                (directory / name).write_bytes(data)
                plan["order"].append(
                    {
                        "case": case["name"],
                        "arm": arm,
                        "request": name,
                        "sha256": hashlib.sha256(data).hexdigest(),
                    }
                )
            report_text(
                "COMPLEX-OFFLINE",
                case["name"],
                "answers",
                len(expected),
                "cache-hit",
                hit,
                flush=True,
            )
    # Conservative byte-per-token estimate plus full output cap; excludes future trials.
    plan["conservativeScheduledUpperUsd"] = (
        sum(
            (len((directory / x["request"]).read_bytes()) + 1024) * 0.3
            + MAX_OUTPUT_TOKENS * 1.2
            for x in plan["order"]
        )
        / 1e6
    )
    (directory / "plan.json").write_text(
        json.dumps(plan, ensure_ascii=False, indent=2) + "\n"
    )
    report_text(
        "COMPLEX-PREPARED calls",
        plan["maxCalls"],
        "upper-usd",
        plan["conservativeScheduledUpperUsd"],
        flush=True,
    )
