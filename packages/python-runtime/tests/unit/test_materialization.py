# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import pytest

from agentic_ai_lab_runtime.materialization import (
    RuntimeGraphBindings,
    describe_runtime_graph_plan,
)
from agentic_ai_lab_runtime.receipts import parse_runtime_receipt
from agentic_ai_lab_runtime.runtime_graph import linear_plan


def test_domain_description_is_deterministic_without_c_abi() -> None:
    plan = linear_plan("load", "run", step_limit=12)
    bindings = RuntimeGraphBindings(
        node_actions={"load": "poo.load", "run": "poo.run"},
        state_reducers={"events": "poo.events.append"},
    )

    left = describe_runtime_graph_plan(plan, bindings)
    right = describe_runtime_graph_plan(plan, bindings)
    receipt = parse_runtime_receipt(left)

    assert left == right
    assert receipt.kind == "runtime-graph-domain-validation"
    assert receipt.plan_digest is not None


def test_domain_description_rejects_unknown_action_binding() -> None:
    with pytest.raises(ValueError, match="unknown nodes"):
        describe_runtime_graph_plan(
            linear_plan("load"),
            RuntimeGraphBindings(node_actions={"missing": "poo.missing"}),
        )
