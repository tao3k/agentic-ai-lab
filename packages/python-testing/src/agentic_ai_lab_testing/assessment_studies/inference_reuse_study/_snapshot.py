# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Snapshot for the inference reuse study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_label

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib
import json
import shutil
from pathlib import Path
from ascent import Engine
from ..complex_movie_study import ROOT
from ..movie_study import MAX_OUTPUT_TOKENS
from ._workload import expected, oracle_contract, program, updated, workload


def prepare(directory, library):
    directory.mkdir(parents=True, exist_ok=False)
    frozen_library = directory / library.name
    shutil.copy2(library, frozen_library)
    library = frozen_library
    cases = [workload(i) for i in range(4)]
    with Engine() as engine:
        for case in cases:
            for phase, source in [("cold", case["source"]), ("updated", updated(case))]:
                with engine.open(program(source, oracle_contract(case))) as session:
                    result = session.run()
                    if not result["complete"] or sorted(
                        result["relations"]["answer"]
                    ) != expected(case, source):
                        raise ValueError("independent gold disagreement")
                report_text(
                    "HOLDOUT-ORACLE",
                    case["name"],
                    phase,
                    len(expected(case, source)),
                    flush=True,
                )
    plan = {
        "schema": "ascent.inference-reuse-plan.v1",
        "cases": cases,
        "repetitions": 2,
        "maxProviderCalls": 32,
        "maxOutputTokens": MAX_OUTPUT_TOKENS,
        "upperPeakEstimateUsd": 3.0,
        "scope": "Four synthetic structural holdouts, independently named entities; two repeated cold controls. Not a real-world KGQA benchmark.",
        "repeatBaseline": "Direct model is called again; also report identical-request answer-cache control with zero repeat calls.",
        "reuseKey": "Exact question, schema, contract and engine identity; no natural-language similarity matching.",
        "sourceUpdate": "Retain rules, replace trusted source rows in Scheme; invalidate completed answer. No model call.",
        "recovery": "No repair or retry in primary evaluation. Failed contracts remain failures in all retained phases.",
        "reflectionInputs": {
            str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in [
                ROOT
                / ".cache/ascent/archived-runs/docs/research/agent-inference/movie-reflection-result.json",
                ROOT
                / ".cache/ascent/archived-runs/docs/research/agent-inference/complex-movie-result.json",
            ]
        },
        "reflectionDecisions": [
            "Use structured head arrays.",
            "Union and join explicit in ABI.",
            "Keep existential witness exclusion distinct from actor-wide exclusion.",
            "Compile intent without fact enumeration.",
            "Retain Scheme session; do not call model on exact repeat.",
            "Withdraw sources and check against independent oracle; never return stale answer.",
        ],
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
        "library": library.name,
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
        "priceSource": "https://api-docs.deepseek.com/quick_start/pricing/",
    }
    (directory / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
