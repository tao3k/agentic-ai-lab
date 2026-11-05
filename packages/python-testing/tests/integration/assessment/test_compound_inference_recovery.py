# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_testing.assessment_studies.compound_inference_recovery import censored_episodes
from agentic_ai_lab_testing.assessment_studies.inference_effort import until_verified


class CompoundRecoveryAudit(unittest.TestCase):
    def test_recovery_selects_every_censored_arm_without_rewriting_primary(self):
        passed={'effort':{'verified':True},'arm':'scheme-evidence'}
        raw={'effort':{'verified':False},'arm':'raw-fact-reasoning'}
        assisted={'effort':{'verified':False},'arm':'scheme-evidence'}
        receipt={'pairs':[],'episodes':[passed,raw,assisted]}
        self.assertEqual(censored_episodes(receipt),[raw,assisted])
        self.assertFalse(raw['effort']['verified'])
        with self.assertRaises(ValueError):censored_episodes({'episodes':[raw]})

    def test_higher_ceiling_recovery_charges_original_exhaustion(self):
        def a(correct,tokens,adaptive=False):
            return {'providerCalls':1,'correct':correct,'adaptive':adaptive,'usage':{
                'input_tokens':10,'output_tokens':tokens,'output_tokens_details':{'reasoning_tokens':tokens}}}
        primary=[a(False,65536)];continued=until_verified(primary+[a(True,12000,True)])
        self.assertEqual(continued['observedReasoningTokens'],77536)
        self.assertEqual(continued['modelCalls'],2)
        self.assertTrue(continued['adaptive']);self.assertFalse(primary[0]['correct'])


if __name__=='__main__':unittest.main()
