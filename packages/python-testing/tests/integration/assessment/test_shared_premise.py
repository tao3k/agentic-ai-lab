# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Fail-closed answer and literal annotation admission for the diagnostic."""
import unittest
from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import (
    shared_action, shared_validate_label, shared_tasks, shared_truth,
    branch_tasks, branch_candidates, branch_grade, branch_input_reservation)


class SharedPremiseTest(unittest.TestCase):
    def message(self, payload):
        return {'output': [{'type': 'message', 'content': [{'type': 'output_text', 'text': payload}]}]}

    def test_answer_rejects_salvage_duplicates_and_boolean_ids(self):
        for raw in ('```json\n{"permitted":[0]}\n```', '{"permitted":[0,0]}',
                    '{"permitted":[true]}', '{"permitted":[0],"permitted":[]}',
                    '{"permitted":[],"why":"ok"}'):
            with self.subTest(raw=raw), self.assertRaises((ValueError, AssertionError)):
                shared_action(self.message(raw))

    def test_distinct_residuals_and_directed_absence(self):
        a,b=shared_tasks()
        self.assertTrue(shared_truth(a,['path',0,2]))
        self.assertTrue(shared_truth(b,['path',0,2]))
        self.assertTrue(shared_truth(a,['ready',2]))
        self.assertFalse(shared_truth(b,['ready',2]))
        self.assertTrue(shared_truth(b,['ready',3]))
        self.assertFalse(shared_truth(a,['path',2,0]))

    def test_repeat_is_across_questions_but_mentions_are_not_derivations(self):
        text='edge(0,1) and edge(1,2) imply path(0,2).'
        item={'quote':text,'occurrence':0,'category':'positive_derivation',
              'atom':['path',0,2],'premises':[['edge',0,1],['edge',1,2]]}
        first=shared_validate_label(text,item,shared_tasks()[0],[],[])
        second=shared_validate_label(text,item,shared_tasks()[0],[],[first])
        self.assertTrue(second['repeatFact']);self.assertTrue(second['exactRepeat'])
        mention={**item,'quote':'path(0,2)','premises':[]}
        with self.assertRaises(AssertionError):
            shared_validate_label('path(0,2)',mention,shared_tasks()[0],[],[])

    def test_label_name_cannot_make_old_or_supplied_atom_new(self):
        text='edge(0,1) and edge(1,2) imply path(0,2).'
        item={'quote':text,'occurrence':0,'category':'new_residual',
              'atom':['path',0,2],'premises':[['edge',0,1],['edge',1,2]]}
        label=shared_validate_label(text,item,shared_tasks()[0],[['path',0,2]],[])
        self.assertFalse(label['newConsequence'])
        self.assertTrue(label['suppliedPremiseRederived'])

    def test_invented_chain_and_nonliteral_endpoint_rejected(self):
        text='edge(0,1) implies path(0,2).'
        item={'quote':text,'occurrence':0,'category':'positive_derivation',
              'atom':['path',0,2],'premises':[['edge',0,1]]}
        with self.assertRaises(AssertionError):shared_validate_label(text,item,shared_tasks()[0],[],[])
        item['premises']=[['edge',0,10],['edge',10,2]]
        with self.assertRaises(AssertionError):shared_validate_label(text,item,shared_tasks()[0],[],[])

    def test_sibling_search_has_feasible_nonoptimal_starts_and_real_shared_paths(self):
        for task in branch_tasks():
            for branch in task['branches']:
                start = branch_grade(task, branch, branch['start'])
                self.assertTrue(start['feasible'])
                self.assertLess(start['score'], max(branch_candidates(task, branch))[0])
                invalid = task['items'][next(i for i in range(16) if not shared_truth(task, ['ready', i]))]
                self.assertTrue(shared_truth(task, ['path', *invalid['paths'][0]]))
                self.assertFalse(shared_truth(task, ['path', *invalid['paths'][1]]))
                bad = [invalid['id'], *[x for x in branch['start'] if x != invalid['id']][:3]]
                self.assertFalse(branch_grade(task, branch, bad)['feasible'])

    def test_sibling_grader_rejects_bad_shape_and_has_frozen_optimum(self):
        task = branch_tasks()[0]; branch = task['branches'][0]
        for ids in ([True, 1, 2, 3], [0, 0, 1, 2], [999, 1, 2, 3], []):
            self.assertFalse(branch_grade(task, branch, ids)['feasible'])
        self.assertEqual(max(branch_candidates(task, branch))[0], 182)

    def test_continuation_uses_measured_usage_and_new_tool_io(self):
        import json
        request={'input':[{'type':'reasoning','content':'x'*20000}]}
        result={'type':'function_call_output','call_id':'actual-call','output':'{}'}
        expected=3000+len(json.dumps(result,ensure_ascii=False).encode())+256
        self.assertEqual(branch_input_reservation(request,3000,[result],256),expected)
        self.assertGreater(branch_input_reservation(request,None,[],256),20000)


