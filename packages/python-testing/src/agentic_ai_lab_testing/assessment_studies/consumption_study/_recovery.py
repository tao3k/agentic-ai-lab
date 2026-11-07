# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Recovery for the consumption study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory


def legacy_repair(library, output):
    output.mkdir(parents=True, exist_ok=False)
    engine = ReasoningRuntime()
    records = []
    try:
        for index in range(4):
            source = Path(f".cache/ascent/correction/holdout-{index}")
            plan = json.loads((source / "plan.json").read_text())
            case = plan["cases"][0]
            control = next(
                r
                for r in json.loads((source / "records.json").read_text())
                if r["arm"] == "reflection"
            )
            i = next(
                i
                for i, c in enumerate(control["calls"])
                if c["failureKind"] == "semantic"
            )
            prefix = control["calls"][: i + 1]
            start = prefix[-1]["stage"] - 1
            with Trajectory(
                engine, case["case"], identity(case["sources"])
            ) as trajectory:
                for c in prefix:
                    trajectory.model_call(c["callId"], c["round"], c["usage"])
                    trajectory.verify(
                        c["correct"],
                        "original-independent-oracle",
                        scope="subgoal",
                        round=c["round"],
                    )
                with EvidenceChain(
                    engine, case["sources"], trajectory=trajectory
                ) as chain:
                    first = chain.query(case["program"])
                    reference = first["resultReference"]
                    receipts = []
                    for stage in range(start, 2):
                        program = [case["program"], case["secondProgram"]][stage]
                        # Historical tasks already supplied the complete authorized
                        # query; no new model call is needed to rediscover it.
                        receipt = chain.consume(reference, program, program)
                        assert receipt["accepted"]
                        actual = sorted(
                            r[0]
                            for r in chain.answer(receipt["resultReference"], "answer")
                        )
                        assert actual == case["gold"][stage]
                        trajectory.verify(
                            True,
                            "original-independent-oracle",
                            scope="task" if stage == 1 else "subgoal",
                            consumption_reference=receipt["resultReference"],
                        )
                        reference = receipt["resultReference"]
                        receipts.append(receipt)
                    records.append(
                        {
                            "case": case["case"],
                            "source": str(source),
                            "prefix": prefix,
                            "control": control,
                            "receipts": receipts,
                            "newModelCalls": 0,
                            "trajectory": trajectory.close("authorized-query-executed"),
                        }
                    )
        (output / "result.json").write_text(json.dumps(records, indent=2))
        report_text("LEGACY-REPAIR-OK", len(records), "new-model-calls=0", flush=True)
    finally:
        engine.close()
