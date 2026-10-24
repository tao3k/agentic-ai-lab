# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import copy
import os
import unittest
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime, ReasoningError
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import EvidenceOperation, EvidenceInteraction, EvidenceConversation
from agentic_ai_lab_runtime.reasoning import Trajectory


def fixture():
    source={'name':'edge','source':True,'columns':[{'kind':'symbol'},{'kind':'symbol'}], 'rows':[['A','D'],['D','E']]}
    derived={'name':'path','source':False,'columns':copy.deepcopy(source['columns']),'rows':[]}
    def atom(n,*xs):return {'relation':n,'terms':[{'var':x} for x in xs]}
    program={'relations':[source,derived],'rules':[
        {'head':[atom('path','x','y')],'body':[atom('edge','x','y')]},
        {'head':[atom('path','x','z')],'body':[atom('path','x','y'),atom('edge','y','z')]}], 'queries':['path']}
    return [source], {'connected':EvidenceOperation(program,'path','Directed reachability [from,to]',True),
                      'open_connected':EvidenceOperation(program,'path','Positive support [from,to]',False)}


class InteractionIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.engine=ReasoningRuntime()
    @classmethod
    def tearDownClass(cls):cls.engine.close()
    def test_local_checks_preserve_unknown_and_source_bound_reuse(self):
        sources,operations=fixture()
        with Trajectory(self.engine,'branching',identity(sources)) as ledger:
            with EvidenceInteraction(self.engine,sources,operations,trajectory=ledger) as tools:
                ledger.model_call('first',1,{'input_tokens':2,'output_tokens':10,'output_tokens_details':{'reasoning_tokens':8}})
                first=tools.check([{'id':'via-D','operation':'connected','arguments':['A','E']},
                                   {'id':'via-B','operation':'connected','arguments':['A','B']},
                                   {'id':'via-H','operation':'open_connected','arguments':['A','H']}],model_call='first')
                self.assertEqual([b['status'] for b in first['branches']],['supported','contradicted','unknown'])
                self.assertFalse(first['taskCorrectnessCertified'])
                ref=first['branches'][0]['reference']
                again=tools.check([{'id':'continue-D','operation':'connected','arguments':['A','E'],'reference':ref}],model_call='first')
                self.assertTrue(again['branches'][0]['reusedComponents'])
                self.assertFalse(ledger.snapshot()['verified'])
                changed=copy.deepcopy(sources);changed[0]['rows']=[['A','B']]
                tools.replace(changed)
                ledger.model_call('second',1,{'input_tokens':2,'output_tokens':3,'output_tokens_details':{'reasoning_tokens':1}})
                stale=tools.check([{'id':'old','operation':'connected','arguments':['A','E'],'reference':ref}],model_call='second')
                self.assertEqual(stale['branches'][0]['status'],'unknown')
                new=tools.check([{'id':'fresh','operation':'connected','arguments':['A','B']}],model_call='second')
                self.assertEqual(new['branches'][0]['status'],'supported')
                self.assertFalse(new['branches'][0]['reusedComponents'])
                ledger.verify(True,'independent-whole-task-test')
                self.assertEqual(ledger.snapshot()['completedEpochs'][0]['totals']['thinkingTokens'],8)

    def test_fresh_control_does_not_admit_retained_components(self):
        sources,ops=fixture()
        with EvidenceInteraction(self.engine,sources,ops,retain=False) as tools:
            for _ in range(2):
                result=tools.check([{'id':'a','operation':'connected','arguments':['A','E']}],model_call='none')
                self.assertEqual(result['branches'][0]['status'],'supported')
                self.assertFalse(result['branches'][0]['reusedComponents'])

    def test_unknown_and_mismatched_requests_do_not_become_proofs(self):
        sources,ops=fixture()
        with EvidenceInteraction(self.engine,sources,ops) as tools:
            ref=tools.check([{'id':'x','operation':'connected','arguments':['A','E']}],model_call='none')['branches'][0]['reference']
            result=tools.check([{'id':'wrong','operation':'connected','arguments':['A','B'],'reference':ref},
                               {'id':'unimplemented','operation':'infer_everything','arguments':[]}],model_call='none')
            self.assertEqual([b['status'] for b in result['branches']],['unknown','unknown'])
            with self.assertRaises(ValueError):tools.check([{'id':'x'},{'id':'x'}],model_call='none')

    def test_checkpoint_rejects_unknown_negation_and_unobserved_calls_atomically(self):
        with Trajectory(self.engine,'atomic-checkpoint','source') as ledger:
            with self.assertRaises(ReasoningError):ledger.checkpoint('missing',[{'id':'x','status':'unknown'}])
            ledger.model_call('real',1,{'input_tokens':1,'output_tokens':1,'output_tokens_details':{'reasoning_tokens':0}})
            ledger.evidence({'sourceIdentity':'source','resultReference':'ref','pathIdentity':'path',
                             'reusedComponents':[],'freshComponents':[],'retainedCompleted':False})
            before=ledger.snapshot()['eventCount']
            with self.assertRaises(ReasoningError):ledger.checkpoint('real',[{'id':'x','status':'contradicted','complete':False,'resultReference':'ref'}])
            with self.assertRaises(ReasoningError):ledger.checkpoint('real',[{'id':'x','status':'supported','resultReference':'missing'}])
            self.assertEqual(ledger.snapshot()['eventCount'],before)
            ledger.checkpoint('real',[{'id':'x','status':'unknown'}])
            self.assertFalse(ledger.snapshot()['verified'])

    def test_conversation_pairs_first_round_tools_and_preserves_reasoning(self):
        import json
        sources,ops=fixture()
        with Trajectory(self.engine,'conversation',identity(sources)) as ledger:
            with EvidenceInteraction(self.engine,sources,ops,trajectory=ledger) as tools:
                conversation=EvidenceConversation('Explore paths from A.',tools)
                response={'status':'completed','usage':{'input_tokens':10,'output_tokens':9,'output_tokens_details':{'reasoning_tokens':7}},
                          'output':[{'type':'reasoning','id':'reason','summary':[]},
                                    {'type':'function_call','call_id':'tool-first','name':'check_branches',
                                     'arguments':json.dumps({'branches':[{'id':'D','operation':'connected','arguments':['A','E']}]})}]}
                feedback=conversation.accept(response,call_id='first',round=1)
                self.assertEqual(feedback[0]['feedback']['branches'][0]['status'],'supported')
                items=conversation.history.input()
                self.assertEqual(items[1]['type'],'reasoning')
                self.assertEqual(items[-1]['type'],'function_call_output')
                self.assertEqual(ledger.snapshot()['totals']['thinkingTokens'],7)
                self.assertFalse(ledger.snapshot()['verified'])

    def test_full_candidate_batch_does_not_open_one_session_per_branch(self):
        sources,ops=fixture()
        with EvidenceInteraction(self.engine,sources,ops) as tools:
            branches=[{'id':str(i),'operation':'connected','arguments':['A','E' if i%2 else 'B']} for i in range(128)]
            for _ in range(2):
                result=tools.check(branches,model_call='none')
                self.assertEqual(sum(b['status']=='supported' for b in result['branches']),64)
                self.assertEqual(sum(b['status']=='contradicted' for b in result['branches']),64)
                self.assertEqual(len({b['resultReference'] for b in result['branches']}),1)

    def test_model_declared_path_requires_every_condition_and_current_support(self):
        sources,ops=fixture()
        def cond(op,*args):return {'operation':op,'arguments':list(args)}
        with EvidenceInteraction(self.engine,sources,ops) as tools:
            good={'id':'A-D-E','conditions':[cond('connected','A','D'),cond('connected','D','E')]}
            bad={'id':'A-B-E','conditions':[cond('connected','A','B'),cond('connected','D','E')]}
            unknown={'id':'A-H-E','conditions':[cond('open_connected','A','H'),cond('connected','D','E')]}
            first=tools.check([good,bad,unknown],model_call='none')
            self.assertEqual([b['status'] for b in first['branches']],['supported','contradicted','unknown'])
            reference=first['branches'][0]['reference']
            again=tools.check([{**good,'reference':reference}],model_call='none')
            self.assertEqual(again['branches'][0]['status'],'supported')
            self.assertTrue(again['branches'][0]['reusedComponents'])
            changed=copy.deepcopy(sources);changed[0]['rows']=[['A','D']]
            tools.replace(changed)
            self.assertEqual(tools.check([{**good,'reference':reference}],model_call='none')['branches'][0]['status'],'unknown')
            self.assertEqual(tools.check([good],model_call='none')['branches'][0]['status'],'contradicted')

    def test_reuse_and_extension_recheck_the_same_path_without_retyping(self):
        sources,ops=fixture()
        with EvidenceInteraction(self.engine,sources,ops) as tools:
            first=tools.check([{'id':'via-D','conditions':[{'operation':'connected','arguments':['A','D']}]}],model_call='none')
            reference=first['branches'][0]['reference']
            same=tools.reuse([reference],model_call='none')
            self.assertEqual(same['branches'][0]['status'],'supported')
            extension=tools.extend([{'id':'via-D-E','reference':reference,'conditions':[{'operation':'connected','arguments':['D','E']}]}],model_call='none')
            self.assertEqual(extension['branches'][0]['status'],'supported')
            self.assertEqual(len(extension['branches'][0]['conditions']),2)
            wrong=tools.extend([{'id':'via-D-H','reference':reference,'conditions':[{'operation':'connected','arguments':['D','H']}]}],model_call='none')
            self.assertEqual(wrong['branches'][0]['status'],'contradicted')
            changed=copy.deepcopy(sources);changed[0]['rows']=[['A','D']]
            tools.replace(changed)
            self.assertEqual(tools.reuse([reference],model_call='none')['branches'][0]['status'],'unknown')
            self.assertEqual(tools.extend([{'id':'stale','reference':reference,'conditions':[{'operation':'connected','arguments':['D','E']}]}],model_call='none')['branches'][0]['status'],'unknown')
            new=tools.check([{'id':'fresh','conditions':[{'operation':'connected','arguments':['A','D']}]}],model_call='none')
            self.assertNotEqual(new['branches'][0]['reference'],reference)


if __name__=='__main__':unittest.main()