if __name__ == '__main__': unittest.main()

class BranchEntryTest(unittest.TestCase):
    def test_partial_output_preserves_reasoning_and_rejects_unpaired_calls(self):
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_partial_output
        t={'status':'incomplete','incomplete_details':{'reason':'max_output_tokens'},
           'output':[{'type':'reasoning','content':[{'type':'reasoning_text','text':'literal trace'}]}]}
        self.assertEqual(branch_partial_output(t),t['output'])
        t['output'].append({'type':'function_call','call_id':'partial'})
        with self.assertRaises(AssertionError):branch_partial_output(t)

    def test_full_text_partition_and_cross_branch_chain_without_hidden_premises(self):
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_literal_episodes
        task=branch_tasks()[0];atom=['path',0,5]
        raw='Check 0->1->2->3->4->5.\npath(0,5) is valid.\nScore = 182.\n'
        a=branch_literal_episodes(raw,task,[atom],[],0,0)
        self.assertEqual(a['coveredCharacters'],len(raw));self.assertEqual(len(a['episodes']),1)
        self.assertTrue(a['episodes'][0]['suppliedPremiseRederived'])
        b=branch_literal_episodes(raw,task,[atom],a['episodes'],1,0)
        self.assertTrue(b['episodes'][0]['crossBranchRepeat']);self.assertEqual(b['unresolvedSemanticLines'],1)
        false=branch_literal_episodes('0->3->5.\n',task,[],[],0,0)
        self.assertFalse(false['episodes']);self.assertEqual(false['unresolvedSemanticLines'],1)

    def test_literal_edge_list_and_via_encoding_deduplicate_overlaps(self):
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_literal_episodes
        task=branch_tasks()[0]
        for text in ('[0,1],[1,2],[2,3],[3,4],[4,5] => path 0 to 5.',
                     '0->5 via 0,1,2,3,4,5.', '[2,5] exists via [2,3],[3,4],[4,5].'):
            r=branch_literal_episodes(text,task,[],[],0,0)
            self.assertEqual(len(r['episodes']),1)
            self.assertEqual(r['episodes'][0]['atom'],['path',2 if text.startswith('[2,5]') else 0,5])

    def test_submission_rejects_duplicate_keys_and_boolean_ids(self):
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_payload
        for arguments in ('{"selected":[0,1,2,3],"selected":[0,1,2,4]}','{"selected":[true,1,2,3]}'):
            with self.assertRaises(AssertionError):branch_payload({'output':[{'type':'function_call','name':'submit_selection','arguments':arguments}]})

    def test_branch_delta_requires_identical_evidence_and_common_context(self):
        import json
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_entry_reservation
        ctx={'task':'x'*20000,'branch':{'id':0},'nativeEvidence':{'scope':1}}
        old={'model':'m','input':[{'role':'user','content':json.dumps(ctx)}]}
        ctx['branch']={'id':1};new={'model':'m','input':[{'role':'user','content':json.dumps(ctx)}]}
        bound=branch_entry_reservation(new,old,5000,256)
        self.assertLess(bound,6000)
        ctx['nativeEvidence']['scope']=2;new['input'][0]['content']=json.dumps(ctx)
        self.assertGreater(branch_entry_reservation(new,old,5000,256),20000)

    def test_non_thinking_submission_contains_exact_visible_trace_without_new_prompt(self):
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_submission_context
        raw='literal first\nsecond fragment'
        terminal={'status':'incomplete','incomplete_details':{'reason':'max_output_tokens'},
                  'output':[{'type':'reasoning','content':[{'type':'reasoning_text','text':raw}]}]}
        output=branch_submission_context(terminal)
        self.assertEqual(output,[{'type':'message','role':'assistant','content':[{'type':'output_text','text':raw}]}])

    def test_qualification_request_identity_and_completed_message_projection(self):
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_submission_context,branch_qualification_request
        terminal={'status':'completed','output':[{'type':'message','content':[{'type':'output_text','text':'literal answer'}]}]}
        self.assertEqual(branch_submission_context(terminal)[0]['content'][0]['text'],'literal answer')
        fixture={'request':{'model':'m','input':[{'role':'user','content':'unchanged question'}]},'terminal':terminal}
        request=branch_qualification_request({'tool':{'name':'submit_selection'},'finalizationOutputCap':256},fixture)
        self.assertEqual(request['reasoning'],{'effort':'none'})
        self.assertEqual(len(fixture['request']['input']),1)


