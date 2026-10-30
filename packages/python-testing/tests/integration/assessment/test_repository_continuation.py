# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import json
from pathlib import Path
import tempfile
import unittest
from agentic_ai_lab_testing.assessment_studies.repository_continuation import restored_history


class RepositoryContinuationTests(unittest.TestCase):
    def test_restore_preserves_reasoning_and_pairs_last_tool(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            previous = [{'role': 'user', 'content': 'complete problem'}, {'type': 'reasoning', 'id': 'r0', 'opaque': 'unchanged'}, {'type': 'function_call', 'call_id': 'c0', 'name': 'read_source', 'arguments': '{}'}, {'type': 'function_call_output', 'call_id': 'c0', 'output': '{}'}]
            output = [{'type': 'reasoning', 'id': 'r1', 'opaque': 'unchanged too'}, {'type': 'function_call', 'call_id': 'c1', 'name': 'submit_patch', 'arguments': '{}'}]
            (root/'10.request.json').write_text(json.dumps({'input': previous, 'instructions': 'same'}))
            (root/'10.response.json').write_text(json.dumps({'terminal': {'output': output}}))
            record = {'attempts': [{'turn': 10, 'actions': [{'callId': 'c1', 'result': {'verified': False}}]}]}
            history, request = restored_history(root, record)
            self.assertEqual(history.input()[:len(previous)], previous)
            self.assertEqual(history.input()[len(previous):-1], output)
            self.assertEqual(json.loads(history.input()[-1]['output']), {'verified': False})
            self.assertEqual(history.seen, {'c0', 'c1'})
            self.assertEqual(request['instructions'], 'same')

    def test_restore_refuses_unrecorded_implicit_feedback(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/'10.request.json').write_text(json.dumps({'input': []}))
            (root/'10.response.json').write_text(json.dumps({'terminal': {'output': []}}))
            with self.assertRaisesRegex(ValueError, 'feedback unavailable'):
                restored_history(root, {'attempts': [{'turn': 10, 'actions': []}]})


if __name__ == '__main__': unittest.main()
