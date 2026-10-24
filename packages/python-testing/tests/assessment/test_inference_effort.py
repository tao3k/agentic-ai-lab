# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_testing.assessment_studies.inference_effort import until_verified,paired_reduction


def attempt(correct,reasoning,visible=20,adaptive=False):
    return {'providerCalls':1,'correct':correct,'adaptive':adaptive,
            'usage':{'input_tokens':100,'output_tokens':reasoning+visible,
                     'output_tokens_details':{'reasoning_tokens':reasoning}}}


class InferenceEffort(unittest.TestCase):
    def test_failures_and_repair_are_charged_until_first_verified_answer(self):
        baseline=until_verified([attempt(False,1000),attempt(False,800),attempt(True,600),attempt(True,5000)])
        candidate=until_verified([attempt(False,500),attempt(True,400)])
        self.assertEqual(baseline['modelCalls'],3)
        self.assertEqual(baseline['observedReasoningTokens'],2400)
        self.assertEqual(candidate['modelCalls'],2)
        self.assertEqual(candidate['observedReasoningTokens'],900)
        self.assertAlmostEqual(paired_reduction(baseline,candidate,'modelCalls'),1/3)
        self.assertAlmostEqual(paired_reduction(baseline,candidate,'observedReasoningTokens'),.625)

    def test_unverified_and_unknown_usage_do_not_become_cheap_successes(self):
        failed=until_verified([attempt(False,100)])
        solved=until_verified([attempt(True,200)])
        self.assertIsNone(paired_reduction(solved,failed,'modelCalls'))
        unknown=until_verified([{'providerCalls':1,'correct':True}])
        self.assertIsNone(unknown['totalModelTokens'])
        self.assertIsNone(paired_reduction(solved,unknown,'totalModelTokens'))

    def test_retained_execution_is_free_of_model_tokens_but_bootstrap_is_not(self):
        bootstrap=attempt(True,500)
        warm={'providerCalls':0,'correct':True,'schemeSeconds':.001}
        self.assertEqual(until_verified([warm])['modelCalls'],0)
        self.assertEqual(until_verified([warm])['totalModelTokens'],0)
        self.assertEqual(until_verified([bootstrap,warm])['observedReasoningTokens'],500)

    def test_visible_answer_length_does_not_define_reasoning_reduction(self):
        first=until_verified([attempt(True,1000,300)])
        second=until_verified([attempt(True,1000,200)])
        self.assertEqual(paired_reduction(first,second,'observedReasoningTokens'),0)
        adaptive=until_verified([attempt(False,400),attempt(True,500,adaptive=True)])
        self.assertTrue(adaptive['adaptive'])


if __name__=='__main__':unittest.main()
