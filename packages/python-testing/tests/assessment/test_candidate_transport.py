# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Deadline and framing regressions for the existing model consumer IO."""
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from agentic_ai_lab_testing.assessment_studies import candidate_model as model


class TransportTest(unittest.TestCase):
    def consumer(self, script):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        consumer = model.Consumer.__new__(model.Consumer)
        consumer.run = Path(folder.name)
        consumer.trace = []
        consumer.dynamic = False
        consumer.shutdown = None
        consumer._stdout_buffer = bytearray()
        consumer.err = (consumer.run/'native-stderr.log').open('a')
        consumer.p = subprocess.Popen([sys.executable, '-u', '-c', script],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=consumer.err, bufsize=0)
        self.addCleanup(consumer.close)
        return consumer

    def test_partial_line_obeys_deadline(self):
        c = self.consumer('import sys; sys.stdout.write("{\\\"ready\\\":"); sys.stdout.flush(); sys.stdin.read()')
        began = time.monotonic()
        with self.assertRaises(TimeoutError):
            c.receive(.25)
        self.assertLess(time.monotonic()-began, 1)
        self.assertEqual((c.run/'native-partial-output.bin').read_bytes(), b'{"ready":')
        self.assertTrue(c.close()['clean'])

    def test_multiple_frames_are_not_lost_in_buffer(self):
        c = self.consumer('import sys; sys.stdout.write("{\\\"first\\\":1}\\n{\\\"second\\\":2}\\n"); sys.stdout.flush(); sys.stdin.read()')
        self.assertEqual(c.receive(1), {'first':1})
        self.assertEqual(c.receive(.1), {'second':2})

    def test_split_frame(self):
        c = self.consumer('import sys,time; sys.stdout.write("{\\\"ready\\\":"); sys.stdout.flush(); time.sleep(.05); print("true}"); sys.stdin.read()')
        self.assertEqual(c.receive(1), {'ready':True})

    def test_eof_with_partial_frame_is_failure(self):
        c = self.consumer('print("{",end="",flush=True)')
        with self.assertRaisesRegex(RuntimeError, 'before complete response'):
            c.receive(1)
        self.assertEqual((c.run/'native-partial-output.bin').read_bytes(), b'{')

    def test_invalid_frame_is_preserved(self):
        c = self.consumer('print("not-json",flush=True)')
        with self.assertRaises(model.json.JSONDecodeError):
            c.receive(1)
        self.assertEqual((c.run/'native-invalid-output.log').read_bytes(), b'not-json\n')

    def test_silent_peer_times_out(self):
        c = self.consumer('import sys; sys.stdin.read()')
        with self.assertRaises(TimeoutError):
            c.receive(.1)

    def test_broken_stdin_is_recorded(self):
        c = self.consumer('pass')
        c.p.wait(timeout=1)
        with self.assertRaises(BrokenPipeError):
            c.call(op='ignored')
        self.assertIn('failure', model.json.loads((c.run/'native.json').read_text())[0])

    def test_readiness_failure_records_actual_deadline_and_cleans(self):
        with tempfile.TemporaryDirectory() as folder:
            run = Path(folder)
            real_popen = subprocess.Popen
            def launch(*args, **kwargs):
                return real_popen([sys.executable, '-u', '-c', 'import sys; sys.stdin.read()'], **kwargs)
            with patch.object(model.subprocess, 'Popen', side_effect=launch), \
                    patch.object(model.Consumer, 'receive', side_effect=TimeoutError('test readiness timeout')) as receive:
                with self.assertRaises(TimeoutError):
                    model.Consumer(run, dynamic=True)
                receive.assert_called_once_with(60)
            receipt = model.json.loads((run/'native-readiness-failure.json').read_text())
            self.assertEqual(receipt['deadline'], 60)
            self.assertEqual(receipt['pendingBytes'], 0)
            self.assertTrue(model.json.loads((run/'native-shutdown.json').read_text())['clean'])

    def test_spawn_failure_has_receipt(self):
        with tempfile.TemporaryDirectory() as folder:
            run = Path(folder)
            with patch.object(model.subprocess, 'Popen', side_effect=FileNotFoundError('missing executable')):
                with self.assertRaises(FileNotFoundError):
                    model.Consumer(run)
            self.assertEqual(model.json.loads((run/'native-readiness-failure.json').read_text())['phase'], 'spawn')


