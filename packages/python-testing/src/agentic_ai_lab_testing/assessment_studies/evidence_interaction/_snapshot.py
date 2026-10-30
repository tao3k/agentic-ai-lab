# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Snapshot for the evidence interaction study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
from pathlib import Path
import subprocess
from datetime import datetime, timezone
from ._artifacts import save, sha
from ._config import LABEL_TOOL, ROOT, RUBRIC, SOLVER_TOOLS
from ._sources import binding
from ._workload import request_for


def freeze(run):
    if (run / "plan.json").exists():
        raise ValueError("already frozen")
    qualification = json.loads((run / "qualification.json").read_text())
    plan = {
        "frozenAtUtc": datetime.now(timezone.utc).isoformat(),
        "head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "tasks": [x["task"] for x in qualification["tasks"] if x["case"] in (0, 1)],
        "calibration": qualification["tasks"][2]["task"],
        "schedule": [
            (0, "baseline"),
            (0, "facts"),
            (0, "prune"),
            (1, "prune"),
            (1, "facts"),
            (1, "baseline"),
        ],
        "model": "deepseek-flash",
        "reasoningEffort": "low",
        "budget": 65536,
        "maxOutputTokens": 8192,
        "maxCalls": 32,
        "maxConsecutiveFailures": 3,
        "checkpoints": [16384, 32768],
        "tools": SOLVER_TOOLS,
        "nativeBoundaries": "Explicit module-load readiness and each native RPC have separate 20-second deadlines. One consumer/judge process pair is reused within each calibration/solver batch. Earlier combined-load/RPC failures remain archived; no timeout is widened.",
        "solverInstructions": None,
        "annotationRubric": RUBRIC,
        "annotationTool": LABEL_TOOL,
        "annotationOutputCap": 8192,
        "measurementContract": "Fixed one returned solver call per chunk; exact quotes, explicit grounded atoms/premises, literal-ID agreement, independent source truth, identical-premise prior links. All calls, failures, negatives, uncertain and rejected labels retained; no extraction retry. Same-provider extraction is not validated independent cognitive ground truth.",
        "budgetContract": "All provider input + all output, including thinking, cached input and failures. Reasoning tokens are a subset of output. Per-call reservation is serialized UTF8 bytes + 4096 + 128*inputItems, plus 8192 output. Unused reservation remains unused, never savings. Only completed actions ending before common checkpoints contribute to quality/depth.",
        "failureContract": "Known usage retained/charged; no failed action admitted. New call receives same pending branch, at most three consecutive failed calls. Unknown usage stops that phase. No retries or continuation of truncated reasoning. Common controller incumbent survives all failures.",
        "boundary": "Consumer fixture only, outside Library build. Agentic AI Lab revision projection and reverse-dependency plan feed ASCENT retained Session; independent finite proof replay compares its published rows. Each case starts after its predetermined temporal history; this study does not yet test live correction mid-model-dialogue. All arms use native post-choice validation. Baseline has no model-visible Facts or Fact prepruning. Fact-only and pruning share evidence. Two fixed task cases, one run per arm; descriptive only. No general source authentication, MRR integration or causal-mechanism claim.",
        "binding": binding(),
        "qualificationSha256": sha((run / "qualification.json").read_bytes()),
    }
    save(run / "plan.json", plan)
    (run / "plan.sha256").write_text(sha((run / "plan.json").read_bytes()) + "\n")
    # Exact executable study sources are artifacts, not copied active modules.
    producers = run / "producers"
    producers.mkdir()
    for name in plan["binding"]:
        if name.endswith(".py") or name in (
            "t/research/evidence-search.ss",
            "candidate/evidence-store.ss",
        ):
            dest = producers / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes((ROOT / name).read_bytes())
        elif name.startswith("/"):
            dest = producers / "agentic-ai-lab" / Path(name).relative_to(ROOT)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(Path(name).read_bytes())
    preview = run / "payload-review"
    preview.mkdir()
    for entry in qualification["tasks"]:
        for arm, context in zip(("baseline", "facts", "prune"), entry["rootContexts"]):
            save(
                preview / f"case-{entry['case']}-{arm}.json", request_for(plan, context)
            )
    save(
        preview / "manifest.json",
        {
            "destination": "https://api.deepseek.com/responses",
            "data": "Synthetic graph, fixed numerical search task, native Fact/proof nodes. No repository source, user files, business records or credentials in requests.",
            "solverSystemInstructions": False,
            "solverAntiRepetitionPrompt": False,
        },
    )
    report_text("FROZEN", sha((run / "plan.json").read_bytes()), flush=True)
