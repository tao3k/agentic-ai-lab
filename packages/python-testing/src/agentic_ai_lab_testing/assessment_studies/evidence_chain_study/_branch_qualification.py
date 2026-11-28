# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Branch qualification for the evidence chain study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import copy, hashlib, json
from ..model_study import provider
from ..movie_study import provider_key
from ._branch_contracts import branch_payload, branch_submission_context
from ._config import SHARED_CANDIDATE
from ._shared_cases import shared_source, shared_truth
from ._shared_check import shared_check


def branch_qualify(engine, tasks):
    from agentic_ai_lab_runtime.reasoning import ComputationalEvidence

    checks = []
    for task in tasks:
        with ComputationalEvidence(engine) as store:
            source = shared_source(task)
            resolved = store.resolve(source, SHARED_CANDIDATE)
            assert resolved["status"] == "verified"
            assert sorted(resolved["rows"]) == [
                [i] for i in range(16) if shared_truth(task, ["ready", i])
            ]
            supports = []
            for _ in task["branches"]:
                hit = store.resolve(source, SHARED_CANDIDATE)
                assert hit["reused"]
                observation = store.observe(
                    source,
                    SHARED_CANDIDATE,
                    hit["handle"],
                    [task["sharedAtom"]],
                    support=True,
                )
                supports.append(observation)
            assert (
                all(x == supports[0] for x in supports)
                and store.stats()["proof-builds"] == 1
            )
            checks.append(
                {
                    "id": task["id"],
                    "proofBuilds": 1,
                    "sharedSupportIdenticalAcrossBranches": True,
                    "nativeStats": store.stats(),
                }
            )
    return checks


def branch_input_reservation(request, prior_usage, additions, padding):
    # Replayed output is already measured in the preceding input + all-output usage.
    # Only genuinely new paired tool results use the conservative UTF-8 bound.
    measured = (
        len(json.dumps(request, ensure_ascii=False).encode())
        if prior_usage is None
        else prior_usage
        + sum(len(json.dumps(x, ensure_ascii=False).encode()) for x in additions)
    )
    return measured + padding


def branch_entry_reservation(request, prior_request, prior_input, padding):
    if prior_request is None:
        return branch_input_reservation(request, None, [], padding)
    # Only a changed branch record is new; all other request/context bytes must match.
    a = {
        k: v
        for k, v in prior_request.items()
        if k not in ("input", "max_output_tokens")
    }
    b = {k: v for k, v in request.items() if k not in ("input", "max_output_tokens")}
    old = json.loads(prior_request["input"][0]["content"])
    new = json.loads(request["input"][0]["content"])
    if a != b or {k: v for k, v in old.items() if k != "branch"} != {
        k: v for k, v in new.items() if k != "branch"
    }:
        return branch_input_reservation(request, None, [], padding)
    return (
        prior_input
        + sum(
            len(json.dumps(c["branch"], ensure_ascii=False).encode())
            for c in (old, new)
        )
        + padding
    )


def branch_qualification_request(plan, fixture):
    request = copy.deepcopy(fixture["request"])
    request["input"] += branch_submission_context(fixture["terminal"])
    request.update(
        reasoning={"effort": "none"},
        tools=[plan["tool"]],
        tool_choice={"type": "function", "name": "submit_selection"},
        max_output_tokens=plan["finalizationOutputCap"],
    )
    return request


def branch_import_output_qualification(directory, output):
    """Reuse actual transport receipts only for byte-identical qualification requests."""
    plan = shared_check(directory)
    fixture = json.loads(
        (directory / "inputs/t/research/output-check-fixture.json").read_text()
    )
    expected = branch_qualification_request(plan, fixture)
    record = json.loads((output / "receipt.json").read_text())
    actual = json.loads((output / "request.json").read_text())
    terminal = json.loads((output / "response.json").read_text())["terminal"]
    assert (
        record["passed"] and expected == actual and record["usage"] == terminal["usage"]
    )
    assert (
        terminal["status"] == "completed"
        and branch_payload(terminal) == record["selected"]
    )
    assert (
        terminal["usage"]["input_tokens"]
        >= fixture["terminal"]["usage"]["input_tokens"] + 1024
    )
    assert (
        record["fixtureSha256"]
        == plan["inputs"]["t/research/output-check-fixture.json"]
    )
    linked = {
        **record,
        "acceptedForPlanSha256": hashlib.sha256(
            (directory / "plan.json").read_bytes()
        ).hexdigest(),
        "qualificationRequestSha256": hashlib.sha256(
            (output / "request.json").read_bytes()
        ).hexdigest(),
        "reuseScope": "Byte-identical nonthinking transport request only; does not qualify thinking tool choice or native semantics",
    }
    (directory / "output-qualification.json").write_text(
        json.dumps(linked, indent=2) + "\n"
    )
    report_text("OUTPUT_QUALIFICATION_REQUEST_IDENTITY_OK", flush=True)


def branch_output_qualify(directory, output):
    """Explicit paid transport gate; clean-rebuild never calls this function."""
    plan = shared_check(directory)
    output.mkdir(parents=True, exist_ok=False)
    fixture = json.loads(
        (directory / "inputs/t/research/output-check-fixture.json").read_text()
    )
    request = branch_qualification_request(plan, fixture)
    bound = branch_input_reservation(request, None, [], plan["inputPadding"])
    (output / "request.json").write_text(json.dumps(request, indent=2) + "\n")
    record = {
        "passed": False,
        "planSha256": hashlib.sha256(
            (directory / "plan.json").read_bytes()
        ).hexdigest(),
        "fixtureSha256": plan["inputs"]["t/research/output-check-fixture.json"],
        "costBoundary": "Transport qualification separately charged, not a solver trajectory",
        "inputReservation": bound,
        "usage": None,
        "failure": None,
    }
    try:
        _, meta = provider(request, provider_key(), output / "response.json")
        terminal = meta.get("terminal") or {}
        record["usage"] = terminal.get("usage")
        assert not meta.get("error") and terminal.get("status") == "completed", (
            "output qualification provider failure"
        )
        u = terminal["usage"]
        assert (
            u["input_tokens"] <= bound
            and u["output_tokens"] <= plan["finalizationOutputCap"]
        )
        baseline_input = fixture["terminal"]["usage"]["input_tokens"]
        assert u["input_tokens"] >= baseline_input + 1024, (
            "historical thinking not reflected in input usage"
        )
        record["historicalThinkingInputIncrement"] = u["input_tokens"] - baseline_input
        record["selected"] = branch_payload(terminal)
        record["passed"] = True
    except Exception as error:
        record["failure"] = str(error)
    (output / "receipt.json").write_text(json.dumps(record, indent=2) + "\n")
    (directory / "output-qualification.json").write_text(
        json.dumps(record, indent=2) + "\n"
    )
    assert record["passed"], record["failure"]
    report_text("OUTPUT_FINALIZATION_QUALIFIED", flush=True)
