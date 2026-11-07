# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Snapshot for the factor budget study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes

from agentic_ai_lab_testing.assessment_studies._source_files import _study_module_file

from agentic_ai_lab_testing.model_study.reporting import report_text
import subprocess
from datetime import datetime, timezone
from ._artifacts import canonical, save, sha
from ._config import BASE, INSTRUCTIONS, ROOT, SNAP, TOOLS
from ._tasks import CALIBRATION, CASES, packet, question, task
from ._transport import SchemeEngine


def qualify():
    native = SchemeEngine()
    checks = []
    try:
        for seed in range(10):
            c = task(seed, 7, "small")
            ds = c["durations"]
            ws = c["weights"][1]
            native.call(
                op="init",
                arm="A",
                edges=c["edges"],
                identity=c["id"],
                penalties=c["transitionPenalties"],
            )
            gold, _ = native.call(op="grade", durations=ds, weights=ws, order=[])
            brute, _ = native.call(op="brute", durations=ds, weights=ws)
            assert (
                gold["oracle"]["optimum"] == brute["optimum"]
                and gold["oracle"]["feasibleOrders"] == brute["feasibleOrders"]
            )
            checks.append({"seed": seed, "oracle": gold["oracle"], "exhaustive": brute})
        native.call(op="init", arm="A", edges=[], identity="hand-control")
        hand, _ = native.call(
            op="grade", durations=[1, 2, 3], weights=[3, 2, 1], order=[0, 1, 2]
        )
        assert hand["optimal"] and hand["oracle"]["optimum"] == 15
        native.call(
            op="init",
            arm="A",
            edges=[],
            identity="transition-hand",
            penalties=[[0, 2, 2], [3, 0, 2], [3, 3, 0]],
        )
        transition_hand, _ = native.call(
            op="grade", durations=[1, 2, 3], weights=[3, 2, 1], order=[0, 1, 2]
        )
        assert transition_hand["optimal"] and transition_hand["oracle"]["optimum"] == 19
        comparisons = []
        for c in CASES + CALIBRATION:
            packets = []
            answers = []
            for arm in ("A", "D"):
                native.call(
                    op="init",
                    arm=arm,
                    edges=c["edges"],
                    identity=c["id"],
                    penalties=c["transitionPenalties"],
                )
                a, ar = packet(native, BASE / "qualification-proofs")
                b, br = packet(native, BASE / "qualification-proofs")
                assert (
                    a == b and ar["reused"] == False and (br["reused"] == (arm == "D"))
                )
                packets.append(a)
                answers.append(
                    [
                        native.call(op="factor", u=u, v=v)[0]["precedes"]
                        for u, v in [
                            (0, c["n"] - 1),
                            (c["n"] - 1, 0),
                            (0, 0),
                            (c["n"] // 2, c["n"] - 2),
                        ]
                    ]
                )
                for phase in range(2):
                    n = c["n"]
                    g, _ = native.call(
                        op="grade",
                        durations=c["durations"][:n],
                        weights=c["weights"][phase],
                        order=[],
                    )
                    order = g["oracle"]["optimalOrder"]
                    v, _ = native.call(
                        op="grade",
                        durations=c["durations"][:n],
                        weights=c["weights"][phase],
                        order=order,
                    )
                    assert v["optimal"]
                    bad, _ = native.call(
                        op="evaluate",
                        durations=c["durations"][:n],
                        weights=c["weights"][phase],
                        order=order[:-1] + [order[0]],
                    )
                    assert not bad["valid"]
            assert packets[0] == packets[1] and answers[0] == answers[1]
            for phase in range(2):
                assert question(c, phase, packets[0]) == question(c, phase, packets[1])
            comparisons.append(
                {
                    "task": c["id"],
                    "packetSha256": sha(canonical(packets[0]).encode()),
                    "packetBytes": len(canonical(packets[0]).encode()),
                    "matched": True,
                }
            )
        save(
            BASE / "qualification.json",
            {
                "passed": True,
                "hand": hand,
                "transitionHand": transition_hand,
                "dpVersusBrute": checks,
                "matchedPackets": comparisons,
            },
        )
        report_text("FACTOR-BUDGET-QUALIFICATION-OK", flush=True)
    finally:
        native.close()


def freeze():
    sources = [
        "t/research/factor-budget.ss",
        "t/research/factor-budget-oracle.ss",
        "t/research/factor-budget-build.ss",
        str(_study_module_file("factor_budget")),
        str(_study_module_file("model_study")),
        str(_study_module_file("movie_study")),
        "rust/ascent/src/conversation.rs",
    ]
    artifacts = {
        str(p.relative_to(SNAP)): sha(p.read_bytes())
        for p in (SNAP / ".gerbil/lib").rglob("*")
        if p.is_file() and (not p.name.endswith(".lock"))
    }
    artifacts[".gerbil/bin/factor-budget"] = sha(
        (SNAP / ".gerbil/bin/factor-budget").read_bytes()
    )
    plan = {
        "schema": "ascent.factor-total-budget.v4",
        "frozenAtUtc": datetime.now(timezone.utc).isoformat(),
        "headAtFreeze": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True
        ).strip(),
        "cases": CASES,
        "calibrationCases": CALIBRATION,
        "arms": {"fresh": "A", "retained": "D"},
        "order": [
            {"case": c["id"], "arm": a}
            for i, c in enumerate(CASES)
            for a in (["fresh", "retained"] if i == 0 else ["retained", "fresh"])
        ],
        "totalTokenBudget": 98304,
        "perCallOutputCap": 32768,
        "calls": 3,
        "toolActions": 32,
        "model": "deepseek-flash",
        "reasoningEffort": "high",
        "instructions": INSTRUCTIONS,
        "tools": TOOLS,
        "producerHashes": _source_hashes({p: ROOT / p for p in sources}),
        "artifactHashes": artifacts,
        "qualificationSha256": sha((BASE / "qualification.json").read_bytes()),
        "currentCandidateSourceHashes": {
            str(p.relative_to(SNAP)): sha(p.read_bytes())
            for p in (SNAP / "candidate").glob("*.ss")
        },
        "inheritedKernelManifestSha256": sha(
            (ROOT / ".cache/ascent/factor-pilot/source-manifest.json").read_bytes()
        ),
        "buildScope": "New native bridge and independent subset-plus-last DP grader; inherited frozen pilot production kernel/dependencies. Candidate source files match current checkout. Not a whole-checkout rebuild.",
        "reservation": "Before each paid call, reserve compact request UTF-8 bytes plus 4096 plus 128 per input item as an empirical conservative input allowance. This is not an exact tokenizer. Provider usage is authoritative. Stop and retain reservation violations or any total-budget overshoot as protocol failures, never successful budget-matched results.",
        "hardnessGate": "Separate disjoint full-size calibration phases; at least one valid non-optimal best-observed calibration candidate under known gross-token budget required; censored refinement and missing submission remain failures before confirmatory run. No task selection using confirmatory outcomes.",
        "measurement": "Repeated tool fact requests, duplicate prefixes/candidates, prefix depth and branching, independently graded objective gaps; reasoning token counts. Hidden semantic thinking repetition is not measured.",
        "causalBoundary": "Same model-visible initial packets and deterministic answers; cache flags/timings remain private. Cache-only state cannot directly cause different token allocation under identical observations. Small stochastic differences are descriptive.",
        "finalReasoningEffort": "none",
        "finalizePolicy": "After at most two high-reasoning construction/refinement calls, final non-thinking submit receives the best independently evaluated candidate; no hidden oracle information.",
        "qualityEndpoint": "Any-time best verified candidate when no final submission; missing submission and censored optimization remain failures. No candidate is counted as a successful task solely because its grade is valid.",
        "calibrationSourcePlan": "calibration/frozen-source-plan.json",
        "supersedes": "calibration/frozen-source-plan.json",
        "revisionReason": "Transition calibration produced valid non-optimal candidates with gaps 206 and 397, but censored refinement before submission. Before any confirmatory outcome, select any-time candidate quality and separate completion/censoring as endpoints. Relax only the hardness admission rule to accept valid non-optimal best-observed candidates with known in-budget usage; do not reclassify any calibration failure as success. Model requests, task definitions, independent grader, artifact bytes, input reservation and inference/finalization policy remain identical to v3. Preserve the original stricter calibration plan and controller separately.",
        "failurePolicy": "No retries; retain raw requests, SSE, usage unknowns, native/tool errors, incomplete responses and all final grades.",
    }
    save(BASE / "frozen-plan.json", plan)
    (BASE / "frozen-plan.sha256").write_text(
        sha((BASE / "frozen-plan.json").read_bytes()) + "\n"
    )
    report_text("FROZEN", len(artifacts), flush=True)


def verify(plan):
    assert (
        sha((BASE / "frozen-plan.json").read_bytes())
        == (BASE / "frozen-plan.sha256").read_text().strip()
    )
    assert (
        sha((BASE / "qualification.json").read_bytes()) == plan["qualificationSha256"]
    )
    for p, h in plan["currentCandidateSourceHashes"].items():
        assert sha((ROOT / p).read_bytes()) == h, p
    for p, h in plan["producerHashes"].items():
        assert sha((ROOT / p).read_bytes()) == h, p
    for p, h in plan["artifactHashes"].items():
        assert sha((SNAP / p).read_bytes()) == h, p
    for p in (
        "t/research/factor-budget.ss",
        "t/research/factor-budget-oracle.ss",
        "t/research/factor-budget-build.ss",
    ):
        assert sha((SNAP / p).read_bytes()) == plan["producerHashes"][p]
