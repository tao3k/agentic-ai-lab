# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_testing.assessment_studies.interactive_study import obligation_acceptance


class TaskEndpoint(unittest.TestCase):
    def verdict(self,stage,correct,call):return {'stage':stage,'correct':correct,'providerCall':call}

    def test_same_contract_later_success_repairs_the_original_goal(self):
        accepted,first=obligation_acceptance([self.verdict(0,False,'failed'),self.verdict(1,True,'repair'),self.verdict(2,True,'updated')])
        self.assertEqual(accepted,[True,True,True])
        self.assertEqual(first,['repair','repair','updated'])

    def test_earlier_answer_does_not_answer_a_later_paraphrase(self):
        accepted,first=obligation_acceptance([self.verdict(0,True,'first'),self.verdict(1,False,'paraphrase'),self.verdict(2,True,'updated')])
        self.assertEqual(accepted,[True,False,True])
        self.assertEqual(first,['first',None,'updated'])

    def test_changed_sources_cannot_repair_old_source_obligations(self):
        accepted,first=obligation_acceptance([self.verdict(0,False,'first'),self.verdict(1,False,'paraphrase'),self.verdict(2,True,'updated')])
        self.assertEqual(accepted,[False,False,True])
        self.assertEqual(first,[None,None,'updated'])
