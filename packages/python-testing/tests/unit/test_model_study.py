# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Frozen scoring and paired Runtime transport without paid model calls."""

from __future__ import annotations

from types import SimpleNamespace

from agentic_ai_lab_testing.model_study.runner import build_graph, corpus, grade
from agentic_ai_lab_testing.model_study.paired import typed_observation
from agentic_ai_lab_testing.model_study.protocol import (
    guard_answer, proof_observation, require_pinned_ascent,
)
from agentic_ai_lab_testing.model_study.scheme import readable_answer
from agentic_ai_lab_testing.temporal.authority import gate_model_answer, guarded_runtime


def test_frozen_corpus_and_strict_score() -> None:
    cases = corpus()
    assert len(cases) == 5
    expected = cases[0]["expected"]
    assert grade('{"choice":"B","claim":"bounded_candidate_only"}', expected) == {
        "valid_json": True, "choice_correct": True, "claim_correct": True,
    }
    assert grade('{"choice":"B","claim":"general_truth"}', expected) == {
        "valid_json": True, "choice_correct": True, "claim_correct": False,
    }
    assert grade('{"choice":"B","claim":"bounded_candidate_only","extra":1}', expected)[
        "valid_json"
    ] is False


def test_model_arms_share_prompt_and_tool_arm_adds_only_observation() -> None:
    calls: list[dict] = []

    def create(**kwargs):
        calls.append(kwargs)
        return SimpleNamespace(
            status="completed", id="fake-response", usage=None,
            output_text='{"choice":"B","claim":"bounded_candidate_only"}',
        )

    client = SimpleNamespace(responses=SimpleNamespace(create=create))
    case = corpus()[0]
    for arm in ("baseline", "tool"):
        state, trace = build_graph(client, case, arm, {"status": "complete"}).invoke_with_trace({})
        assert trace == ["observation", "model", "score"]
        assert state["score"]["choice_correct"] is True
    assert calls[0]["input"] == [{"role": "user", "content": case["prompt"]}]
    assert calls[1]["input"][0] == calls[0]["input"][0]
    assert len(calls[1]["input"]) == 2
    for call in calls:
        assert call["model"] == "deepseek-flash"
        assert call["temperature"] == 0
        assert call["reasoning"] == {"effort": "none"}
        assert call["max_output_tokens"] == 512
        assert "instructions" not in call


def test_typed_observation_preserves_boolean_and_scope() -> None:
    ascent = typed_observation("ascent.wrong-join", {"status": "complete"})
    assert ascent == {
        "status": "complete",
        "evidence_scope": "candidate_on_named_finite_snapshot",
        "intent_verified": False,
    }
    temporal = typed_observation("temporal.closed-cut", {
        "status": "bounded-temporal-classification",
        "release-authorized?": "#f",
    })
    assert temporal == {
        "status": "bounded-temporal-classification",
        "release_authorized": False,
        "causation_proven": False,
        "evidence_scope": "temporal_classification_only",
    }


def test_runtime_guard_withholds_native_denied_model_claims() -> None:
    closed = typed_observation("temporal.closed-cut", {
        "source": "agentic-ai-lab.temporal-causality",
        "status": "bounded-temporal-classification",
        "release-authorized?": "#f",
        "unknown": "()",
    })
    unsafe = '{"choice":"A","claim":"release_authorized"}'
    state, trace = guarded_runtime().invoke_with_trace({
        "model_output": unsafe, "observation": closed,
    })
    assert trace == ["authority"]
    assert state["guard"] == {
        "status": "withheld", "reason": "native-denies-release",
    }
    safe = '{"choice":"A","claim":"classification_no_authority"}'
    assert gate_model_answer(safe, closed) == {
        "status": "observation-only", "choice": "A",
        "claim": "classification_no_authority",
    }
    opened = typed_observation("temporal.open-parent", {
        "source": "agentic-ai-lab.temporal-causality",
        "release-authorized?": "#f",
        "unknown": '("missing-administration")',
    })
    assert gate_model_answer('{"choice":"A","claim":"negative_claim"}', opened) == {
        "status": "withheld", "reason": "open-frontier-denies-absence",
    }


def test_stratified_observation_keeps_candidate_scope_and_guards_model_claim() -> None:
    typed = typed_observation("ascent.negation-count", {
        "source": "gerbil-ascent", "status": "complete", "rows": "((1 1))",
    })
    receipt = {
        "status": "complete", "rows": "((1 1))",
        "proof-status": "complete", "finite-verdict": "valid",
        "proof-verdict": "valid",
    }
    proof = proof_observation("ascent.negation-count", typed, receipt)
    assert proof["proof_scope"] == "one_founded_support_per_result_on_named_finite_snapshot"
    assert proof["intent_verified"] is False
    assert guard_answer(
        "ascent.negation-count", '{"choice":"A","claim":"bounded_candidate_only"}',
        proof, {},
    ) == {"status": "observation-only", "choice": "A",
          "claim": "bounded_candidate_only"}
    assert guard_answer(
        "ascent.negation-count", '{"choice":"A","claim":"general_truth"}',
        proof, {},
    ) == {"status": "withheld", "reason": "candidate-claim-exceeds-evidence"}
    assert proof_observation("ascent.wrong-join", typed, receipt) == typed


def test_live_study_requires_exact_ascent_dependency_pin(tmp_path, monkeypatch) -> None:
    from agentic_ai_lab_testing.model_study import protocol

    ascent = tmp_path / "ascent"
    poo = tmp_path / "poo"
    ascent.mkdir()
    poo.mkdir()
    head = "a" * 40
    monkeypatch.setattr(protocol, "source_head", lambda _root: head)
    package = poo / "gerbil.pkg"
    package.write_text(f'(dependencies "github.com/tao3k/gerbil-ascent@{head}")')
    require_pinned_ascent(ascent, poo)

    package.write_text('(dependencies "github.com/tao3k/gerbil-ascent@' + "b" * 40 + '")')
    try:
        require_pinned_ascent(ascent, poo)
    except RuntimeError as error:
        assert "dependency pin" in str(error)
    else:
        raise AssertionError("mismatched dependency pin accepted")


def test_scheme_answer_filter_allows_symbols_without_reader_directives() -> None:
    assert readable_answer("(answer ((path 0 1) (summary 1 2)))")
    assert readable_answer("(answer ((invalid-body (rule ?x ?y))))")
    assert not readable_answer("(answer #.(system 1))")
    assert not readable_answer("(answer ((0 1))")
    assert not readable_answer("(answer 0))(")
