# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
from agentic_ai_lab_testing.model_study.prediction_transport import prediction_from_output
from agentic_ai_lab_testing.model_study.direct.native import score_candidate


def test_transport_extracts_one_assertion_with_explanation():
    raw = "Expected:\n```scheme\n(check-equal? result '((11 13)))\n```\nThe edge joins."
    assert prediction_from_output(raw) == "(check-equal? result '((11 13)))"


def test_transport_rejects_conflicting_assertions_without_oracle():
    raw = "(check-equal? result '((11 13))) or (check-equal? result '((11 14)))"
    assert prediction_from_output(raw) is None
    assert prediction_from_output('No result offered.') is None


def test_transport_deduplicates_equal_tokens_but_preserves_symbol_boundaries():
    assert prediction_from_output("(check-equal? result '((1 2)))\n(check-equal? result '( (1 2) ))")
    assert prediction_from_output("(check-equal? result '(a b))\n(check-equal? result '(ab))") is None


def test_transport_does_not_accept_reader_execution_or_unbounded_input():
    assert prediction_from_output('```scheme\n#.(danger)\n```') is None
    assert prediction_from_output('x'*65537) is None


def test_normalized_guard_preserves_raw_output_and_rejects_ambiguity(tmp_path):
    raw = "(check-equal? result '(a)) or (check-equal? result '(b))"
    result = score_candidate(tmp_path, tmp_path/'unused', raw, tmp_path/'guard', normalize=True)
    assert result['transportAmbiguousOrAbsent'] and not result['correct']
    assert (tmp_path/'guard/raw-output.txt').read_text() == raw


def test_explicit_literal_and_assertion_conflict_is_not_hidden_by_priority():
    raw = "(check-equal? result '(a))\n```scheme\n'(b)\n```"
    assert prediction_from_output(raw) is None


def test_equal_transport_wrappers_and_code_explanation_do_not_create_false_conflict():
    raw = "```scheme\n(list (canonical '((1 2))))\n```\n```scheme\n'(((1 2)))\n```\n(check-equal? result '(((1 2))))"
    assert prediction_from_output(raw)
    assert prediction_from_output("```scheme\n'(a b)\n```\n```scheme\n(quote (a b))\n```")


def test_placeholder_is_task_incomplete_not_a_semantic_prediction():
    assert prediction_from_output("(check-equal? result '?)") is None
    assert prediction_from_output("(check-equal? result '((1 ?)))") is None
