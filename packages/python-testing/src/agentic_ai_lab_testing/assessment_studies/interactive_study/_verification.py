# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Verify each returned stage answer against the original independent task oracle."

from ._cases import obligation_acceptance


def _verify_stage_answer(
    observation, case, stage, verdicts, trajectory, current_round, save, stem
):
    """Own the verify stage answer phase and retain its evidence checks."""
    prediction = observation["prediction"]
    success = prediction == case["gold"][stage]
    verdicts.append(
        {
            "providerCall": stem,
            "stage": stage,
            "correct": success,
            "prediction": prediction,
            "expected": case["gold"][stage],
        }
    )
    accepted, _ = obligation_acceptance(verdicts)
    trajectory.verify(
        success,
        "independent-fixed-point-oracle.v1",
        round=current_round,
        scope="task" if stage == 2 and all(accepted) else "subgoal",
        candidate=prediction,
    )
    save(trajectory.snapshot())
    return success
