# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Transport/context boundaries only; scheme Scheme grades movie semantics."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).parents[1]/'src'))
from agentic_ai_lab_testing.assessment_studies import movie_study as study
from agentic_ai_lab_testing.assessment_studies.model_study import response_outcome

class MovieRequestBytes(unittest.TestCase):
    def test_incomplete_output_is_not_an_incorrect_answer_or_account_error(self):
        response={'terminal':{'status':'incomplete','error':None,
                             'incomplete_details':{'reason':'max_output_tokens'}},'error':None}
        self.assertEqual(response_outcome(response,False),'output_budget_exhausted')
        response['terminal']={'status':'completed','error':None}
        self.assertEqual(response_outcome(response,False),'answer_mismatch')
        self.assertEqual(response_outcome(response,True),'correct')
        self.assertEqual(response_outcome(response),'completed_ungraded')

    def test_capped_sample_continues_but_provider_failure_stops(self):
        self.assertFalse(study.provider_fatal({'terminal':{'status':'incomplete','incomplete_details':{'reason':'max_output_tokens'}},'error':None}))
        self.assertTrue(study.provider_fatal({'terminal':{'status':'failed'},'error':None}))
        self.assertTrue(study.provider_fatal({'terminal':None,'error':{'type':'TimeoutError'}}))

    def test_env_file_is_data_and_only_provider_key_is_loaded(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/'.env').write_text('UNRELATED=$(false)\nexport DEEPSEEK_API_KEY="fixture-key" # comment\n')
            with patch.object(study, 'ROOT', root), patch.dict(study.os.environ, {'DEEPSEEK_API_KEY': ''}):
                self.assertEqual(study.provider_key(), 'fixture-key')

    def test_versioned_runtime_objects_and_expander_metadata_are_bound(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); (root/'source').write_text('source')
            artifacts = root/'.gerbil/lib/gerbil-ascent/program'; artifacts.mkdir(parents=True)
            for name in ('module.o1', 'module.o8', 'module.ssi', 'module.scm', 'module.ssxi.ss'):
                (artifacts/name).write_text(name)
            with patch.object(study, 'ROOT', root), patch.object(study, 'PRODUCERS', ['source']):
                hashes = study.identities()
                self.assertEqual(len(hashes), 6)
                before = hashes['.gerbil/lib/gerbil-ascent/program/module.o8']
                (artifacts/'module.o8').write_text('changed selected runtime')
                self.assertNotEqual(study.identities()['.gerbil/lib/gerbil-ascent/program/module.o8'], before)

    def test_prepared_simple_fixture_cannot_be_used_as_capability_evidence(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)/'preview'
            cases = [dict(id=family+'-'+variant, family=family, template='x',
                          left='Q1', right='Q2', blocked='Q3', combine='any',
                          exclude_scope='left', expected=[])
                     for family in ('a', 'b', 'c') for variant in ('seed', 'transfer')]
            def scheme_prepare(mode, path):
                self.assertEqual(mode, 'prepare')
                path.write_text(json.dumps({'source': {'cast': []}, 'cases': cases}))
            with patch.object(study, 'scheme', side_effect=scheme_prepare), \
                 patch.object(study, 'identities', return_value={}), \
                 patch.object(study.subprocess, 'check_output', return_value='head\n'):
                study.prepare(output)
            plan = json.loads((output/'plan.json').read_text())
            self.assertEqual(plan['purpose'], 'mechanism-regression')
            self.assertFalse(plan['capabilityEvaluationEligible'])
            self.assertFalse(plan['liveAuthorized'])
            self.assertEqual(plan['providerCallsExecuted'], 0)
            self.assertEqual(len(plan['order']), 9)

    def test_gold_and_expected_are_not_sent_in_either_arm(self):
        case = {'template':'Actors in $left OR $right', 'left':'Q1','right':'Q2','blocked':'Q3',
                'combine':'PRIVATE-GOLD', 'exclude_scope':'PRIVATE-MASK', 'expected':['PRIVATE-ANSWER']}
        for arm in ('baseline','scheme-contract'):
            request=study.request_for({'cast':[]},case,arm)
            text=json.dumps(request)
            self.assertNotIn('PRIVATE-',text)
            self.assertEqual(request['reasoning'],{'effort':'high'})
            self.assertFalse(request['store'])
            self.assertEqual(request['max_output_tokens'],study.MAX_OUTPUT_TOKENS)

    def test_contract_compilation_retains_identity_without_sending_fact_rows(self):
        case={'template':'Actors in $left OR $right','left':'Q1','right':'Q2','blocked':'Q3'}
        source={'cast':[['PRIVATE-FILM-ROW','PRIVATE-ACTOR-ROW']]*90}
        compiler=study.request_for(source,case,'scheme-contract')
        direct=study.request_for(source,case,'baseline')
        text=compiler['input'][0]['content']
        self.assertNotIn('PRIVATE-ACTOR-ROW',text)
        self.assertIn('PRIVATE-ACTOR-ROW',direct['input'][0]['content'])
        context=json.loads(text.split('\n',1)[1])
        self.assertEqual(context['executor']['bindings']['blocked'],'Actor')
        self.assertEqual(context['sourceIdentity'],study.digest(json.dumps(source,ensure_ascii=False,sort_keys=True).encode()))
        other=study.request_for({'cast':[]},case,'scheme-contract')
        self.assertNotEqual(compiler,other)

    def test_unknown_arms_and_oversized_requests_reject_before_transport(self):
        case={'template':'x','left':'Q1','right':'Q2','blocked':'Q3'}
        with self.assertRaises(ValueError):study.request_for({},case,'unknown')
        with self.assertRaises(ValueError):study.request_for({'blob':'x'*32768},case,'baseline')

    def test_source_and_request_byte_changes_invalidate_prepared_reuse(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp);data=b'original';(p/'request.json').write_bytes(data)
            plan={'producerHashes':{'source':'first'},'order':[{'request':'request.json','sha256':study.digest(data)}]}
            (p/'plan.json').write_text(json.dumps(plan))
            with patch.object(study,'identities',return_value={'source':'second'}):
                with self.assertRaises(ValueError):study.validate(p)
            with patch.object(study,'identities',return_value={'source':'first'}):
                study.validate(p)
                (p/'request.json').write_bytes(b'changed')
                with self.assertRaises(ValueError):study.validate(p)

    def test_paid_continuation_rejects_changed_producers_and_nonprefix_ledger(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);preview=root/'preview';preview.mkdir();output=root/'output';output.mkdir()
            (root/'producer').write_bytes(b'original')
            data=json.dumps({'model':'deepseek-flash','max_output_tokens':4096}).encode()
            (preview/'request.json').write_bytes(data)
            order=[{'id':str(i),'arm':'baseline','request':'request.json','sha256':study.digest(data)} for i in range(9)]
            plan={'producerHashes':{'producer':study.digest(b'original')},'order':order,
                  'purpose':'mechanism-regression','capabilityEvaluationEligible':False,
                  'retries':0,'conservativeScheduledUpperUsd':0.1,'maxOutputTokens':4096}
            (preview/'plan.json').write_text(json.dumps(plan))
            (output/'calls.jsonl').write_text(json.dumps(order[0])+'\n')
            self.assertEqual(len(study.continuation_plan(preview,output,root)[1]),1)
            (output/'calls.jsonl').write_text(json.dumps(order[1])+'\n')
            with self.assertRaises(ValueError):study.continuation_plan(preview,output,root)
            (output/'calls.jsonl').write_text(json.dumps(order[0])+'\n')
            (root/'producer').write_bytes(b'drift')
            with self.assertRaises(ValueError):study.continuation_plan(preview,output,root)

if __name__=='__main__':unittest.main()
