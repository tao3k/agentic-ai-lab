# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import os
import subprocess
import sys
import unittest
import tempfile
from pathlib import Path


class EmbeddedProcessStatus(unittest.TestCase):
    def test_failed_child_status_survives_embedded_runtime_initialization(self):
        root=Path(__file__).resolve().parents[4]
        code='''
import os,subprocess,sys
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
engine=ReasoningRuntime()
assert not engine.closed
for status in (7,0,9):
 child=subprocess.Popen([sys.executable,'-c',f'import sys; sys.exit({status})'])
 assert child.wait()==status, 'embedded runtime consumed child status'
print('EMBEDDED-PROCESS-STATUS-OK',flush=True)
'''
        subprocess.run([sys.executable,'-u','-c',code],cwd=root,env={**os.environ,'PYTHONPATH':str(root/'packages/python-testing/src')},check=True)

    def test_host_descriptor_flags_survive_initialization_and_evaluation(self):
        root=Path(__file__).resolve().parents[4]
        code="""
import os,fcntl
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_testing.assessment_studies import inference_reuse_study as s
read,write=os.pipe()
fds=(0,1,2,read,write)
before={fd:fcntl.fcntl(fd,fcntl.F_GETFL) for fd in fds}
engine=ReasoningRuntime()
assert not engine.closed
assert before=={fd:fcntl.fcntl(fd,fcntl.F_GETFL) for fd in fds}, 'host flags changed on init'
case=s.workload(3);p=s.program(case['source'],s.oracle_contract(case))
with EvidenceChain(engine,[r for r in p['relations'] if r['source']],True) as chain:
 chain.query(p)
assert before=={fd:fcntl.fcntl(fd,fcntl.F_GETFL) for fd in fds}, 'host flags changed on evaluation'
os.write(write,b'host');assert os.read(read,4)==b'host'
print('EMBEDDED-HOST-IO-FLAGS-OK',flush=True)
"""
        subprocess.run([sys.executable,'-u','-c',code],cwd=root,env={**os.environ,'PYTHONPATH':str(root/'packages/python-testing/src')},check=True)

    def test_each_scheme_worker_finishes_without_reusing_a_host_queue(self):
        root=Path(__file__).resolve().parents[4]
        code="""
import concurrent.futures,multiprocessing,os,fcntl
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_testing.assessment_studies import inference_reuse_study as s
def job(index):
 flags={fd:fcntl.fcntl(fd,fcntl.F_GETFL) for fd in (0,1,2)}
 engine=ReasoningRuntime()
 assert not engine.closed
 case=s.workload(3);p=s.program(case['source'],s.oracle_contract(case))
 with EvidenceChain(engine,[r for r in p['relations'] if r['source']],True) as chain:
  result=chain.query(p)
  assert sorted(result['result']['relations']['answer'])==s.expected(case,case['source'])
 assert flags=={fd:fcntl.fcntl(fd,fcntl.F_GETFL) for fd in (0,1,2)}
 return os.getpid()
if __name__=='__main__':
 with concurrent.futures.ProcessPoolExecutor(max_workers=2,mp_context=multiprocessing.get_context('spawn'),max_tasks_per_child=1) as pool:
  pids=list(pool.map(job,range(4)))
 assert len(set(pids))==4
 print('EMBEDDED-ONE-TRAJECTORY-WORKERS-OK',flush=True)
"""
        with tempfile.TemporaryDirectory() as temp:
            script=Path(temp)/'workers.py';script.write_text(code)
            subprocess.run([sys.executable,'-u',str(script)],cwd=root,env={**os.environ,'PYTHONPATH':str(root/'packages/python-testing/src')},check=True)


if __name__=='__main__':unittest.main()
