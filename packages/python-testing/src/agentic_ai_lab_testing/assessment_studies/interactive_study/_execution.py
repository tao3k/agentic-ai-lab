# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Execution for the interactive study study."""

from functools import partial
import json
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import (
    EvidenceInteraction,
    EvidenceConversation,
)
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import identity
from ..movie_study import provider_key
from ._cases import obligation_acceptance


from ._request import _request_stage_attempt

from ._recovery import (
    _revalidate_prefix_checks,
    _replay_prefix_calls,
    _restore_prefix_history,
)

from ._results import _publish_interaction_result

from ._preflight import _qualify_source_versions


from ._plan import _prepare_run_plan


from ._verification import _verify_stage_answer


from ._ledger import _save_ledger


from ._operations import _source_operations


from ._attempt_observation import _call_observation


def run(
    library,
    output,
    *,
    live=False,
    index=0,
    arm="retained",
    resume_prefix=None,
    failed_prefix=None,
    checkpoint_prefix=None,
    seed_offset=0,
):
    plan, case = _prepare_run_plan(
        output,
        seed_offset,
        index,
        arm,
        checkpoint_prefix,
        failed_prefix,
        library,
        resume_prefix,
        __file__,
    )
    engine = ReasoningRuntime()
    calls = []
    checks = []
    verdicts = []
    operations = _source_operations(case, arm)

    save = partial(_save_ledger, output, calls, checks, verdicts)

    try:
        # Qualify compiled derived relations against independent oracles before paid calls.
        _qualify_source_versions(engine, case)
        if not live:
            (output / "result.json").write_text(
                json.dumps({"preflight": "passed", "paidCalls": 0})
            )
            return
        question = (
            case["description"]
            + "\n"
            + case["goals"][0]
            + "\nAvailable evidence tools can be called at any point in your reasoning, including before an answer. "
            "Choose your own candidate branches and entity bindings. Local tool support does not itself solve the whole question. "
            "Explanations/Markdown are welcome. Include the complete final job set as a JSON object with an answer array.\nFinite sources:\n"
            + json.dumps(case["sources"], separators=(",", ":"))
        )
        key = provider_key()
        all_correct = True
        global_round = 0
        current_round = 0
        fatal = False
        with Trajectory(engine, case["case"], identity(case["sources"])) as trajectory:
            with EvidenceInteraction(
                engine,
                case["sources"],
                operations,
                trajectory=trajectory,
                retain=arm == "retained",
            ) as interaction:
                conversation = EvidenceConversation(question, interaction)
                prefix_count = 0
                start_stage = 0
                prefix = failed_prefix or checkpoint_prefix
                if prefix is not None:
                    old, failure, cut, start_stage, prefix_count = (
                        _restore_prefix_history(
                            prefix, failed_prefix, question, conversation
                        )
                    )
                    current_round, global_round = _replay_prefix_calls(
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
                    )
                    _revalidate_prefix_checks(
                        old,
                        start_stage,
                        cut,
                        interaction,
                        checks,
                        conversation,
                        save,
                        trajectory,
                    )
                for stage in range(start_stage, 3):
                    if stage == 1:
                        conversation.history.append_feedback(
                            {"nextGoal": case["goals"][stage], "sourcesUnchanged": True}
                        )
                    if stage == 2 and not (prefix is not None and start_stage == 2):
                        interaction.replace(case["changed"])
                        current_round = 0
                        conversation.history.append_feedback(
                            {
                                "nextGoal": case["goals"][stage],
                                "sourceUpdate": case["changed"],
                                "sourceIdentity": interaction.chain.source_identity,
                                "oldEvidenceInvalidated": True,
                            }
                        )
                    success = False
                    failures = 0
                    for attempt in range(
                        8 - (prefix_count if stage == start_stage else 0)
                    ):
                        global_round += 1
                        current_round += 1
                        stem = f"stage-{stage}-call-{attempt + (prefix_count if stage == start_stage else 0)}"
                        raw, meta = _request_stage_attempt(
                            conversation,
                            interaction,
                            output,
                            stem,
                            case,
                            arm,
                            resume_prefix,
                            stage,
                            attempt,
                            key,
                        )
                        terminal = meta.get("terminal") or {}
                        observation = _call_observation(
                            stem, stage, global_round, terminal, meta, raw
                        )
                        calls.append(observation)
                        save(trajectory.snapshot())
                        if meta.get("error") or terminal.get("status") != "completed":
                            trajectory.model_call(
                                stem, current_round, terminal.get("usage")
                            )
                            fatal = True
                            all_correct = False
                            break
                        results = conversation.accept(
                            terminal, call_id=stem, round=current_round
                        )
                        if results:
                            checks.extend(
                                [
                                    {"providerCall": stem, "stage": stage, **r}
                                    for r in results
                                ]
                            )
                            save(trajectory.snapshot())
                            continue
                        success = _verify_stage_answer(
                            observation,
                            case,
                            stage,
                            verdicts,
                            trajectory,
                            current_round,
                            save,
                            stem,
                        )
                        if success:
                            break
                        failures += 1
                        if failures >= 3:
                            break
                        conversation.history.append_feedback(
                            {
                                "verification": "not-correct",
                                "scope": "whole-current-goal",
                                "reason": "Complete job set does not match independently evaluated finite semantics. Check context/tag bindings, conjunction, exclusions, and source generation. Tools remain available.",
                            }
                        )
                    all_correct = all(obligation_acceptance(verdicts)[0])
                    if fatal:
                        break
                    if not success:
                        conversation.history.append_feedback(
                            {
                                "stageStatus": "unresolved-within-predeclared-budget",
                                "nextStageFollows": True,
                            }
                        )
            snapshot = trajectory.close(
                "complete" if all_correct else "unresolved-or-provider-failure"
            )
        save(snapshot)
        _publish_interaction_result(
            output, case, arm, all_correct, calls, verdicts, checks
        )
    finally:
        engine.close()
