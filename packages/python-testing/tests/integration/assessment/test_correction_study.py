# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import json
import unittest
from agentic_ai_lab_testing.assessment_studies.correction_study import corpus, holdout_corpus
from agentic_ai_lab_testing.assessment_studies.trajectory_study import closure


class CorrectionStudyIntent(unittest.TestCase):
    def test_holdout_job_identifiers_do_not_encode_construction_order(self):
        cases=holdout_corpus()
        self.assertEqual(cases,holdout_corpus())
        for case in cases:
            jobs=[r[0] for r in next(s for s in case['sources'] if s['name']=='needs')['rows']]
            self.assertEqual(len(jobs),len(set(jobs)))
            self.assertTrue(all(j.startswith('job_') and len(j)==16 for j in jobs))
            self.assertNotIn('gold',case['question'])
            self.assertTrue(all(set(gold)<=set(jobs) for gold in case['gold']))
        self.assertEqual(cases[-1]['complexity']['contexts'],4)
        self.assertEqual(cases[-1]['complexity']['requests'],160)

    def test_frozen_instances_are_repeatable_json_sources_and_nontrivial(self):
        first=corpus();self.assertEqual(first,corpus())
        self.assertEqual(first,json.loads(json.dumps(first)))
        self.assertEqual(len({c['case'] for c in first}),4)
        for case in first:
            self.assertEqual(case['complexity']['requests'],96)
            self.assertGreater(case['complexity']['oracleRounds'],5)
            self.assertTrue(all(0<len(g)<96 for g in case['gold']))
            self.assertNotIn('gold',case['question'])
            self.assertNotEqual(case['gold'][0],case['gold'][1])

    def test_balanced_oracle_detects_unmatched_path_shortcut(self):
        for case in corpus()[2:]:
            sources={r['name']:r['rows'] for r in case['sources']}
            edges={(x,y) for name in ['opening','closing'] for x,y,k in sources[name]}|set(map(tuple,sources['epsilon']))
            nodes={x for pair in edges for x in pair}
            ordinary={x:closure(edges,[x],set()) for x in nodes}
            excluded={r[0] for r in sources['excluded']}
            wrong=sorted(j for j,c,x,y,d,u,v in sources['needs'] if y in ordinary[x] and v in ordinary[u] and j not in excluded)
            self.assertNotEqual(wrong,case['gold'][0])
