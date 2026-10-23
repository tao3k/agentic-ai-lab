# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import hashlib
import importlib.util
import copy
import json
import unittest
import subprocess
import sys
import tempfile
from agentic_ai_lab_testing.assessment_studies import complex_movie_study as study
from agentic_ai_lab_testing.assessment_studies.query_contract import compact_request

class ComplexMovieProtocol(unittest.TestCase):
    def setUp(self): self.source=json.loads(study.FIXTURE.read_text())
    def test_all_arms_share_question_and_raw_evidence_without_private_gold(self):
        case=study.cases()[0]
        views={'eligible':[['Q145','Q25188','Q25191','Q38111']],'coactor':[]}
        contexts=[json.loads(study.request(self.source,case,arm,views if arm=='reuse' else None)
                             ['input'][0]['content'].split('\n',1)[1]) for arm in ('direct','execute','reuse')]
        for ctx in contexts:
            self.assertEqual(ctx['facts'],self.source['rows']);self.assertEqual(ctx['question'],case['question'])
            self.assertNotIn('gold',ctx);self.assertNotIn('expected',ctx)
        self.assertNotIn('materializedViews',contexts[1]);self.assertEqual(contexts[2]['materializedViews'],views)
    def test_model_cannot_write_source_or_materialized_heads(self):
        for name in ('cast','directed','citizen','anchor','omitted_film','blocked'):
            with self.assertRaises(ValueError):
                study.program(self.source,{'relations':[],'rules':[study.rule(study.atom(name))]})
        with self.assertRaises(ValueError):
            study.program(self.source,study.view_contract(),{'eligible':[],'coactor':[]})

    def test_source_withdrawal_changes_identity_without_mutating_frozen_facts(self):
        before=copy.deepcopy(self.source);case=study.cases()[-2]
        current=study.source_for(self.source,case)
        self.assertNotIn(case['withdrawal'],current['rows']['cast'])
        self.assertNotEqual(study.identity(current),study.identity(self.source));self.assertEqual(self.source,before)
    def test_compact_intent_keeps_bindings_without_enumerating_source_or_answers(self):
        case=study.cases('country-qualified')[0]
        request=study.request(self.source,case,'reuse',{'eligible':[],'coactor':[]})
        frozen=copy.deepcopy(request);sid=study.identity(self.source)
        result=compact_request(request,sid)
        ctx=json.loads(result['input'][0]['content'].split('\n',1)[1])
        self.assertEqual(request,frozen);self.assertEqual(ctx['question'],case['question'])
        self.assertEqual(ctx['bindings']['rightCountry'],'Q96');self.assertEqual(ctx['sourceIdentity'],sid)
        for name in ('facts','domains','materializedViews','gold','expected'):self.assertNotIn(name,ctx)
        self.assertIn('directed(f,d)',ctx['viewDefinitions']['eligible'])
    def test_finite_views_and_withdrawals_through_real_scheme(self):
        with tempfile.TemporaryDirectory() as directory:
            output=study.Path(directory)/'result.json'
            library=study.Path(importlib.util.find_spec('ascent._core').origin)
            subprocess.run([sys.executable,'-u','-m','agentic_ai_lab_testing.assessment_studies.complex_movie_study','qualify',
                            str(study.FIXTURE.parent/'conformance.json'),str(library),str(output)],check=True)
            receipt=json.loads(output.read_text())
            self.assertEqual(receipt['librarySha256'], hashlib.sha256(library.read_bytes()).hexdigest())
            self.assertEqual(receipt['observations'],3072)
            self.assertEqual(len(receipt['faultControlsDetected']),3)

    def test_model_cannot_replace_trusted_source_declarations(self):
        for name in ('cast','eligible','coactor','answer'):
            with self.assertRaises(ValueError):
                study.program(self.source,{'relations':[{'name':name,'types':['Actor']}],'rules':[]})

if __name__=='__main__': unittest.main()
