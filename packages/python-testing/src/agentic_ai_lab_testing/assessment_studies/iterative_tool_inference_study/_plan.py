# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Plan for the iterative tool inference study study."""

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
from .. import iterative_inference_study as loop
from .. import inference_reuse_study as study
from .. import complex_inference_workload as workload


def prepare(original, directory):
    plan = json.loads((original / "plan.json").read_text())
    directory.mkdir(parents=True, exist_ok=False)
    shutil.copy2(original / plan["library"], directory / plan["library"])
    if (
        hashlib.sha256((directory / plan["library"]).read_bytes()).hexdigest()
        != plan["librarySha256"]
    ):
        raise ValueError("engine identity")
    paths = [
        Path(__file__),
        Path(loop.__file__),
        Path(study.__file__),
        Path(workload.__file__),
        _study_module_file("inference_effort"),
        _study_module_file("model_study"),
        _study_module_file("movie_study"),
        _study_module_file("query_contract"),
        _study_module_file("complex_movie_study"),
        study.ROOT / "rust/ascent/src/conversation.rs",
        study.ROOT / "rust/ascent-python/src/api/evidence.rs",
        study.ROOT / "rust/ascent-python/src/api/exports.rs",
    ]
    plan.update(
        schema="ascent.tool-thinking-plan.v1",
        maxOutputTokens=131072,
        workers=2,
        scope="Corrected tool-history development evaluation on the same frozen compound questions; follows diagnosis of the original protocol. Not a new independent holdout.",
        conservativePeakCeilingUsd=24,
        originalPlanSha256=hashlib.sha256(
            (original / "plan.json").read_bytes()
        ).hexdigest(),
        historyPolicy="Both arms retain complete provider reasoning/message/function_call items and matched function_call_output items. Never use unsupported server conversation ids.",
        sourceBoundary="Identical raw-fact scan and binary verifier. Additional Scheme evidence checking is available in the assisted arm. No forced subproblem or forced first query. No gold values in prompts.",
        scheduling="At most two spawned worker processes; one active provider call per process, one retained runtime per process, fresh evidence store per trajectory. Pair order counterbalanced.",
        producerHashes=_source_hashes(
            {str(_source_label(p, study.ROOT)): p for p in paths}
        ),
    )
    (directory / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    report_text(
        "TOOL-THINKING-PREPARED",
        "trajectories",
        16,
        "workers",
        2,
        "maxCalls",
        128,
        flush=True,
    )
