# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import json
from pathlib import Path
import tempfile
import unittest
from agentic_ai_lab_testing.assessment_studies.repository_statistics import billing, repair_effort
from agentic_ai_lab_testing.assessment_studies.repository_metrics import trajectory_metrics, integrated_metrics
from agentic_ai_lab_testing.assessment_studies.inference_effort import until_verified


def attempt(tokens, correct=False, submission=False):
    return {'providerCalls': 1, 'usage': {'input_tokens': 10, 'output_tokens': tokens+1, 'output_tokens_details': {'reasoning_tokens': tokens}}, 'correct': correct, 'actions': [{'name': 'submit_patch', 'result': {'verified': correct}}] if submission else []}


class RepositoryStatisticsTests(unittest.TestCase):
    def test_turn_ledger_stops_at_acceptance_and_accounts_for_edit_boundary(self):
        a = attempt(100); a['sourceIdentity'] = 'parent'
        b = attempt(200); b['sourceIdentity'] = 'patch'
        b['actions'] = [{'name': 'edit_source', 'result': {'edited': ['source.py'], 'priorEvidenceInvalidated': True}}]
        c = attempt(300, True, True); c['sourceIdentity'] = 'patch'
        result = trajectory_metrics([a, b, c, attempt(999)])
        self.assertEqual([r['cumulativeThinkingTokens'] for r in result['rounds']], [100, 300, 600])
        self.assertEqual(result['preEditThinkingTokens'], 100)
        self.assertEqual(result['fromFirstEditThinkingTokens'], 500)
        self.assertEqual(result['firstAcceptedEditTurn'], 2)
        self.assertEqual(result['firstAcceptedTurn'], 3)
        self.assertEqual(result['observedSourceTransitions'], 1)
        self.assertEqual(result['actionCounts']['acceptedEdits'], 1)

    def test_unknown_usage_remains_unknown_and_private_payload_is_excluded(self):
        a = attempt(100); a['usage'] = None
        a['actions'] = [{'name': 'read_source', 'result': {'text': 'PRIVATE', 'observedOutput': 'PRIVATE'}}]
        result = trajectory_metrics([a, attempt(200)])
        self.assertIsNone(result['rounds'][0]['thinkingTokens'])
        self.assertIsNone(result['rounds'][1]['cumulativeThinkingTokens'])
        self.assertIsNone(result['primaryThinkingTokens'])
        self.assertIsNone(result['peakDollarEstimate'])
        self.assertNotIn('PRIVATE', json.dumps(result))

    def test_censored_cost_is_in_yield_not_success_only_distribution(self):
        entries = []
        for attempts in ([attempt(100, True)], [attempt(300)]):
            entries.append({'arm': 'ordinary-tools', 'effort': until_verified(attempts),
                            'trajectory': trajectory_metrics(attempts)})
        result = integrated_metrics(entries, [])[0]
        self.assertEqual(result['acceptanceRate'], .5)
        self.assertEqual(result['thinkingIncludingCensored'], 400)
        self.assertEqual(result['censoredThinking'], 300)
        self.assertEqual(result['thinkingPerAcceptedYield'], 400)
        self.assertEqual(result['thinkingDistributionAll']['median'], 200)
        self.assertEqual(result['callsDistributionAccepted']['n'], 1)
        self.assertEqual(result['milestones'][0]['thinkingConsumed'], 400)
        self.assertEqual(result['milestones'][0]['accepted'], 1)

    def test_common_budget_counts_acceptance_only_at_its_observed_turn(self):
        attempts = [attempt(10) for _ in range(19)] + [attempt(10, True)]
        row = {'arm': 'scheme-retained', 'effort': until_verified(attempts),
               'trajectory': trajectory_metrics(attempts)}
        result = integrated_metrics([row], [])[0]
        self.assertEqual([m['accepted'] for m in result['milestones']], [0, 1, 1, 1])
        self.assertEqual([m['thinkingConsumed'] for m in result['milestones']], [100, 200, 200, 200])
        self.assertEqual(row['trajectory']['adaptiveThinkingTokens'], 100)

    def test_paired_aggregation_preserves_regression_and_weights_denominator(self):
        attempts = [attempt(30, True)]
        row = {'arm': 'scheme-fresh', 'effort': until_verified(attempts),
               'trajectory': trajectory_metrics(attempts)}
        pairs = [{'arm': 'scheme-fresh', 'thinkingReduction': .5, 'baselineThinking': 100, 'candidateThinking': 50},
                 {'arm': 'scheme-fresh', 'thinkingReduction': -.25, 'baselineThinking': 200, 'candidateThinking': 250},
                 {'arm': 'scheme-fresh', 'thinkingReduction': None, 'baselineThinking': 100, 'candidateThinking': 5}]
        result = integrated_metrics([row], pairs)[0]
        self.assertEqual(result['jointlyAcceptedPairs'], 2)
        self.assertEqual(result['pairedWeightedReduction'], 0)
        self.assertEqual(result['pairedSavedThinking'], 0)
        self.assertEqual(result['pairedRegressions'], 1)
        self.assertEqual(result['pairedWins'], 1)
        self.assertEqual(result['pairedReductionDistribution']['mean'], .125)

    def test_all_censored_has_no_yield_estimate_or_paired_savings(self):
        attempts = [attempt(30)]
        row = {'arm': 'scheme-retained', 'effort': until_verified(attempts),
               'trajectory': trajectory_metrics(attempts)}
        result = integrated_metrics([row], [])[0]
        self.assertIsNone(result['thinkingPerAcceptedYield'])
        self.assertIsNone(result['pairedWeightedReduction'])
        self.assertEqual(result['callsDistributionAccepted']['n'], 0)

    def test_repair_includes_rejected_submission_until_first_acceptance(self):
        result = repair_effort([attempt(100), attempt(200, submission=True), attempt(300), attempt(400, True, True), attempt(999)])
        self.assertEqual(result['modelCalls'], 3)
        self.assertEqual(result['observedReasoningTokens'], 900)
        self.assertTrue(result['verified'])

    def test_failing_development_checks_start_repair_accounting(self):
        failed = attempt(200)
        failed['actions'] = [{'name': 'run_checks', 'result': {'allChecksPassed': False, 'verified': False}}]
        result = repair_effort([attempt(100), failed, attempt(300, True, True)])
        self.assertEqual(result['observedReasoningTokens'], 500)
        self.assertEqual(result['failureFeedbackKind'], 'run_checks')

    def test_interrupted_request_is_unknown_not_zero(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); episode = root/'task'; episode.mkdir()
            (episode/'1.request.json').write_text('{}')
            (episode/'2.request.json').write_text('{}')
            (episode/'1.response.json').write_text(json.dumps({'terminal': {'usage': {'input_tokens': 10, 'output_tokens': 3, 'output_tokens_details': {'reasoning_tokens': 2}}}}))
            result = billing(root)
            self.assertEqual(result['startedRequests'], 2)
            self.assertEqual(result['observedCalls'], 1)
            self.assertEqual(result['unknownUsageRequests'], ['task/2.request.json'])
            self.assertEqual(result['observedReasoningTokens'], 2)
            self.assertFalse(result['invoiceVerified'])


if __name__ == '__main__': unittest.main()