class EvidenceProjectionTest(unittest.TestCase):
    def test_columns_preserve_unknown_scope_and_shared_parents(self):
        import copy,json
        from agentic_ai_lab_runtime.reasoning import compact_observation,expand_observation
        packet={'scope':{'generation':7,'source-digest':'source'},'observations':[
            {'conclusion':{'status':'verified','atom':['path',0,2],'handle':9},'support':{'roots':[3]}},
            {'conclusion':{'status':'unknown','atom':['path',2,0],'handle':9}}],
            'supportNodes':[{'id':3,'kind':'rule','atom':['path',0,2],'ruleLabel':4,'parents':[1,2]}]}
        original=copy.deepcopy(packet);encoded=compact_observation(packet)
        self.assertEqual(expand_observation(json.loads(json.dumps(encoded))),original)
        self.assertEqual(packet,original)
        encoded['supportNodes'][0][-1].clear()
        self.assertEqual(packet,original)

    def test_heterogeneous_native_fields_are_not_erased(self):
        from agentic_ai_lab_runtime.reasoning import compact_observation,expand_observation
        packet={'observations':[{'conclusion':{'status':'unknown'}},{'conclusion':{'status':'verified','atom':['path',0,1]}}]}
        self.assertEqual(expand_observation(compact_observation(packet)),packet)


class SemanticCoverageTest(unittest.TestCase):
    def test_missing_lines_cannot_be_called_complete(self):
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_semantic_validate
        text='Native path exists.\n\nChoose a resource feasible set.\n'
        with self.assertRaises(AssertionError):branch_semantic_validate(text,{'lineCategories':['premise_use'],'episodes':[]})
        spans=branch_semantic_validate(text,{'lineCategories':['premise_use','other','optimization'],'episodes':[]})
        self.assertEqual(spans[-1]['span'][1],len(text))


