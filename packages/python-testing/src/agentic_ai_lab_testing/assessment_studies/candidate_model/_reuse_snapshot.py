# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Reuse snapshot for the candidate model study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes

from agentic_ai_lab_testing.assessment_studies._source_files import _study_module_file

from agentic_ai_lab_testing.model_study.reporting import report_text
import inspect
import ast
import hashlib
import json
from pathlib import Path
import subprocess
from ._artifacts import digest, save
from ._config import CANONICAL, PREPARED, ROOT, RUNTIME
from ._tasks import study_annotations
from ._judge import judge_selection, optimum, reachable, ready, search_task
from ._transport import Consumer


def _build_plan(annotation, binding, capture, judge_code, reference, run, tasks):
    """Assemble the retained plan structure."""
    return {
        "head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "librarySourceCapture": capture,
        "tasks": tasks,
        "arms": ["baseline", "facts", "scheme"],
        "orders": [["baseline", "facts", "scheme"], ["scheme", "facts", "baseline"]],
        "unchangedTaskPlanSha256": digest(reference),
        "independentJudgeAstSha256": hashlib.sha256(
            json.dumps(
                judge_code(Path(inspect.getsourcefile(judge_selection))), sort_keys=True
            ).encode()
        ).hexdigest(),
        "model": "deepseek-flash",
        "budget": 65536,
        "outputCap": 65536,
        "minimumOutputCap": 1024,
        "inputReservationPadding": 256,
        "maxCalls": 24,
        "checkpoints": [8192, 16384, 24576, 32768, 49152, 65536],
        "interaction": "Stateless Responses dialogue: replay every returned reasoning/message/function_call item. Pair actual function calls with function_call_output; return observed extension-result data after a strict JSON action message. Request each next extension with the SAME ordinary question as the first turn. API text.format uses exactly the existing expand argument JSON Schema; no user/system instruction is added. Exactly one object with integer parentId/optionId is required in either encoding, followed by unchanged availability and independent semantic checks. No fabricated tool call, repair, fenced-text salvage or retry of incomplete responses. Per-call output is limited only by remaining total budget minus input reservation. Initial input is bounded by serialized request bytes plus 256 framing padding; continuations reserve previous billed input plus output and ALL newly added result/question item bytes plus padding. Observed input must not exceed reservation. All input and output tokens, including cached input and thinking, are charged. Insufficient reservation is censored, not savings.",
        "binding": binding,
        "qualificationSha256": digest(run / "qualification.json"),
        "annotationRubric": annotation.RUBRIC,
        "annotationTool": annotation.LABEL_TOOL,
        "annotationCap": 8192,
        "annotationRules": "Use exact quoted thinking, independently true source atoms and explicitly supported edge chains/conjunctions. Mark repeated qualified conclusions within the same immutable source, and separately identical ordered-premise repeats. Different parent paths do not reset prior derivations. Resource/value recalculation, mentions, reuse and uncertainty are excluded. Missing labels are unknown, never zero. No completeness or inter-rater agreement claim.",
        "protocol": "Each arm starts with the same strictly nonoptimal feasible seed and one empty search prefix. Every call chooses one parentId/optionId extension from the supplied frontier. Invalid branches consume cost and are retained. Baseline receives raw task data; facts adds the same relevant verified Fact outcomes used by scheme; scheme adds ancestor-closed proof fragments and Library finite-absence partition. No branch ranking is performed by Scheme. The host independently grades prefixes and complete selections. Unused reservations and call-limit stops are censored, not savings. Compare only jointly reached input-plus-all-output checkpoints. Labeling costs are separate measurement costs.",
        "tool": {
            "type": "function",
            "name": "expand",
            "description": "Expand one available child from the frontier.",
            "parameters": {
                "type": "object",
                "properties": {
                    "parentId": {"type": "integer"},
                    "optionId": {"type": "integer"},
                },
                "required": ["parentId", "optionId"],
                "additionalProperties": False,
            },
        },
    }


