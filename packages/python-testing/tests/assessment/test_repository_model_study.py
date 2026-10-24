# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import hashlib
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from agentic_ai_lab_testing.assessment_studies.repository_model_study import Workspace, evidence_program, symbol_table, episode


class RepositoryModelStudy(unittest.TestCase):
    def workspace(self, root):
        parent=root/'plan/task/parent/demo';parent.mkdir(parents=True)
        text='def leaf():\n    return 1\n\ndef entry():\n    return leaf()\n'
        (parent/'core.py').write_text(text)
        case={'name':'task','package':'demo','editable':['demo/core.py'],'files':{'demo/core.py':hashlib.sha256(text.encode()).hexdigest()},'testFile':'demo/tests/test_core.py'}
        output=root/'episode';output.mkdir()
        return Workspace(root/'plan',output,case,'ordinary-tools')

    def test_scoped_reads_and_atomic_implementation_edits(self):
        with tempfile.TemporaryDirectory() as temp:
            workspace=self.workspace(Path(temp))
            with self.assertRaises(ValueError):workspace.read('../../.env')
            with self.assertRaises(ValueError):workspace.read('demo/tests/test_core.py')
            original=workspace.read('demo/core.py')['text'];old=workspace.source_identity
            with self.assertRaises(ValueError):workspace.edit([{'path':'demo/core.py','old':'return 1','new':'return 2'},{'path':'demo/tests/test_core.py','old':'x','new':'y'}])
            self.assertEqual(original,workspace.read('demo/core.py')['text'])
            workspace.edit([{'path':'demo/core.py','old':'return 1','new':'return 2'}])
            self.assertNotEqual(old,workspace.source_identity)
            self.assertEqual(workspace.generation,1)

    def test_unchanged_reference_graph_still_binds_changed_source_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            workspace=self.workspace(Path(temp));entries,edges=workspace.entries,workspace.edges
            first=evidence_program(entries,edges,[],workspace.source_identity)
            workspace.edit([{'path':'demo/core.py','old':'return 1','new':'return 2'}])
            second=evidence_program(workspace.entries,workspace.edges,[],workspace.source_identity)
            self.assertEqual(edges,workspace.edges)
            self.assertNotEqual(first['relations'][-1]['rows'],second['relations'][-1]['rows'])

    def test_verified_candidate_cannot_be_overwritten_or_bound_to_another_snapshot(self):
        with tempfile.TemporaryDirectory() as temp:
            workspace=self.workspace(Path(temp));workspace.case.update(graderSha256='grader',expectedTestNames=['control'])
            grade={'verified':True,'kind':'hidden-grading','exitCode':0,'counts':{'passed':1,'failed':0,'skipped':0,'error':0},'sourceIdentity':'other'}
            with self.assertRaises(ValueError):workspace.seal_candidate(grade)
            grade['sourceIdentity']=workspace.source_identity
            receipt=workspace.seal_candidate(grade)
            self.assertEqual((Path(receipt['path'])/'demo/core.py').read_text(),(workspace.root/'demo/core.py').read_text())
            with self.assertRaises(ValueError):workspace.edit([{'path':'demo/core.py','old':'return 1','new':'return 2'}])

    def test_guard_stops_after_first_verified_edit_without_another_provider_call(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            terminal={'status':'completed','usage':{'input_tokens':1,'output_tokens':1,'output_tokens_details':{'reasoning_tokens':1}},'output':[{'type':'function_call','name':'edit_source','call_id':'call-1','arguments':'{"edits": []}'}]}
            with patch('agentic_ai_lab_testing.assessment_studies.repository_model_study.Workspace') as factory,patch('agentic_ai_lab_testing.assessment_studies.repository_model_study.provider_key',return_value='unused'),patch('agentic_ai_lab_testing.assessment_studies.repository_model_study.provider',return_value=('',{'terminal':terminal,'providerSeconds':0,'error':None})) as provider:
                workspace=factory.return_value;workspace.source_identity='source';workspace.journal=[];workspace.domain=None
                workspace.edit.return_value={'edited':['source.py']};workspace.execute.return_value={'verified':True};workspace.seal_candidate.return_value={'sourceIdentity':'source'}
                record=episode({'maxTurns':10,'maxOutputTokens':131072,'verifyCandidatesOnEdit':True},root,root,{'name':'task','editable':[],'question':'Repair.'},0,'ordinary-tools')
                self.assertEqual(record['status'],'verified');self.assertEqual(provider.call_count,1)
                workspace.seal_candidate.assert_called_once()

    def test_plain_final_prose_is_graded_without_a_json_format_rejection(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            terminal={'status':'completed','usage':{'input_tokens':1,'output_tokens':1,'output_tokens_details':{'reasoning_tokens':1}},'output':[{'type':'message','role':'assistant','content':[{'type':'output_text','text':'The repair is complete.'}]}]}
            with patch('agentic_ai_lab_testing.assessment_studies.repository_model_study.Workspace') as factory,patch('agentic_ai_lab_testing.assessment_studies.repository_model_study.provider_key',return_value='unused'),patch('agentic_ai_lab_testing.assessment_studies.repository_model_study.provider',return_value=('The repair is complete.',{'terminal':terminal,'providerSeconds':0,'error':None})) as provider:
                workspace=factory.return_value;workspace.source_identity='source';workspace.journal=[];workspace.domain=None;workspace.execute.return_value={'verified':True}
                record=episode({'maxTurns':10,'maxOutputTokens':131072},root,root,{'name':'task','editable':[],'question':'Repair.'},0,'ordinary-tools')
                self.assertEqual(record['status'],'verified');workspace.execute.assert_called_once_with(grading=True)
                workspace.seal_candidate.side_effect=ValueError('source changed while sealing')
                failed=episode({'maxTurns':1,'maxOutputTokens':131072,'verifyCandidatesOnEdit':True},root,root,{'name':'changed-task','editable':[],'question':'Repair.'},0,'ordinary-tools')
                self.assertEqual(failed['status'],'censored')
                self.assertFalse(failed['attempts'][0]['correct'])
                self.assertIn('source changed',failed['attempts'][0]['actions'][0]['result']['error'])

    def test_evaluator_introspection_and_import_changes_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            workspace=self.workspace(Path(temp))
            for new in ('return open("/tmp/secret").read()', 'import os\n    return 2'):
                with self.assertRaises(ValueError):workspace.edit([{'path':'demo/core.py','old':'return 1','new':new}])

    def test_relative_entry_paths_are_normalized_before_changing_child_cwd(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);existing=self.workspace(root);case=existing.case
            out=root/'relative-episode';out.mkdir()
            workspace=Workspace(Path(os.path.relpath(root/'plan')),Path(os.path.relpath(out)),case,'ordinary-tools')
            self.assertTrue(workspace.root.is_absolute())
            self.assertTrue(workspace.directory.is_absolute())

    def test_harness_failure_stops_further_paid_requests(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            terminal={'status':'completed','usage':{'input_tokens':1,'output_tokens':1,'output_tokens_details':{'reasoning_tokens':1}},'output':[{'type':'function_call','name':'run_checks','call_id':'call-1','arguments':'{}'}]}
            with patch('agentic_ai_lab_testing.assessment_studies.repository_model_study.Workspace') as factory,patch('agentic_ai_lab_testing.assessment_studies.repository_model_study.provider_key',return_value='unused'),patch('agentic_ai_lab_testing.assessment_studies.repository_model_study.provider',return_value=('',{'terminal':terminal,'providerSeconds':0,'error':None})) as provider:
                factory.return_value.source_identity='source';factory.return_value.journal=[];factory.return_value.domain=None
                factory.return_value.execute.side_effect=RuntimeError('test environment did not produce a complete receipt')
                record=episode({'maxTurns':10,'maxOutputTokens':131072},root,root,{'name':'task','editable':[],'question':'Repair.'},0,'ordinary-tools')
                self.assertEqual(record['status'],'harness_failure')
                self.assertEqual(provider.call_count,1)


if __name__=='__main__':unittest.main()
