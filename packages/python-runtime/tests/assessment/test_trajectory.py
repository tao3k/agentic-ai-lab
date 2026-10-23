# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import os
import unittest
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime, ReasoningError
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import EvidenceChain, evidence_graph
from agentic_ai_lab_runtime.reasoning import identity


def relation(name, source, rows=()):
    return {'name':name,'source':source,'columns':[{'kind':'symbol'}],'rows':list(rows)}

def atom(name):
    return {'relation':name,'terms':[{'var':'x'}]}


class TrajectoryIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = ReasoningRuntime(os.environ['ASCENT_ENGINE_LIBRARY']) if os.environ.get('ASCENT_ENGINE_BACKEND') == 'abi' else ReasoningRuntime()

    @classmethod
    def tearDownClass(cls):
        cls.engine.close()

    def test_progressive_brief_does_not_replay_attempts(self):
        with Trajectory(self.engine, 'progressive', 'source-a') as trajectory:
            first = trajectory.brief()
            self.assertEqual(first['readSurfaces'],
                             ['context', 'explore', 'focus', 'exact-prefix', 'snapshot'])
            self.assertEqual(first['status'], 'unread')
            self.assertEqual(first['changeKinds'], [])
            self.assertNotIn('attempts', first)
            self.assertNotIn('comparisons', first)
            self.assertNotIn('currentEvidenceReference', first)
            self.assertTrue(trajectory.exploration_current(first))

            unchanged = trajectory.brief(first)
            self.assertEqual(unchanged['status'], 'unchanged')
            self.assertEqual(unchanged['changeKinds'], [])
            trajectory.append('attempt', questionIdentity='question',
                              operationIdentity='probe', inputIdentity='input')
            self.assertFalse(trajectory.exploration_current(first))
            changed = trajectory.brief(first)
            self.assertEqual(changed['status'], 'changed')
            self.assertEqual(changed['changeKinds'], ['attempt'])
            self.assertNotIn('attempts', changed)
            self.assertEqual(len(trajectory.context()['attempts']), 1)
            self.assertEqual(len(trajectory.explore(dict(questionIdentity='question',
                operationIdentity='probe', inputIdentity='input'))['comparisons']), 1)

            trajectory.invalidate('source-b')
            replaced = trajectory.brief(changed)
            self.assertEqual(replaced['status'], 'changed')
            self.assertIn('source-replacement', replaced['changeKinds'])
            with self.assertRaises(ReasoningError):
                trajectory.brief(dict(changed, prefixIdentity='different-content'))
            with Trajectory(self.engine, 'foreign', 'source-b') as foreign:
                with self.assertRaises(ReasoningError):
                    foreign.brief(changed)

    def test_progressive_focus_and_exact_prefix(self):
        with Trajectory(self.engine, 'focused', 'source-a') as trajectory:
            candidate = dict(questionIdentity='q', operationIdentity='probe',
                             inputIdentity='input')
            first = trajectory.focus(candidate)
            trajectory.append('attempt', questionIdentity='other',
                              operationIdentity='probe', inputIdentity='input')
            unchanged = trajectory.focus(candidate, first)
            self.assertEqual(unchanged['status'], 'unchanged')
            self.assertEqual(unchanged['comparisons'], [])
            trajectory.append('attempt', questionIdentity='q',
                              operationIdentity='probe', inputIdentity='input')
            changed = trajectory.focus(candidate, unchanged)
            self.assertEqual(changed['status'], 'changed')
            self.assertEqual(len(changed['comparisons']), 1)
            exact = trajectory.exact_prefix(changed['eventCount'], changed['prefixIdentity'])
            self.assertEqual(len(exact['events']), 2)
            self.assertFalse(exact['executionAuthorized'])
            with self.assertRaises(ReasoningError):
                trajectory.exact_prefix(changed['eventCount'], 'wrong')
            with self.assertRaises(ReasoningError):
                trajectory.focus(dict(candidate, questionIdentity='other'), changed)
            trajectory.invalidate('source-b')
            historical = trajectory.exact_prefix(changed['eventCount'],
                                                 changed['prefixIdentity'])
            self.assertEqual(historical['sourceIdentity'], 'source-a')
            self.assertEqual(historical['generation'], 0)
            self.assertFalse(trajectory.exploration_current(historical))

    def test_exploration_packet_preserves_open_choice_and_source_history(self):
        with Trajectory(self.engine, 'exploration', 'source-a') as trajectory:
            before = trajectory.snapshot()['eventCount']
            trajectory.append('attempt', questionIdentity='question', scopeIdentity='scope',
                              operationIdentity='test', inputIdentity='input-a',
                              toolIdentity='tool', modelIdentity='model', purpose='first probe')
            candidate = dict(questionIdentity='question', scopeIdentity='scope',
                             operationIdentity='test', inputIdentity='input-a',
                             toolIdentity='tool', modelIdentity='model')
            context = trajectory.context()
            self.assertTrue(trajectory.exploration_current(context))
            self.assertEqual(set(context), {'schema', 'sourceIdentity', 'generation',
                                            'eventCount', 'prefixIdentity', 'ownerIdentity', 'attempts',
                                            'executionAuthorized', 'actionSelected'})
            self.assertEqual(len(context['prefixIdentity']), 64)
            self.assertFalse(trajectory.exploration_current(
                dict(context, prefixIdentity='different-content')))
            self.assertEqual(context['attempts'][0]['earlierEvent'], 'event:1')
            self.assertNotIn('resultReference', context['attempts'][0])
            self.assertFalse(context['actionSelected'])
            packet = trajectory.explore(candidate)
            self.assertEqual(set(packet), {'schema', 'sourceIdentity', 'generation',
                                           'eventCount', 'prefixIdentity', 'ownerIdentity', 'comparisons',
                                           'executionAuthorized', 'actionSelected'})
            self.assertEqual(packet['prefixIdentity'], context['prefixIdentity'])
            self.assertEqual(set(packet['comparisons'][0]),
                             {'earlierEvent', 'relation', 'changedPremises',
                              'unknownPremises', 'currentEvidenceReference'})
            self.assertFalse(packet['executionAuthorized'])
            self.assertFalse(packet['actionSelected'])
            self.assertEqual(packet['comparisons'][0]['relation'], 'exact-current')
            self.assertEqual(trajectory.snapshot()['eventCount'], before + 1)
            incomplete = dict(candidate)
            del incomplete['toolIdentity']
            self.assertEqual(trajectory.explore(incomplete)['comparisons'][0]['relation'],
                             'comparison-unknown')
            changed = dict(candidate, inputIdentity='input-b')
            self.assertEqual(trajectory.explore(changed)['comparisons'][0]['relation'],
                             'changed-premise')
            trajectory.invalidate('source-b')
            self.assertFalse(trajectory.exploration_current(context))
            self.assertTrue(trajectory.context()['attempts'][0]['historical'])
            self.assertEqual(trajectory.explore(candidate)['comparisons'][0]['relation'],
                             'historical')

    def test_exploration_result_is_withheld_until_bound_review_and_revoked_on_failure(self):
        with Trajectory(self.engine, 'reviewed-exploration', 'source') as trajectory:
            trajectory.append('evidence', resultReference='result', pathIdentity='path')
            trajectory.append('attempt', questionIdentity='question',
                              operationIdentity='test', inputIdentity='input',
                              resultReference='result', contractIdentity='contract')
            candidate = dict(questionIdentity='question', operationIdentity='test',
                             inputIdentity='input', contractIdentity='contract')
            def reference():
                return trajectory.explore(candidate)['comparisons'][0]['currentEvidenceReference']
            self.assertFalse(reference())
            trajectory.append('consumption', consumedReference='result',
                              resultReference='result', intentIdentity='intent',
                              contractIdentity='contract')
            self.assertFalse(reference())
            trajectory.verify(True, 'independent-check', consumption_reference='result')
            self.assertEqual(reference(), 'result')
            reviewed_packet = trajectory.explore(candidate)
            self.assertTrue(trajectory.exploration_current(reviewed_packet))
            self.assertFalse(trajectory.explore(dict(candidate, contractIdentity='other'))
                             ['comparisons'][0]['currentEvidenceReference'])
            trajectory.verify(False, 'independent-check', consumption_reference='result')
            self.assertFalse(reference())
            self.assertFalse(trajectory.exploration_current(reviewed_packet))

    def test_exploration_uses_real_evidence_chain_and_revokes_on_replace(self):
        sources = [relation('input', True, [['a']])]
        proof = {'relations': sources + [relation('proof', False)],
                 'rules': [{'head': [atom('proof')], 'body': [atom('input')]}],
                 'queries': ['proof']}
        contract = {'relations': sources + [relation('proof', False), relation('answer', False)],
                    'rules': proof['rules'] + [{'head': [atom('answer')],
                                                'body': [atom('proof')]}],
                    'queries': ['answer']}
        with Trajectory(self.engine, 'generic-exploration', identity(sources)) as trajectory:
            with EvidenceChain(self.engine, sources, trajectory=trajectory) as chain:
                prior = chain.query(proof)
                accepted = chain.consume(prior['resultReference'], contract, contract)
                self.assertTrue(accepted['accepted'])
                candidate = dict(questionIdentity='answer', operationIdentity='query',
                                 inputIdentity=chain.source_identity,
                                 contractIdentity=accepted['contractIdentity'])
                trajectory.append('attempt', **candidate,
                                  resultReference=accepted['resultReference'])
                self.assertFalse(trajectory.explore(candidate)['comparisons'][0]
                                 ['currentEvidenceReference'])
                trajectory.verify(True, 'independent-answer-check',
                                  consumption_reference=accepted['resultReference'])
                packet = trajectory.explore(candidate)
                self.assertEqual(packet['comparisons'][0]['currentEvidenceReference'],
                                 accepted['resultReference'])
                self.assertTrue(trajectory.exploration_current(packet))
                chain.replace([relation('input', True, [['b']])])
                self.assertFalse(trajectory.exploration_current(packet))
                self.assertEqual(trajectory.explore(candidate)['comparisons'][0]['relation'],
                                 'historical')

    def test_consumption_accepts_alpha_and_conjunct_order_and_rejects_weakened_intent(self):
        import copy
        sources=[relation('input',True,[['a'],['b']]),relation('blocked',True,[['b']])]
        base={'relations':sources+[relation('proof',False)],
              'rules':[{'head':[atom('proof')],'body':[atom('input')]}],'queries':['proof']}
        contract=copy.deepcopy(base);contract['relations'].append(relation('answer',False))
        contract['rules'].append({'head':[atom('answer')],'body':[atom('proof'),dict(atom('blocked'),not_=True)]})
        contract['rules'][-1]['body'][-1].pop('not_');contract['rules'][-1]['body'][-1]['not']=True
        contract['queries']=['answer']
        with Trajectory(self.engine,'consume',identity(sources)) as trajectory:
            with EvidenceChain(self.engine,sources,trajectory=trajectory) as chain:
                prior=chain.query(base)
                with self.assertRaises(ReasoningError):
                    trajectory.verify(True,'test',consumption_reference=prior['resultReference'])
                wrong=copy.deepcopy(contract);wrong['rules'][-1]['body'].pop()
                before=trajectory.snapshot()['eventCount']
                rejected=chain.consume(prior['resultReference'],wrong,contract)
                self.assertFalse(rejected['accepted'])
                self.assertEqual(trajectory.snapshot()['eventCount'],before)
                self.assertTrue(rejected['diagnostic']['requiredPredicateSignatures'])
                candidate=copy.deepcopy(contract);candidate['rules'][-1]['body'].reverse()
                for a in candidate['rules'][-1]['head']+candidate['rules'][-1]['body']:
                    a['terms'][0]['var']='renamed'
                accepted=chain.consume(prior['resultReference'],candidate,contract)
                self.assertTrue(accepted['accepted']);self.assertTrue(accepted['reusedComponents'])
                self.assertEqual(chain.answer(accepted['resultReference'],'answer'),[['a']])
                trajectory.verify(True,'test',consumption_reference=accepted['resultReference'])
                chain.replace([relation('input',True,[['c']]),relation('blocked',True,[])])
                with self.assertRaises(ValueError):chain.consume(prior['resultReference'],candidate,contract)
                with self.assertRaises(ReasoningError):
                    trajectory.verify(True,'test',consumption_reference=accepted['resultReference'])

    def test_consumption_rejects_accidentally_equal_answers_with_wrong_variable_join(self):
        import copy
        sources=[relation('input',True,[])]
        base={'relations':sources+[relation('proof',False)],'rules':[{'head':[atom('proof')],'body':[atom('input')]}],'queries':['proof']}
        contract=copy.deepcopy(base);contract['relations'].append(relation('answer',False))
        contract['rules'].append({'head':[atom('answer')],'body':[atom('proof'),atom('input')]});contract['queries']=['answer']
        candidate=copy.deepcopy(contract);candidate['rules'][-1]['body'][-1]['terms'][0]['var']='unrelated'
        with EvidenceChain(self.engine,sources) as chain:
            prior=chain.query(base)
            self.assertFalse(chain.consume(prior['resultReference'],candidate,contract)['accepted'])

    def test_cost_freeze_repair_unknown_usage_and_close(self):
        with Trajectory(self.engine,'repair','source') as trajectory:
            trajectory.model_call('initial',1,{'input_tokens':100,'output_tokens':90,'output_tokens_details':{'reasoning_tokens':80}})
            trajectory.verify(False,'independent-oracle',round=1)
            trajectory.model_call('repair',2,{'input_tokens':160,'output_tokens':40,'output_tokens_details':{'reasoning_tokens':30}})
            trajectory.verify(True,'independent-oracle',round=2)
            trajectory.model_call('post-success',3,{'input_tokens':10,'output_tokens':60,'output_tokens_details':{'reasoning_tokens':50}})
            result=trajectory.snapshot()
            self.assertEqual(result['throughFirstCorrect']['thinkingTokens'],110)
            self.assertEqual(result['throughFirstCorrect']['repairThinkingTokens'],30)
            self.assertEqual(result['postSuccess']['thinkingTokens'],50)
            self.assertEqual(result['throughFirstCorrect']['modelCalls'],2)
        self.assertTrue(trajectory.closed['closed'])
        with self.assertRaises(ValueError):trajectory.model_call('closed',4)
        with Trajectory(self.engine,'missing','source') as unknown:
            unknown.model_call('rejected-request',1)
            result=unknown.close('provider-error')
            self.assertEqual(result['totals']['modelCalls'],1)
            self.assertFalse(result['totals']['thinkingComplete'])
            self.assertTrue(result['censored'])

    def test_real_dag_reuse_direct_answer_and_replacement_share_one_trajectory(self):
        sources=[relation('input',True,[['a']])]
        program={'relations':sources+[relation('answer',False)],
                 'rules':[{'head':[atom('answer')],'body':[atom('input')]}], 'queries':['answer']}
        with Trajectory(self.engine,'session-reuse',identity(sources)) as trajectory:
            with EvidenceChain(self.engine,sources,trajectory=trajectory) as chain:
                first=chain.query(program)
                self.assertEqual(chain.answer(first['resultReference'],'answer'),[['a']])
                trajectory.verify(True,'native-test-oracle')
                second=chain.query(program)
                self.assertTrue(second['retainedCompleted'])
                self.assertEqual(chain.answer(second['resultReference'],'answer'),[['a']])
                graph=evidence_graph(program)
                self.assertEqual(len(graph['edges']),1)
                chain.replace([relation('input',True,[['b']])])
                with self.assertRaises(ValueError):chain.answer(first['resultReference'],'answer')
                with self.assertRaises(ReasoningError):trajectory.direct_answer(first['resultReference'])
                program['relations'][0]=relation('input',True,[['b']])
                fresh=chain.query(program)
                self.assertFalse(fresh['reusedComponents'])
                self.assertEqual(chain.answer(fresh['resultReference'],'answer'),[['b']])
                trajectory.verify(True,'native-test-oracle')
            result=trajectory.snapshot()
            self.assertEqual(result['generation'],1)
            self.assertEqual(len(result['completedEpochs']),1)
            self.assertEqual(result['throughFirstCorrect']['modelCalls'],0)
            self.assertEqual(result['completedEpochs'][0]['totals']['directAnswers'],2)
            self.assertTrue(any(event.get('retainedCompleted') for event in result['events']))

    def test_bad_event_cannot_partially_charge_or_overwrite_first_success(self):
        with Trajectory(self.engine,'atomic','source') as trajectory:
            with self.assertRaises(ReasoningError):trajectory.model_call('negative',1,{'input_tokens':-1,'output_tokens':1})
            self.assertEqual(trajectory.snapshot()['eventCount'],0)
            trajectory.model_call('valid',1,{'input_tokens':1,'output_tokens':1,'output_tokens_details':{'reasoning_tokens':0}})
            with self.assertRaises(ReasoningError):trajectory.model_call('valid',1)
            with self.assertRaises(ReasoningError):trajectory.model_call('repair',2,repair_of='nonexistent')
            self.assertEqual(trajectory.snapshot()['totals']['modelCalls'],1)
            trajectory.verify(True,'oracle')
            trajectory.verify(True,'second-oracle')
            self.assertEqual(trajectory.snapshot()['throughFirstCorrect']['modelCalls'],1)

    def test_subgoal_success_does_not_end_whole_task_cost_prefix(self):
        with Trajectory(self.engine,'two-obligations','source') as trajectory:
            usage=lambda n:{'input_tokens':1,'output_tokens':n,'output_tokens_details':{'reasoning_tokens':n}}
            trajectory.model_call('first-failure',1,usage(80))
            trajectory.verify(False,'oracle',scope='subgoal')
            trajectory.model_call('first-repair',2,usage(30))
            trajectory.verify(True,'oracle',scope='subgoal')
            self.assertFalse(trajectory.snapshot()['verified'])
            with self.assertRaises(ReasoningError):trajectory.verify(True,'oracle',scope='unknown')
            trajectory.model_call('second-obligation',3,usage(20))
            trajectory.verify(True,'oracle',scope='task')
            result=trajectory.snapshot()['throughFirstCorrect']
            self.assertEqual(result['thinkingTokens'],130)
            self.assertEqual(result['repairThinkingTokens'],30)
            self.assertEqual(result['modelCalls'],3)

    def test_intermediate_projection_rejects_final_answers_and_source_changes(self):
        sources=[relation('input',True,[['a']])]
        program={'relations':sources+[relation('reach',False),relation('answer',False)],
                 'rules':[{'head':[atom('reach')],'body':[atom('input')]},
                          {'head':[atom('answer')],'body':[atom('reach')]}], 'queries':['answer']}
        with EvidenceChain(self.engine,sources) as chain:
            ref=chain.query(program)['resultReference']
            packet=chain.intermediates(ref,['reach'])
            self.assertEqual(packet['facts'],{'reach':[['a']]})
            packet['facts']['reach'].clear()
            self.assertEqual(chain.intermediates(ref,['reach'])['facts']['reach'],[['a']])
            for names in [['answer'],['input'],['reach','reach'],[]]:
                with self.assertRaises(ValueError):chain.intermediates(ref,names)
            chain.replace([relation('input',True,[['b']])])
            with self.assertRaises(ValueError):chain.intermediates(ref,['reach'])