class BranchRequestTest(unittest.TestCase):
    def setUp(self):
        self.plan={'model':'deepseek-flash','tool':{'type':'function','name':'expand','parameters':{'type':'object','properties':{'parentId':{'type':'integer'},'optionId':{'type':'integer'}},'required':['parentId','optionId'],'additionalProperties':False}},
                   'budget':65536,'outputCap':65536,'minimumOutputCap':1024,'inputReservationPadding':256}
        self.context={'task':{'immutable':'raw facts'},'question':'original question',
                      'frontier':[{'parentId':0,'optionIds':[1]}],'incumbent':{'value':3}}

    def test_first_request_preserves_question_and_thinking(self):
        req,reserve=model.branch_request(self.plan,self.context,[],None,0)
        self.assertEqual(model.json.loads(req['input'][0]['content']),self.context)
        self.assertEqual(req['reasoning'],{'effort':'low'})
        self.assertNotIn('instructions',req)
        self.assertLessEqual(reserve,self.plan['budget'])
        self.assertGreater(req['max_output_tokens'],32768)

    def test_continuation_replays_reasoning_and_pairs_tool_result(self):
        history=[{'role':'user','content':'original'},
                 {'type':'reasoning','content':[{'type':'reasoning_text','text':'kept exactly'}]},
                 {'type':'function_call','call_id':'call-1','name':'expand','arguments':'{}'}]
        req,reserve=model.branch_request(self.plan,self.context,history,'call-1',30000,22000)
        self.assertEqual(req['input'][:len(history)],history)
        self.assertEqual(req['input'][-2]['call_id'],'call-1')
        self.assertNotIn('task',model.json.loads(req['input'][-2]['output']))
        self.assertEqual(model.json.loads(req['input'][-1]['content']),{'question':self.context['question']})
        self.assertLess(req['max_output_tokens'],32768)
        self.assertLessEqual(30000+reserve,65536)

    def test_budget_exhaustion_is_censored_without_request(self):
        req,_=model.branch_request(self.plan,self.context,[{'role':'user','content':'original'}],'call-1',65000,20000)
        self.assertIsNone(req)

    def test_continuation_requires_recorded_usage(self):
        with self.assertRaisesRegex(AssertionError,'missing_history_usage'):
            model.branch_request(self.plan,self.context,[{'role':'user','content':'original'}],'call-1',10000)

    def test_message_action_returns_data_without_fabricating_tool_call(self):
        history=[{'role':'user','content':'original'},
                 {'type':'message','content':[{'type':'output_text','text':'{"parentId":0,"optionId":1}'}]}]
        req,_=model.branch_request(self.plan,self.context,history,None,1000,800)
        self.assertEqual(req['input'][:-1],history)
        self.assertEqual(req['input'][-1]['role'],'user')
        self.assertNotIn('call_id',req['input'][-1])
        self.assertEqual(model.json.loads(req['input'][-1]['content'])['extensionResult']['frontier'],self.context['frontier'])
        self.assertEqual(model.json.loads(req['input'][-1]['content'])['question'],self.context['question'])

    def test_structured_output_uses_existing_action_schema_only(self):
        req,_=model.branch_request(self.plan,self.context,[],None,0)
        self.assertEqual(req['text']['format']['schema'],self.plan['tool']['parameters'])
        self.assertNotIn('instructions',req)

    def test_both_encodings_decode_same_untrusted_action(self):
        action={'parentId':0,'optionId':1};text=model.json.dumps(action)
        tool={'output':[{'type':'function_call','name':'expand','call_id':'real-call','arguments':text}]}
        message={'output':[{'type':'message','content':[{'type':'output_text','text':text}]}]}
        self.assertEqual(model.branch_action(tool),(action,'function_call','real-call'))
        self.assertEqual(model.branch_action(message),(action,'json_message',None))

    def test_invalid_action_payloads_remain_rejected(self):
        for text in ['{"parentId":true,"optionId":1}', '{"parentId":0,"optionId":1,"extra":2}',
                     '[{"parentId":0,"optionId":1}]','```json\n{"parentId":0,"optionId":1}\n```',
                     '{"parentId":0,"optionId":1} trailing','{"parentId":0,"parentId":1,"optionId":1}']:
            with self.subTest(text=text),self.assertRaises((AssertionError,ValueError)):
                model.branch_action({'output':[{'type':'message','content':[{'type':'output_text','text':text}]}]})

    def test_ambiguous_or_wrong_tool_remains_rejected(self):
        call={'type':'function_call','name':'expand','call_id':'real-call','arguments':'{"parentId":0,"optionId":1}'}
        for outputs in [[call,call],[{**call,'name':'other'}],[{**call,'call_id':None}],[],
                        [{'type':'message','content':[]},{'type':'message','content':[]}]]:
            with self.subTest(outputs=outputs),self.assertRaises(AssertionError):
                model.branch_action({'output':outputs})


if __name__ == '__main__':
    unittest.main()
