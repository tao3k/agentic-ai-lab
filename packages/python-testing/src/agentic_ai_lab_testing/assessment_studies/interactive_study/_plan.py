# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Freeze the interaction contract, exact source closure and original call budgets."

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
import sys
import hashlib
import json
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import EvidenceInteraction
from ._cases import corpus, public


def _prepare_run_plan(
    output,
    seed_offset,
    index,
    arm,
    checkpoint_prefix,
    failed_prefix,
    library,
    resume_prefix,
    producer_source,
):
    """Own the prepare run plan phase and retain its evidence checks."""
    output.mkdir(parents=True, exist_ok=False)
    case = corpus(seed_offset)[index]
    paths = [
        producer_source,
        "rust/ascent-python/src/api/evidence_conversation.rs",
        "rust/ascent-python/src/api/trajectory.rs",
        "rust/ascent/src/derivations.rs",
        "program/trajectory.ss",
        "program/evidence-dag.ss",
    ]
    plan = _build_plan(
        arm, case, checkpoint_prefix, failed_prefix, library, paths, resume_prefix
    )
    (output / "plan.json").write_text(json.dumps(plan, indent=2))
    return plan, case


def _build_plan(
    arm, case, checkpoint_prefix, failed_prefix, library, paths, resume_prefix
):
    """Assemble the retained plan structure."""
    return {
        "schema": "ascent.interactive-study.v1",
        "case": public(case),
        "arm": arm,
        "model": "deepseek-flash",
        "maxOutputTokens": 131072,
        "maxCallsPerStage": 8,
        "maxFinalFailuresPerStage": 3,
        "endpoint": "Entire three-stage task: all calls through first independently correct answer for every stage, including source update and repairs.",
        "sourceHashes": _source_hashes({p: Path(p) for p in paths}),
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
        "strictOutputSchema": False,
        "runtimeInteractionSource": sys.modules[
            EvidenceInteraction.__module__
        ].__file__,
        "runtimeInteractionSha256": hashlib.sha256(
            Path(sys.modules[EvidenceInteraction.__module__].__file__).read_bytes()
        ).hexdigest(),
        "interpretation": "Fresh and retained expose identical domain checks from round one; source-only exposes ground source checks. No model query synthesis.",
        "replayedFirstCallFrom": str(resume_prefix)
        if resume_prefix is not None
        else None,
        "failedPrefixFrom": str(failed_prefix) if failed_prefix is not None else None,
        "checkpointPrefixFrom": str(checkpoint_prefix)
        if checkpoint_prefix is not None
        else None,
    }
