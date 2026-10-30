# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Obligations for the assessment formal study."""

from __future__ import annotations

from dataclasses import replace
import json
import re
from ..assessment_models import FAULTS
from ._models import Configuration, Obligation


def obligations(base: Configuration) -> tuple[Obligation, ...]:
    model = base.model
    result = [Obligation("correct", base)]
    for mutation, property_name, expected in FAULTS.get(model, ()):
        constants = {}
        for name in ("Mutation", "Fault"):
            if re.search(rf"(?m)^{name} = ", base.constants):
                constants[name] = json.dumps(mutation)
        if "EarlyReturn = FALSE" in base.constants:
            constants["EarlyReturn"] = True
        fault = base.changed(**constants)
        if model == "ProviderFrontier" and mutation == "initial":
            fault = fault.changed(Seeded=True)
        if model == "LatticeProjection" and mutation in (
            "budget-skip",
            "budget-events",
            "refusal-publish",
        ):
            fault = fault.changed(Remaining=1)
        fault = replace(
            fault,
            invariants=(property_name,) if expected == 12 else (),
            properties=(fault.qualified(property_name),) if expected == 13 else (),
        )
        result.append(
            Obligation(mutation, fault, expected, fault.qualified(property_name))
        )
    arithmetic_faults = {
        "EvidenceInteraction": ("negative-cost", "negative-events"),
        "EvidenceConsumption": ("negative-cost", "future-snapshot"),
    }
    for mutation in arithmetic_faults.get(model, ()):
        fault = replace(
            base.changed(Mutation=json.dumps(mutation)),
            invariants=("Safety",),
            properties=(),
        )
        result.append(Obligation(mutation, fault, 12, "Safety"))
    if model in ("ActorRoundCredits", "ActorTestPool", "ReadyComponents"):
        result.extend(
            Obligation(f"capacity-{n}", base.changed(Capacity=n)) for n in (1, 3)
        )
    if model == "LatticeProjection":
        result.extend(
            Obligation(f"remaining-{n}", base.changed(Remaining=n)) for n in (0, 1)
        )
    if model == "EvidenceLifecycle":
        result.append(Obligation("caller-finite", base.changed(InputLimit=1)))
    if model == "ProviderFrontier":
        result.extend(
            (
                Obligation("seeded", base.changed(Seeded=True)),
                Obligation("overlap", base.changed(Fault='"overlap"')),
            )
        )
    if model == "WithdrawalConcurrency":
        successor = base.changed(SecondExpected=1)
        result.extend(
            (
                Obligation("successor", successor),
                Obligation(
                    "late-receipt",
                    successor.changed(Mutation='"lateReceipt"'),
                    12,
                    "ReceiptBound",
                ),
            )
        )
    if model == "ReaderLifetime":
        result.append(
            Obligation(
                "single-reader-global-fairness",
                base.changed(Readers="{1}", Mutation='"global"'),
            )
        )
        round_config = replace(
            base,
            specification="roundSpec",
            properties=("ReaderCompletion", "RoundCompletion"),
        )
        result.append(Obligation("sealed-round", round_config))
        unfair = replace(
            round_config.changed(Mutation='"unfair"'),
            invariants=(),
            properties=("RoundCompletion",),
        )
        result.append(Obligation("sealed-round-unfair", unfair, 13, "RoundCompletion"))
    return tuple(result)


def validate_output(obligation: Obligation, code: int, output: str) -> None:
    if code != obligation.expected:
        raise RuntimeError(
            f"{obligation.name}: exit={code} expected={obligation.expected}\n{output}"
        )
    if code == 0:
        valid = "Model checking completed. No error has been found." in output
    elif code == 12:
        valid = f"Invariant {obligation.property} is violated" in output
    else:
        valid = bool(
            re.search(
                rf"Temporal propert(y {re.escape(obligation.property)} was|ies were) violated|"
                rf"Action property {re.escape(obligation.property)} is violated",
                output,
            )
        )
    if not valid:
        raise RuntimeError(
            f"missing checker conclusion for {obligation.name}\n{output}"
        )