def _check_frozen_producers(annotation, tasks):
    """Own the check frozen producers phase without weakening its checks."""
    reference = (
        ROOT
        / ".cache/ascent/archived-runs/docs/research/agent-inference/fact-reuse-results/plan.json"
    )
    prior = json.loads(reference.read_text())
    assert (
        tasks == prior["tasks"]
        and annotation.RUBRIC == prior["annotationRubric"]
        and annotation.LABEL_TOOL == prior["annotationTool"]
    ), "frozen task or annotation rule changed"
    original = (
        ROOT
        / ".cache/ascent/candidate-interaction/reuse-study/producers/tools/research/candidate-model.py"
    )

    def judge_code(path):
        return {
            node.name: ast.dump(node, include_attributes=False)
            for node in ast.parse(path.read_text()).body
            if isinstance(node, ast.FunctionDef)
            and node.name
            in ("reachable", "ready", "search_task", "judge_selection", "optimum")
        }

    assert judge_code(Path(inspect.getsourcefile(judge_selection))) == judge_code(
        original
    ), "independent selection judge changed"
    store_test = (
        ROOT
        / ".cache/ascent/candidate-interaction/latest-proof-frame-qualification/evidence-store-test.json"
    )
    assert json.loads(store_test.read_text())["passed"]
    modules = json.loads((RUNTIME / "closure.json").read_text())["modules"]
    assert not any("agentic-ai-lab/" in m for m in modules), (
        "workflow dependency in consumer"
    )
    linked = {
        Path(p).name
        for p in json.loads((RUNTIME / "native-object-sources.json").read_text())
    }
    for module in modules:
        name = module.replace("/", "__") + ".c"
        for static in (CANONICAL / "static", PREPARED / "static"):
            assert not (static / name).exists() or name in linked, (
                "unlinked runtime module " + module
            )
    capture = json.loads((RUNTIME / "source-capture.json").read_text())
    for name, h in capture["sourceSha256"].items():
        assert digest(ROOT / name) == h == digest(RUNTIME / "current-source" / name), (
            "source capture drift " + name
        )
    return reference, original, judge_code, store_test, modules, capture


def _qualify_tasks(run, tasks):
    """Own the qualify tasks phase without weakening its checks."""
    checks = []
    for i, t in enumerate(tasks):
        seed = judge_selection(t, t["seed"], True)
        best = optimum(t)
        assert seed["valid"] and seed["value"] < best["evaluation"]["value"]
        d = run / f"qualify-{i}"
        d.mkdir()
        native = Consumer(d)
        try:
            init = native.call(
                op="reuse-init", identity=t["id"], edges=t["edges"], needs=t["needs"]
            )
            assert {x[0] for x in init["rows"]} == {
                n[0] for n in t["needs"] if ready(t, n[0])
            }
            packets = [
                native.call(op="reuse-packet", fragments=list(range(12)))
                for _ in range(2)
            ]
            assert (
                packets[0]["facts"] == packets[1]["facts"]
                and packets[0]["nodes"] == packets[1]["nodes"]
            )
            assert all(p["reused"] for p in packets)
            for p in packets:
                stats = dict(p["stats"])
                assert stats["proof-builds"] == 1 and stats["hits"] >= 1
                for fact in p["facts"]:
                    a = fact["atom"]
                    truth = (
                        ready(t, a[1])
                        if a[0] == "ready"
                        else reachable(t["edges"], *a[1:])
                    )
                    assert fact["present"] == truth
                assert set(p["allowed"]) == {n[0] for n in t["needs"] if ready(t, n[0])}
                ids = {n[0] for n in p["nodes"]}
                assert all(x in ids for n in p["nodes"] for x in n[5])
            assert native.call(
                op="reuse-episode",
                atom=["path", 0, 7],
                premises=[
                    ["edge", 0, 2],
                    ["edge", 2, 4],
                    ["edge", 4, 6],
                    ["edge", 6, 7],
                ],
            )["supportQualified"]
            assert not native.call(
                op="reuse-episode", atom=["path", 0, 7], premises=[]
            )["supportQualified"]
            assert not native.call(
                op="reuse-episode", atom=["path", 0, 7], premises=[["edge", 1, 3]]
            )["supportQualified"]
        finally:
            shutdown = native.close()
        assert shutdown["clean"]
        checks.append(
            {
                "case": i,
                "seed": seed,
                "optimum": best,
                "packet": packets[0],
                "shutdown": shutdown,
            }
        )
    return checks


