# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_testing.assessment_studies.trajectory_study import task, extract, closure
from agentic_ai_lab_testing.assessment_studies.trajectory_transfer_study import followup


class TrajectoryStudyIntent(unittest.TestCase):
    def test_answer_parser_accepts_explanation_fences_and_final_object(self):
        self.assertEqual(extract('Reasoning: {"note": 1}\n```json\n{"answer": ["b", "a"]}\n```'),['a','b'])
        self.assertEqual(extract('{"answer": ["wrong"]}\nFINAL_JSON: {"answer": ["right"]}'),['right'])
        self.assertIsNone(extract('{"answer": [1]}'))
        self.assertIsNone(extract('No complete answer'))

    def test_generated_questions_are_deterministic_and_entity_disjoint(self):
        first=task(0,2026101300);second=task(0,2026101301)
        self.assertEqual(first,task(0,2026101300))
        self.assertNotEqual(first['gold'],second['gold'])
        self.assertGreater(first['complexity']['edges'],100)
        self.assertNotIn('gold',first['question'])

    def test_negative_and_conjunctive_mutations_change_independent_gold(self):
        case=task(2,2026101334)
        sources={r['name']:r['rows'] for r in case['sources']}
        reached=closure(sources['edge'],[r[0] for r in sources['start']],{r[0] for r in sources['blocked']})
        deferred={r[0] for r in sources['deferred']}
        wrong=sorted(job for job,a,b in sources['needs'] if (a in reached or b in reached) and job not in deferred)
        self.assertNotEqual(wrong,case['gold'])
        self.assertNotEqual(closure([['a','b'],['b','c']],["a"],{'b'}),closure([['a','b'],['b','c']],["a"],set()))

    def test_followup_scopes_blocked_to_closure_not_positive_join(self):
        # A blocked terminal can be a positive join witness while remaining
        # excluded from the recursive closure. Confusing these scopes loses a.
        case=task(0,2026102300)
        case['sources']=[{'name':name,'rows':rows} for name,rows in
                         [('edge',[['a','b'],['b','c']]),('start',[['a']]),
                          ('blocked',[['c']]),('target',[['a']])]]
        self.assertEqual(followup(case)[1],['a'])
        next(r for r in case['sources'] if r['name']=='blocked')['rows']=[['b']]
        self.assertEqual(followup(case)[1],[])
