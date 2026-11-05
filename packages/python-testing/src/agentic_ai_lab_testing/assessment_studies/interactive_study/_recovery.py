# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Restore exact interaction history and revalidate historical evidence under current sources."

import sys
import copy
import json
from agentic_ai_lab_runtime.reasoning import EvidenceInteraction
from agentic_ai_lab_runtime.reasoning import identity


def _revalidate_prefix_checks(
    old, start_stage, cut, interaction, checks, conversation, save, trajectory
):
    """Own the revalidate prefix checks phase and retain its evidence checks."""
    refreshed = []
    for check in old["checks"]:
        if check["stage"] != start_stage or check["providerCall"] not in {
            c["id"] for c in old["calls"][:cut]
        }:
            continue
        arguments = json.loads(check["arguments"])
        feedback = interaction.check(
            arguments["branches"],
            model_call=old["calls"][cut - 1]["id"],
        )
        refreshed.append(feedback)
        checks.append(
            {
                "providerCall": old["calls"][cut - 1]["id"],
                "stage": start_stage,
                "revalidation": True,
                "callId": check["callId"],
                "arguments": check["arguments"],
                "feedback": feedback,
            }
        )
    codec = getattr(
        sys.modules[EvidenceInteraction.__module__],
        "compact_feedback",
        lambda x: x,
    )
    conversation.history.append_feedback(
        {
            "repairCheckpoint": "Previous local checks have been revalidated under the current implementation. Historical references cannot be used as current evidence.",
            "checkedFragments": [codec(f) for f in refreshed],
            "taskAnswerProvided": False,
        }
    )
    save(trajectory.snapshot())


def _replay_prefix_calls(
    old,
    cut,
    case,
    interaction,
    calls,
    trajectory,
    verdicts,
    failure,
    current_round,
    global_round,
):
    """Own the replay prefix calls phase and retain its evidence checks."""
    for original in old["calls"][:cut]:
        if original["stage"] == 2 and interaction.chain.source_identity != identity(
            case["changed"]
        ):
            interaction.replace(case["changed"])
            current_round = 0
        calls.append(copy.deepcopy(original))
        current_round += 1
        global_round += 1
        trajectory.model_call(original["id"], current_round, original["usage"])
    verdicts.extend(
        copy.deepcopy(v)
        for v in old["verdicts"]
        if v["providerCall"] in {c["id"] for c in old["calls"][:cut]}
        and v is not failure
    )
    if failure:
        verdicts.append(copy.deepcopy(failure))
        trajectory.verify(
            False,
            "independent-fixed-point-oracle.v1",
            round=current_round,
            scope="subgoal",
            candidate=failure["prediction"],
        )
    return current_round, global_round


def _restore_prefix_history(prefix, failed_prefix, question, conversation):
    """Own the restore prefix history phase and retain its evidence checks."""
    old = json.loads((prefix / "records.json").read_text())
    failure = (
        next(v for v in old["verdicts"] if not v["correct"]) if failed_prefix else None
    )
    cut = (
        next(
            i for i, c in enumerate(old["calls"]) if c["id"] == failure["providerCall"]
        )
        + 1
        if failure
        else len(old["calls"])
    )
    start_stage = failure["stage"] if failure else 0
    prefix_count = sum(c["stage"] == start_stage for c in old["calls"][:cut])
    next_stem = (
        old["calls"][cut]["id"]
        if cut < len(old["calls"])
        else f"stage-{start_stage}-call-{prefix_count}"
    )
    original_input = json.loads((prefix / (next_stem + "-request.json")).read_text())[
        "input"
    ]
    if original_input[0] != {"role": "user", "content": question}:
        raise ValueError("failed-prefix question changed")
    conversation.restore_history(original_input)
    return old, failure, cut, start_stage, prefix_count
