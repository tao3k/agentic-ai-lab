# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from agentic_ai_lab_testing.assessment_studies import model_study


class ProviderProgress(unittest.TestCase):
    def run_stream(self,events,status=200,body=b''):
        now=[0.0]
        class Wire:
            def settimeout(self,value):pass
        class Response:
            def __init__(self):self.status=status;self.lines=iter(events)
            def readline(self):
                now[0]+=30
                return b'data: '+json.dumps(next(self.lines)).encode()+b'\n'
            def read(self,limit):return body[:limit]
        class Connection:
            sock=Wire()
            def __init__(self,*args,**kwargs):pass
            def connect(self):pass
            def request(self,*args,**kwargs):pass
            def getresponse(self):return Response()
            def close(self):pass
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(model_study.http.client,'HTTPSConnection',Connection), \
                patch.object(model_study.time,'monotonic',lambda:now[0]), \
                contextlib.redirect_stdout(io.StringIO()):
            return model_study.provider({},'private-test-key',Path(directory)/'response.json')[1]

    def test_tool_argument_stream_is_real_progress_past_one_idle_window(self):
        result=self.run_stream([
            {'type':'response.function_call_arguments.delta','delta':'{"contract":'},
            {'type':'response.function_call_arguments.delta','delta':'{}}'},
            {'type':'response.completed','response':{'status':'completed'}}])
        self.assertIsNone(result['error'])
        self.assertEqual(result['providerSeconds'],90)

    def test_unknown_events_cannot_keep_a_stalled_request_alive(self):
        result=self.run_stream([{'type':'unknown'},{'type':'unknown'}])
        self.assertEqual(result['error']['type'],'TimeoutError')
        self.assertIsNone(result['terminal'])

    def test_http_rejection_keeps_typed_detail_and_redacts_credentials(self):
        result=self.run_stream([],400,b'thinking mode rejects required; private-test-key')
        self.assertEqual(result['error']['type'],'RuntimeError')
        self.assertIn('thinking mode rejects required',result['error']['message'])
        self.assertNotIn('private-test-key',result['error']['message'])


if __name__=='__main__':unittest.main()
