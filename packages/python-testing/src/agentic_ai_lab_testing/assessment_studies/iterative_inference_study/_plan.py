# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Plan for the iterative inference study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import (
    _source_label,
    _study_module_file,
)
from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib
import json
import shutil
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from .. import inference_reuse_study as study
from .. import complex_inference_workload as complex_workload
from ..movie_study import MAX_OUTPUT_TOKENS


def _build_plan(library, paths):
    """Assemble the retained plan structure."""
    return {
        "schema": "ascent.iterative-inference-plan.v2",
        "maxTurns": 8,
        "maxProviderCalls": 128,
        "maxOutputTokens": MAX_OUTPUT_TOKENS,
        "conservativePeakCeilingUsd": 12,
        "library": library.name,
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
        "cases": [complex_workload.workload(i, 20261010 + i * 101) for i in range(4)],
        "repetitions": 2,
        "arms": ["raw-fact-reasoning", "scheme-evidence"],
        "scope": "Frozen synthetic compound tasks with opaque entities; two trials per task. Newly designed evaluation, not an independently annotated real-world benchmark.",
        "primaryMetric": "First independently verified answer: model turns and cumulative input/output/reasoning tokens, including scans, queries, failed answers and correction. Unsatisfied episodes are censored.",
        "sourceBoundary": "Both arms can scan identical raw facts. Assisted reasoning may submit executable claims for Scheme checking and retention at any round; no mandatory subproblem decomposition or forced evidence-first action. Untreated assisted episodes remain in the assigned-arm denominator.",
        "mechanism": "The model reasons about the complete complex question. Scheme checks and retains externally expressed claims against admitted facts and rules. Source-bound evidence supports subsequent thinking; hidden model thoughts are neither read nor certified.",
        "verificationFeedback": "Only verified or not_verified; no gold answers or missing-actor list.",
        "producerHashes": _source_hashes(
            {str(_source_label(p, study.ROOT)): p for p in paths}
        ),
    }


def prepare(directory, library):
    directory.mkdir(parents=True, exist_ok=False)
    shutil.copy2(library, directory / library.name)
    paths = [
        Path(__file__),
        Path(study.__file__),
        _study_module_file("inference_effort"),
        Path(complex_workload.__file__),
        _study_module_file("model_study"),
        _study_module_file("movie_study"),
        _study_module_file("query_contract"),
        study.ROOT / "rust/ascent-python/src/api/evidence.rs",
        study.ROOT / "rust/ascent-python/src/api/exports.rs",
    ]
    plan = _build_plan(library, paths)
    with ReasoningRuntime(directory / library.name) as engine:
        for case in plan["cases"]:
            for source in (case["source"], study.updated(case)):
                with engine.open(
                    study.program(source, complex_workload.oracle_contract(case))
                ) as session:
                    result = session.run()
                    if not result["complete"] or sorted(
                        result["relations"]["answer"]
                    ) != complex_workload.expected(case, source):
                        raise ValueError("compound-task oracle disagreement")
            report_text(
                "COMPLEX-ORACLE",
                case["name"],
                len(complex_workload.expected(case, case["source"])),
                flush=True,
            )
    (directory / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
