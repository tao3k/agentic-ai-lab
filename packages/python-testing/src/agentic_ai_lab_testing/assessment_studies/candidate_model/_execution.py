# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the candidate model study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import tarfile
from agentic_ai_lab_testing.assessment_studies.model_study import provider
from agentic_ai_lab_testing.assessment_studies.movie_study import provider_key
from ._artifacts import digest, save
from ._config import CANONICAL, ROOT, RUNTIME
from ._snapshot import verify
from ._tasks import request
from ._transport import Consumer


def call_model(folder, context, previous_cost=0):
    folder.mkdir(parents=True, exist_ok=False)
    req = request(context)
    save(folder / "request.json", req)
    reservation = len(json.dumps(req).encode()) + 4096 + 8192
    if previous_cost + reservation > 32768:
        return {"failure": "budget_reservation", "rules": None, "grossTokens": 0}
    _, meta = provider(req, provider_key(), folder / "response.json")
    term = meta.get("terminal") or {}
    thinking = "\n".join(
        p.get("text", "")
        for x in term.get("output", [])
        if x.get("type") == "reasoning"
        for p in x.get("content", [])
        if p.get("type") == "reasoning_text"
    )
    (folder / "thinking.txt").write_text(thinking)
    result = {
        "status": term.get("status"),
        "usage": term.get("usage"),
        "failure": None,
        "rules": None,
        "grossTokens": None,
    }
    try:
        u = result["usage"]
        if not isinstance(u, dict) or any(
            type(u.get(k)) is not int or u[k] < 0
            for k in ("input_tokens", "output_tokens")
        ):
            raise ValueError("unknown_usage")
        result["grossTokens"] = u["input_tokens"] + u["output_tokens"]
        if previous_cost + result["grossTokens"] > 32768 or u["output_tokens"] > 8192:
            raise ValueError("budget_violation")
        if meta.get("error") or term.get("status") != "completed":
            raise ValueError("incomplete_provider")
        actions = [
            x for x in term.get("output", []) if x.get("type") == "function_call"
        ]
        if len(actions) != 1 or actions[0].get("name") != "submit_rules":
            raise ValueError("expected_one_submission")
        args = json.loads(actions[0]["arguments"])
        if (
            set(args) != {"rules"}
            or not isinstance(args["rules"], list)
            or not 1 <= len(args["rules"]) <= 4
        ):
            raise ValueError("invalid_submission")
        result["rules"] = args["rules"]
    except (ValueError, KeyError, TypeError) as error:
        result["failure"] = str(error)
    save(folder / "receipt.json", result)
    return result


