# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_testing.assessment_studies.compound_inference_report import summarize_episode,summarize


def attempt(outcome,thinking,action='answer',feedback=None):
    return {'providerCalls':1,'correct':outcome=='verified_answer','outcome':outcome,
            'providerOutcome':'completed_ungraded','usage':{'input_tokens':10,'output_tokens':thinking+1,
            'output_tokens_details':{'reasoning_tokens':thinking}},
            'action':{'action':action,'contract':{'rules':[]}},'feedback':feedback or {}}


class CompoundReportAudit(unittest.TestCase):
    def test_failed_attempt_and_all_repairs_remain_charged(self):
        episode={'case':'c','repetition':0,'arm':'scheme-evidence',
                 'attempts':[attempt('evidence_progress',5,'scan'),attempt('action_failure',13,'query'),
                             attempt('evidence_progress',17,'query'),attempt('verified_answer',19)]}
        result=summarize_episode(episode)
        self.assertEqual(result['effort']['observedReasoningTokens'],54)
        self.assertEqual(result['failureAndRepairEffort']['observedReasoningTokens'],49)
        self.assertEqual(result['postFailureModelCalls'],2)
        self.assertEqual(result['failureAttempts'],1)

    def test_evidence_exposure_and_extension_are_distinct(self):
        first=attempt('evidence_progress',3,'query',{'publishedEvidence':[{'relation':'checked'}]})
        second=attempt('evidence_progress',4,'query')
        second['action']['contract']['rules']=[{'body':[{'relation':'checked'}]}]
        result=summarize_episode({'case':'c','repetition':0,'arm':'scheme-evidence',
                                 'attempts':[first,second,attempt('verified_answer',5)]})
        self.assertEqual(result['laterCallsExposedToEvidence'],2)
        self.assertEqual(result['aliasExtensionQueries'],1)

    def test_malformed_provider_action_is_reported_without_normalizing_the_trial(self):
        bad=attempt('action_failure',7)
        bad['action']={'action':{'action':'query','contract':{'rules':[]}}}
        result=summarize_episode({'case':'c','repetition':0,'arm':'scheme-evidence','attempts':[bad]})
        self.assertEqual(result['actions'],['invalid action shape'])
        self.assertEqual(result['failureAndRepairEffort']['observedReasoningTokens'],7)

    def test_censored_failure_is_not_in_the_success_savings_subset(self):
        plan={'cases':[{'name':'c'}],'arms':['raw-fact-reasoning','scheme-evidence'],'repetitions':1}
        result=summarize(plan,{'pairs':[],'episodes':[
            {'case':'c','repetition':0,'arm':'raw-fact-reasoning','attempts':[attempt('verified_answer',50)]},
            {'case':'c','repetition':0,'arm':'scheme-evidence','attempts':[attempt('answer_not_verified',100)]}]})
        self.assertEqual(result['groups']['scheme-evidence']['accuracy'],0)
        self.assertEqual(result['groups']['scheme-evidence']['consumedReasoningTokens'],100)
        self.assertIsNone(result['jointlyVerifiedThinkingReduction'])
        self.assertIsNone(result['pairs'][0]['thinkingReduction'])


if __name__=='__main__':unittest.main()
