# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Exact local ledger audit and English report for the path interface study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _study_module_file

from agentic_ai_lab_testing.model_study.reporting import report_text
import hashlib
import copy
import json
import shutil
from pathlib import Path
from .interactive_study import balanced_oracle, tagged_oracle, obligation_acceptance
from agentic_ai_lab_runtime.reasoning import expand_feedback


from ._path_consumption_projection import sha, count_thinking, decode_historical


from ._path_consumption_audit import _audit_path_runs


from ._path_consumption_rendering import _render_path_report


def main():
    root = Path.cwd()
    cache = root / ".cache/ascent/path-consumption"
    out = root / ".cache/ascent/research-reports/path-consumption-study"
    out.mkdir(parents=True, exist_ok=True)
    records = {}
    plans = {}
    results = []
    audit = {}
    partial = []
    disagreements = []
    stage_costs = []
    _audit_path_runs(
        root, cache, records, plans, results, audit, partial, disagreements, stage_costs
    )
    if disagreements:
        raise ValueError("incorrect native evidence detected")
    for n, value in [
        ("records", records),
        ("plans", plans),
        ("results", results),
        ("provider-audit", list(audit.values())),
        ("stage-costs", stage_costs),
        ("partial-requests", partial),
    ]:
        (out / (n + ".json")).write_text(json.dumps(value, indent=2) + "\n")
    physical_thinking, baseline_total, fresh_total, retained_total = (
        _render_path_report(out, results, audit, partial, stage_costs)
    )
    questions = [
        "#+title: Independent Complex Questions and Oracle Source",
        "",
        "Gold below is for audit only and is absent from model requests and tool feedback.",
    ]
    for c in {p["case"]["case"]: p["case"] for p in plans.values()}.values():
        questions += [
            "",
            "* " + c["case"],
            "",
            "#+begin_src json",
            json.dumps(c, indent=2),
            "#+end_src",
        ]
    (out / "questions.org").write_text("\n".join(questions) + "\n")
    rounds = [
        "#+title: Every Provider Round and Independent Outcome",
        "",
        "| Run | Round | Stage | Thinking | Input / cached input | Output | Provider seconds | Outcome |",
        "|-----+-------+-------+----------+----------------------+--------+------------------+---------|",
    ]
    visible = ["#+title: Visible Provider Outputs and Final Answer Sets"]
    for name, data in records.items():
        visible += ["", "* " + name]
        for c in data["calls"]:
            verdict = next(
                (v for v in data["verdicts"] if v["providerCall"] == c["id"]), None
            )
            outcome = (
                "correct"
                if verdict and verdict["correct"]
                else "incorrect"
                if verdict
                else "tool checkpoint"
            )
            usage = c.get("usage") or {}
            rounds.append(
                f"| {name} | {c['id']} | {c['stage']} | {count_thinking(c)} | {usage.get('input_tokens')} / {usage.get('input_tokens_details', {}).get('cached_tokens')} | {usage.get('output_tokens')} | {c['seconds']:.3f} | {outcome} |"
            )
            path = cache / name / (c["id"] + "-answer.txt")
            visible += [
                "",
                "** " + c["id"],
                f"Thinking: {count_thinking(c)}; outcome: {outcome}.",
                "",
                "#+begin_example",
                path.read_text()
                if path.exists()
                else "Historical prefix: original response directory retained in plan.",
                "#+end_example",
            ]
    (out / "rounds.org").write_text("\n".join(rounds) + "\n")
    (out / "visible-answers.org").write_text("\n".join(visible) + "\n")
    shutil.copyfile(cache / "encoding-receipt.json", out / "encoding-receipt.json")
    sources = out / "execution-sources"
    sources.mkdir(exist_ok=True)
    for name, source in [
        ("raw-baseline-interaction.py", cache / "baseline-host/ascent/interaction.py"),
        ("column-pilot-interaction.py", cache / "column-pilot-interaction.py"),
        (
            "readable-interaction.rs",
            root / "rust/ascent-python/src/api/evidence_conversation.rs",
        ),
        (
            "study.py",
            root / str(_study_module_file("interactive_study")),
        ),
    ]:
        shutil.copyfile(source, sources / name)
    for p in out.rglob("*.json"):
        p.with_name(p.name + ".license").write_text(
            "SPDX-FileCopyrightText: 2026 tao3k team and Contributors\nSPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later\n"
        )
    report_text(
        json.dumps(
            {
                "runs": len(results),
                "physicalResponses": len(audit),
                "physicalThinking": physical_thinking,
                "partialRequests": len(partial),
                "localChecks": sum(r["independentLocalChecks"] for r in results),
                "baselineThinking": baseline_total,
                "readableFreshThinking": fresh_total,
                "readableRetainedThinking": retained_total,
                "reduction": 100 * (1 - retained_total / baseline_total),
            }
        )
    )


if __name__ == "__main__":
    main()
