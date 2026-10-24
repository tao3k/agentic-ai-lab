# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Byte transport and provider-context discriminators; no semantic oracle."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock
import contextlib
import io

sys.path.insert(0, str(Path(__file__).parents[1] / 'src'))
from agentic_ai_lab_testing.assessment_studies import model_study as study

class ProviderByteContext(unittest.TestCase):
    def test_request_context_difference_is_only_real_computed_feedback(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'f-initial.input.ss').write_text('ACTUAL-INITIAL-SOURCE')
            (root/'f-transfer.input.ss').write_text('ACTUAL-TRANSFER-SOURCE')
            (root/'f-transfer.task.ss').write_text('ACTUAL-TRANSFER-TASK')
            initial={'f':{'raw':"'2",'nativeObservation':{'nativeDatum':'2','correct':True}}}
            plan={'model':'deepseek-flash','maxInputBytes':655360,'maxOutputTokens':8192}
            item={'family':'f','case':'f-transfer','reasoningEffort':'high'}
            history=study.request_for(plan,root,{**item,'arm':'transfer-history'},initial)
            feedback=study.request_for(plan,root,{**item,'arm':'transfer-feedback'},initial)
            self.assertEqual(history['input'][:2],feedback['input'][:2])
            self.assertEqual(history['input'][2]['content'],'ACTUAL-TRANSFER-TASK')
            self.assertEqual(feedback['input'][2]['content'],json.dumps(initial['f']['nativeObservation'],sort_keys=True)+'\nACTUAL-TRANSFER-TASK')
            self.assertEqual(set(history),{'model','input','reasoning','max_output_tokens','stream','store'})
            self.assertEqual([x['role'] for x in history['input']],['user','assistant','user'])
            fresh=study.request_for(plan,root,{**item,'arm':'transfer-fresh'},initial)
            self.assertEqual(fresh['input'],[{'role':'user','content':'ACTUAL-TRANSFER-SOURCE'}])
            self.assertFalse(fresh['store'])

    def test_frozen_input_limit_rejects_before_dispatch(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'f-initial.input.ss').write_text('TOO-LONG')
            with self.assertRaises(ValueError):
                study.request_for({'maxInputBytes':1},root,{'case':'f-initial','arm':'initial-none'}, {})

class ProviderProgress(unittest.TestCase):
    def run_stream(self, frames):
        clock=[0.0]
        connection=Mock()
        response=Mock(status=200)
        connection.getresponse.return_value=response
        remaining=iter(frames)
        def read():
            elapsed, payload=next(remaining, (0, b''))
            clock[0]+=elapsed
            return payload
        response.readline.side_effect=read
        with tempfile.TemporaryDirectory() as temp:
            destination=Path(temp)/'response.json'
            with patch.object(study.http.client,'HTTPSConnection',return_value=connection), \
                 patch.object(study.time,'monotonic',side_effect=lambda:clock[0]), \
                 contextlib.redirect_stdout(io.StringIO()):
                raw, metadata=study.provider({'stream':True}, 'TEST-ONLY-KEY', destination)
            self.assertTrue(connection.close.called)
            self.assertEqual(json.loads(destination.read_text()),metadata)
        return raw, metadata

    def test_live_reasoning_can_exceed_180_seconds(self):
        reasoning=b'data: {"type":"response.reasoning_text.delta","delta":"working"}\n'
        completed=b'data: {"type":"response.completed","response":{"status":"completed"}}\n'
        raw, result=self.run_stream([(40,reasoning)]*5+[(20,completed)])
        self.assertIsNone(result['error'])
        self.assertEqual(result['terminal']['status'],'completed')
        self.assertEqual(result['providerSeconds'],220)
        self.assertEqual(result['reasoningEvents'],5)
        self.assertIsNone(result['absoluteWallDeadlineSeconds'])

    def test_keepalive_and_unknown_events_do_not_renew_progress(self):
        for payload in (b': keepalive\n', b'data: {"type":"response.keepalive"}\n'):
            with self.subTest(payload=payload):
                raw,result=self.run_stream([(10,payload)]*5)
                self.assertEqual(result['error']['type'],'TimeoutError')
                self.assertIsNone(result['terminal'])
                self.assertEqual(result['providerSeconds'],50)

if __name__=='__main__':unittest.main()
