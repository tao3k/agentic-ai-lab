# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import json
from pathlib import Path
import tempfile
import unittest
from agentic_ai_lab_testing.assessment_studies.repository_candidate_audit import admitted_edits


class PublicCandidateReplay(unittest.TestCase):
    def test_prose_wrapped_json_edit_is_replayed_without_reading_reasoning(self):
        record={'attempts':[{'turn':1,'actions':[{'name':'implicit_edit','result':{'edited':['x.py'],'sourceIdentity':'snapshot'}}]}]}
        edits=[{'path':'x.py','old':'x=1','new':'x=2'}]
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            text='Applied this repair:\n```json\n'+json.dumps({'edits':edits})+'\n```'
            (root/'1.response.json').write_text(json.dumps({'terminal':{'output':[
                {'type':'reasoning','opaque':'DO-NOT-READ'},
                {'type':'message','content':[{'type':'output_text','text':text}]}]}}))
            self.assertEqual(list(admitted_edits(record,root)),[(1,edits,'snapshot')])
    def test_only_admitted_public_edits_are_replayed(self):
        record={'attempts':[{'turn':1,'actions':[
            {'name':'edit_source','callId':'accepted','result':{'edited':['x.py'],'sourceIdentity':'snapshot'}},
            {'name':'edit_source','callId':'rejected','result':{'error':'mismatch'}}]}]}
        edits=[{'path':'x.py','old':'return 1','new':'return 2'}]
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'1.response.json').write_text(json.dumps({'terminal':{'output':[
                {'type':'reasoning','opaque':'DO-NOT-READ'},
                {'type':'function_call','name':'edit_source','call_id':'accepted','arguments':json.dumps({'edits':edits})},
                {'type':'function_call','name':'edit_source','call_id':'rejected','arguments':'invalid'}]}}))
            self.assertEqual(list(admitted_edits(record,root)),[(1,edits,'snapshot')])

    def test_missing_admitted_call_fails_instead_of_inventing_a_candidate(self):
        record={'attempts':[{'turn':1,'actions':[{'name':'edit_source','callId':'absent','result':{'edited':['x.py'],'sourceIdentity':'snapshot'}}]}]}
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'1.response.json').write_text(json.dumps({'terminal':{'output':[]}}))
            with self.assertRaises(KeyError):list(admitted_edits(record,root))
