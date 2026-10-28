# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_testing.assessment_studies.domain_repository_report import candidate_repair


def turn(n,tokens,actions,correct=False):
    return {'turn':n,'providerCalls':1,'usage':{'input_tokens':1,'output_tokens':tokens,'output_tokens_details':{'reasoning_tokens':tokens}},'actions':actions,'correct':correct}


class CandidateRepairAccounting(unittest.TestCase):
    def test_original_defect_is_diagnosis_and_post_edit_failure_is_repair(self):
        bad={'name':'run_reproducer','result':{'auditDomainChecks':[{'claims':[['constraint',False]]}]}}
        edit={'name':'edit_source','result':{'edited':['source.py']}}
        attempts=[turn(1,100,[bad]),turn(2,200,[edit]),turn(3,300,[bad]),turn(4,400,[],True)]
        result=candidate_repair(attempts)
        self.assertEqual(result['firstFailureTurn'],3)
        self.assertEqual(result['observedReasoningTokens'],700)
        self.assertEqual(result['modelCalls'],2)
        self.assertTrue(result['verified'])

    def test_same_turn_edit_and_failure_charges_entire_turn(self):
        actions=[{'name':'edit_source','result':{'edited':['source.py']}},
                 {'name':'run_checks','result':{'allChecksPassed':False}}]
        result=candidate_repair([turn(1,100,actions),turn(2,200,[],True)])
        self.assertEqual(result['observedReasoningTokens'],300)

    def test_rejected_submission_counts_without_an_edit(self):
        result=candidate_repair([turn(1,100,[{'name':'submit_patch','result':{'verified':False}}]),turn(2,200,[],True)])
        self.assertEqual(result['firstFailureTurn'],1)
        self.assertEqual(result['failureKind'],'independent-submission')

    def test_unknown_or_absent_domain_observation_is_not_an_assessed_failure(self):
        result=candidate_repair([turn(1,100,[{'name':'edit_source','result':{'edited':['source.py']}},
                                          {'name':'run_reproducer','result':{'error':'collector unavailable'}}])])
        self.assertIsNone(result['firstFailureTurn'])


if __name__=='__main__':unittest.main()
