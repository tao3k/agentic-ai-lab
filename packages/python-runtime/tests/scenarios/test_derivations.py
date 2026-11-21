# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import os,subprocess,sys,unittest
from agentic_ai_lab_testing.assessment_studies.inference_reuse_study import ROOT


class DerivationChainIntegration(unittest.TestCase):
    def test_scheme_closure_is_reused_across_rounds_but_not_after_source_change(self):
        code='''
import copy,os
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_testing.assessment_studies import inference_reuse_study as s
case=s.workload(3);source=case['source'];contract=s.oracle_contract(case)
stage=copy.deepcopy(contract);stage['rules']=[r for r in stage['rules'] if r['head'][0]['relation']=='reachable']
p1=s.program(source,stage);p1['queries']=['reachable']
p2=s.program(source,contract)
with ReasoningRuntime() as engine:
 for retained in (False,True):
  with EvidenceChain(engine,[r for r in p1['relations'] if r['source']],retained) as chain:
   first=chain.query(p1);second=chain.query(p2)
   assert sorted(second['result']['relations']['answer'])==s.expected(case,source)
   assert any(c['recursive'] for c in second['reusedComponents'])==retained
   assert chain.answer(second['resultReference'],'answer')==second['result']['relations']['answer']
   bad=copy.deepcopy(p2);bad['relations'][0]['rows']=[]
   try:chain.query(bad);raise AssertionError('forged source accepted')
   except ValueError:pass
   changed=s.updated(case);fresh=s.program(changed,contract)
   old=second['resultReference'];chain.replace([r for r in fresh['relations'] if r['source']])
   try:chain.answer(old,'answer');raise AssertionError('stale answer accepted')
   except ValueError:pass
   third=chain.query(fresh)
   assert not third['reusedComponents']
   assert sorted(third['result']['relations']['answer'])==s.expected(case,changed)
   print('SCHEME-CROSS-ROUND-CLOSURE-OK',retained,flush=True)
'''
        subprocess.run([sys.executable,'-u','-'],input=code,text=True,check=True,
                       env={**os.environ,'PYTHONPATH':str(ROOT/'packages/python-testing/src')})


if __name__=='__main__':unittest.main()