def solve(run):
    plan = json.loads((run / "plan.json").read_text())
    verify(run, plan)
    if plan.get("nativeQualified") is not True:
        raise ValueError("native qualification denied; model calls prohibited")
    if (run / "ledger.json").exists():
        raise ValueError("already run; retain results")
    native = Consumer(run)
    rows = []
    try:
        for t in plan["tasks"]:
            i = t["case"]
            row = {
                "case": i,
                "initial": {
                    "failure": "not_completed",
                    "rules": None,
                    "grossTokens": None,
                },
                "revisions": [],
            }
            rows.append(row)
            save(run / "ledger.json", rows)
            initial = call_model(run / "calls" / f"{i}-initial", t)
            row["initial"] = initial
            save(run / "ledger.json", rows)
            if initial["rules"] is not None:
                dev = native.call(op="feedback", case=i, rules=initial["rules"])
                row["development"] = dev
                # Repair is decided by visible data, before any hidden assessment.
                if any(x["status"] != "match" for x in dev):
                    for arm in ("baseline", "feedback"):
                        context = {**t, "candidateRules": initial["rules"]}
                        if arm == "feedback":
                            context["executionFeedback"] = dev
                        revision = call_model(
                            run / "calls" / f"{i}-{arm}",
                            context,
                            initial["grossTokens"],
                        )
                        revised = {"arm": arm, "call": revision}
                        row["revisions"].append(revised)
                        save(run / "ledger.json", rows)
                        revised["grade"] = (
                            native.call(op="grade", case=i, rules=revision["rules"])
                            if revision["rules"] is not None
                            else None
                        )
                row["grade"] = native.call(op="grade", case=i, rules=initial["rules"])
            save(run / "ledger.json", rows)
            report_text(
                "TASK_DONE",
                i,
                "failure",
                initial["failure"],
                "paired",
                len(row["revisions"]),
                flush=True,
            )
    except Exception as error:
        row["interactionFailure"] = str(error)
        save(run / "ledger.json", rows)
        save(
            run / "failure.json",
            {
                "case": row["case"],
                "error": str(error),
                "remainingTasks": "not run",
                "retry": False,
            },
        )
        report_text("INTERACTION_STOPPED", row["case"], str(error), flush=True)
    finally:
        native.close()
    verify(run, plan)
    save(
        run / "integrity.json",
        {
            "bindingVerified": True,
            "files": {
                str(p.relative_to(run)): digest(p)
                for p in sorted(run.rglob("*"))
                if p.is_file() and p.name != "integrity.json"
            },
        },
    )
    doc = (
        ROOT / ".cache/ascent/research-reports/agent-inference/candidate-model-results"
    )
    doc.mkdir(parents=True, exist_ok=True)
    for name in ["plan.json", "qualification.json", "ledger.json", "integrity.json"]:
        (doc / name).write_bytes((run / name).read_bytes())
    lines = [
        "# Finite Library candidate-feedback model gate",
        "",
        plan["limits"],
        "",
        "| Task | Initial held-out matches / evaluated | Complete native attempts | Paired revisions |",
        "|---|---:|---:|---:|",
    ]
    for r in rows:
        grade = r.get("grade")
        matches = (
            f"{sum(x['status'] == 'match' for x in grade)} / {len(grade)}"
            if grade is not None
            else "not evaluated"
        )
        complete = (
            sum(x["nativeStatus"] == "complete" for x in grade)
            if grade is not None
            else "not evaluated"
        )
        lines.append(
            f"| {r['case']} | {matches} | {complete} | {len(r['revisions'])} |"
        )
    for r in rows:
        if r["initial"]["failure"] or r.get("interactionFailure"):
            lines.append(
                f"\nTask {r['case']} failure: {r.get('interactionFailure') or r['initial']['failure']}.\n"
            )
    calls = [r["initial"] for r in rows] + [
        x["call"] for r in rows for x in r["revisions"]
    ]
    lines += [
        "",
        f"Known physical input + all-output tokens: {sum(c['grossTokens'] or 0 for c in calls)}; unknown-cost calls: {sum(c['grossTokens'] is None for c in calls)}. Unused budget is not savings.",
        "",
        "Full row differences, rejection/exhaustion, raw provider events, thinking and failures are retained. Only the initial proposal or one frozen development-driven revision is evaluated. No repeated-thinking reduction or search-depth benefit is claimed.",
    ]
    (doc / "report.md").write_text("\n".join(lines) + "\n")
    with tarfile.open(doc / "raw.tar.gz", "w:gz") as tar:
        tar.add(run, arcname="run")
        tar.add(RUNTIME, arcname="runtime")
        if CANONICAL.exists():
            tar.add(CANONICAL.parent, arcname="canonical-runtime")
        if (run.parent / "canonical-source").exists():
            tar.add(run.parent / "canonical-source", arcname="canonical-source")
        for failure in sorted(run.parent.glob("failed-*")):
            if failure.is_dir():
                tar.add(failure, arcname=failure.name)
        for log in run.parent.glob("*.log"):
            tar.add(log, arcname="logs/" + log.name)
        for receipt in run.parent.glob("*.json"):
            tar.add(receipt, arcname="receipts/" + receipt.name)
    save(
        doc / "archive.json",
        {
            "sha256": digest(doc / "raw.tar.gz"),
            "bytes": (doc / "raw.tar.gz").stat().st_size,
        },
    )
    report_text("COMPLETE", len(rows), flush=True)