class NegativeEvidenceAnnotationTest(unittest.TestCase):
    def test_native_absence_use_is_not_an_absence_rederivation(self):
        text='Native evidence marks path(2,0) absent; use that constraint.'
        item={'quote':text,'occurrence':0,'category':'absent_premise_consumed','atom':['path',2,0],'premises':[]}
        label=shared_validate_label(text,item,shared_tasks()[0],[],[],supplied_absent=[['path',2,0]])
        self.assertTrue(label['negativePremiseConsumed'])
        self.assertFalse(label['qualifiedPositive'])
        with self.assertRaises(AssertionError):shared_validate_label(text,item,shared_tasks()[0],[],[])
        # A merely unknown handle is never passed as a finite-absent premise.
        fabricated={**item,'premises':[['edge',2,0]]}
        with self.assertRaises(AssertionError):shared_validate_label(text,fabricated,shared_tasks()[0],[],[],supplied_absent=[['path',2,0]])


class SemanticQuoteCoverageTest(unittest.TestCase):
    def test_block_review_requires_every_code_owned_id_and_retains_unclear(self):
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_semantic_blocks,branch_semantic_block_admit
        text='Evidence used.\n' * 12
        blocks=branch_semantic_blocks(text,40)
        self.assertEqual(''.join(b['text'] for b in blocks),text)
        proposals=[{'id':b['id'],'tags':['unclear']} for b in blocks]
        self.assertEqual(branch_semantic_block_admit(blocks,proposals)[0]['status'],'unclear')
        for bad in (proposals[:-1],proposals+[proposals[0]],[{'id':True,'tags':['optimization']}],
                    [{'id':0,'tags':['invented']}],[]):
            with self.assertRaises(AssertionError):branch_semantic_block_admit(blocks,bad)
    def test_negative_statement_and_unreviewed_text_cannot_be_zero_repetition(self):
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_semantic_summary
        text='path(2,0) is absent. More optimization follows.'
        quote='path(2,0) is absent.'
        proposal={'quote':quote,'occurrence':0,'category':'absence_recheck',
                  'atom':['path',2,0],'premises':[]}
        e=shared_validate_label(text,proposal,shared_tasks()[0],[],[])
        result=branch_semantic_summary(text,[e])
        self.assertEqual(result['admittedProposalCounts']['negative_statement_unresolved'],1)
        self.assertGreater(result['unreviewedCharacters'],0)
        self.assertIsNone(result['wholeTraceRepeatedDerivations'])
        self.assertIsNone(result['negativeRederivations'])
        self.assertIsNone(branch_semantic_summary(text,[])['wholeTraceRepeatedDerivations'])

    def test_support_projection_preserves_absence_and_heterogeneous_predicates(self):
        import json
        from agentic_ai_lab_runtime.reasoning import compact_observation,expand_observation
        packet={'observations':[
            {'conclusion':{'atom':['path',0,2],'support-nodes':[3]},'support':{'roots':[3]}},
            {'conclusion':{'atom':['path',2,0],'support-nodes':[]}}],
            'supportNodes':[{'id':3,'kind':'rule','atom':['path',0,2],'ruleLabel':4,'parents':[1,2]}]}
        compact=compact_observation(packet)
        self.assertEqual(expand_observation(json.loads(json.dumps(compact))),packet)
        self.assertEqual(compact['supportRootsFromConclusion'],[True,False])
        packet['supportNodes'].append({'id':4,'kind':'rule','atom':['ready',0],'ruleLabel':5,'parents':[3]})
        mixed=compact_observation(packet)
        self.assertNotIn('nodeAtomPredicates',mixed)
        self.assertEqual(expand_observation(mixed),packet)

    def test_unmatched_text_is_explicitly_unreviewed_not_semantically_covered(self):
        from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import branch_semantic_partition
        text='unknown prefix. native path(0,2). unknown suffix.'
        quote='native path(0,2)';start=text.index(quote)
        result=branch_semantic_partition(text,[{'quote':quote,'span':[start,start+len(quote)]}])
        self.assertEqual(sum(x['span'][1]-x['span'][0] for x in result),len(text))
        self.assertEqual([x['category'] for x in result],['unreviewed_semantics','admitted_quote_proposal','unreviewed_semantics'])
        with self.assertRaises(AssertionError):branch_semantic_partition(text,[{'quote':'invented','span':[0,8]}])