def reuse_freeze(run):
    run.mkdir(parents=True, exist_ok=False)
    annotation = study_annotations()
    tasks = [search_task(i) for i in range(2)]
    reference, original, judge_code, store_test, modules, capture = (
        _check_frozen_producers(annotation, tasks)
    )
    checks = _qualify_tasks(run, tasks)
    shutdown_dir = (
        ROOT / ".cache/ascent/candidate-interaction/latest-proof-frame-qualification"
    )
    startup = json.loads((shutdown_dir / "receipt.json").read_text())
    assert len(startup) == 9 and all(
        x["passed"] and x["shutdown"]["clean"] for x in startup
    )
    clean = {
        "allClean": True,
        "checks": startup,
        "scope": "Native, dynamic evidence module and full gxi, three starts each; current captured proof-frame.",
    }
    sources = [
        _study_module_file("candidate_model"),
        ROOT / "t/research/candidate-interaction.ss",
        _study_module_file("evidence_interaction"),
        _study_module_file("model_study"),
        _study_module_file("movie_study"),
    ]
    sources += [
        store_test,
        ROOT / "candidate/evidence-store.ss",
        ROOT / "t/qualification/ascent-evidence-store-test.ss",
        shutdown_dir / "receipt.json",
    ]
    sources += [
        ROOT / "t/research/test_candidate_transport.py",
        shutdown_dir / "rules/receipt.json",
        shutdown_dir / "test-receipt.json",
    ]
    dialogue = ROOT / ".cache/ascent/candidate-interaction/dialogue-qualification"
    dialogue_receipts = json.loads((dialogue / "receipt.json").read_text())
    assert len(dialogue_receipts) == 2 and all(
        x["status"] == "completed" and not x["failure"] for x in dialogue_receipts
    )
    sources += [reference, original, dialogue / "plan.json", dialogue / "receipt.json"]
    turns = (
        ROOT
        / ".cache/ascent/candidate-interaction/structured-branch-turn-qualification"
    )
    turn_receipts = json.loads((turns / "receipt.json").read_text())
    assert len(turn_receipts) == 2 and all(
        x["status"] == "completed"
        and not x["failure"]
        and x["action"] == {"parentId": i, "optionId": i}
        for i, x in enumerate(turn_receipts)
    )
    sources += [turns / "plan.json", turns / "receipt.json"]
    sources += [
        p
        for d in [RUNTIME, CANONICAL.parent]
        for p in d.rglob("*")
        if p.is_file() and not p.name.endswith(".lock")
    ]
    binding = _source_hashes({str(p): p for p in sources})
    save(run / "qualification.json", {"tasks": checks, "shutdown": clean})
    plan = _build_plan(annotation, binding, capture, judge_code, reference, run, tasks)
    save(run / "plan.json", plan)
    (run / "plan.sha256").write_text(digest(run / "plan.json") + "\n")
    for p in sources[:12]:
        d = run / "producers" / p.relative_to(ROOT)
        d.parent.mkdir(parents=True, exist_ok=True)
        d.write_bytes(p.read_bytes())
    report_text("REUSE_FROZEN", digest(run / "plan.json"), flush=True)


def reuse_verify(run):
    plan = json.loads((run / "plan.json").read_text())
    assert digest(run / "plan.json") == (run / "plan.sha256").read_text().strip()
    assert digest(run / "qualification.json") == plan["qualificationSha256"]
    for p, h in plan["binding"].items():
        assert digest(Path(p)) == h, "producer drift " + p
    return plan
