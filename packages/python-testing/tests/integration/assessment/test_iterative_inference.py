# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_testing.assessment_studies import iterative_inference_study as loop
from agentic_ai_lab_testing.assessment_studies import inference_reuse_study as study


class IterativeEvidenceProtocol(unittest.TestCase):
    def test_full_question_reasoning_does_not_force_evidence_first(self):
        for assisted,expected in [(False,['scan']),(True,['scan','query'])]:
            choices=loop.action_format(assisted,initial=True)['schema']['anyOf']
            self.assertEqual([c['properties']['action']['enum'][0] for c in choices],expected)

    def test_raw_sources_cannot_be_relabelled_as_verified_claims(self):
        source=study.workload(0)['source']
        with self.assertRaises(ValueError):
            loop.evidence_program(source,{'contract':{'relations':[],'rules':[]},'queries':['cast']})

    def test_unary_checked_claims_do_not_require_artificial_subproblems(self):
        case=study.workload(0)
        result=loop.evidence_program(case['source'],{'contract':study.oracle_contract(case),'queries':['answer']})
        self.assertEqual(result['queries'],['answer'])

    def test_argument_notation_is_a_typed_protocol_error_with_repair_guidance(self):
        case=study.workload(3);contract=study.oracle_contract(case)
        with self.assertRaisesRegex(ValueError,'bare relation names'):
            loop.evidence_program(case['source'],{'contract':contract,'queries':['reachable(X,Y)']})

    def test_witness_projection_retains_the_model_requested_rule_body(self):
        case=study.workload(0);contract=study.oracle_contract(case)
        body=contract['rules'][0]['body']
        contract['relations']=[{'name':'witness','types':['Actor','Actor','Actor','Film','Director','Country']}]
        contract['rules']=[study.rule(study.atom('witness',*[study.var(n) for n in ('a','b','c','f','d','k')]),*body)]
        program=loop.evidence_program(case['source'],{'contract':contract,'queries':['witness']})
        self.assertEqual(program['rules'][0]['body'],body)
        self.assertEqual(program['queries'],['witness'])


if __name__=='__main__':unittest.main()
