# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Snapshot for the factor pilot study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
from agentic_ai_lab_testing.assessment_studies._source_files import _study_module_file
import shutil
from datetime import datetime, timezone
from pathlib import Path
from ._artifacts import save, sha
from ._config import BASE, CASES, INSTRUCTIONS, ROOT, SNAP, TOOLS


def _build_plan():
    """Assemble the retained plan structure."""
    return {
        "frozenAtUtc": datetime.now(timezone.utc).isoformat(),
        "schema": "ascent.factor-reuse-real-pilot.v2",
        "supersedesCensoredPilot": "censored-2048/frozen-plan.json",
        "revisionReason": "All 16 v1 phases exhausted the 2048 per-call output cap entirely in reasoning before any tool action. Preserve v1 separately; raise equal phase allowance to 24576 and per-call cap to 16384 for all arms; same tasks/grader.",
        "model": "deepseek-flash",
        "reasoningEffort": "high",
        "arms": {
            "A": "fresh checked atomic factors",
            "B": "retained cards without independent proof gate",
            "C": "checked retained atomic factors",
            "D": "checked shared closure and derivation DAG",
        },
        "cases": CASES,
        "phaseOutputBudget": 24576,
        "perCallOutputCap": 16384,
        "phaseCallLimit": 6,
        "phaseToolLimit": 24,
        "replicates": 1,
        "order": [
            {"case": c["id"], "arm": a}
            for ci, c in enumerate(CASES)
            for a in (list("ABCD") if ci == 0 else list("DCBA"))
        ],
        "instructions": INSTRUCTIONS,
        "tools": TOOLS,
        "grader": "t/research/factor-pilot.ss direct-edge permutation enumeration; no model grader",
        "hiddenThinkingMeasurement": False,
        "taskScope": "Controlled transfer after history reset, 6 jobs then 7 jobs; precedence sources unchanged; weights/goals change. No full-answer cache.",
        "failurePolicy": "No retries. Retain failed/incomplete calls, invalid schedules, missing usage and censored phases.",
        "buildScope": "Frozen current Scheme production modules excluding applications/domain-evidence, interface/engine-api and interface/c-api after full-build syntax failure. This is not full build qualification.",
        "costPolicy": "All input/output including reasoning charged. Native admission+proof storage+IO recorded. Native cache resets per trajectory. Cold phase included. USD invoice unavailable.",
    }


def freeze():
    plan = _build_plan()
    paths = [
        "t/research/factor-pilot.ss",
        "t/research/factor-pilot-build.ss",
        str(_study_module_file("factor_pilot")),
        str(_study_module_file("model_study")),
        str(_study_module_file("movie_study")),
        "rust/ascent/src/conversation.rs",
    ]
    runtime = Path(shutil.which("gxi")).resolve()
    plan["runtime"] = {"path": str(runtime), "sha256": sha(runtime.read_bytes())}
    plan["qualificationSha256"] = sha((BASE / "qualification.json").read_bytes())
    plan["formalReceipts"] = {
        p: sha((BASE / p).read_bytes())
        for p in (
            "native-retained-correspondence.json",
            "quint-retained-correspondence.json",
            "lean-native-quint-correspondence.log",
            "lean-retained.log",
            "quint-retained.log",
        )
    }
    plan["producerHashes"] = _source_hashes({p: ROOT / p for p in paths})
    # Bind every fresh compiler output and retained dependency byte, not pre-existing ASCENT objects.
    plan["artifactHashes"] = {
        str(p.relative_to(SNAP)): sha(p.read_bytes())
        for p in (SNAP / ".gerbil/lib").rglob("*")
        if p.is_file() and not p.name.endswith(".lock")
    }
    plan["artifactHashes"][".gerbil/bin/factor-pilot"] = sha(
        (SNAP / ".gerbil/bin/factor-pilot").read_bytes()
    )
    plan["scopedBuildHash"] = sha((SNAP / "build.ss").read_bytes())
    plan["sourceManifestHash"] = sha((BASE / "source-manifest.json").read_bytes())
    save(BASE / "frozen-plan.json", plan)
    (BASE / "frozen-plan.sha256").write_text(
        sha((BASE / "frozen-plan.json").read_bytes()) + "\n"
    )
    return plan
