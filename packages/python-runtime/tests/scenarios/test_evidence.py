# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import os
import subprocess
import sys
import unittest
from agentic_ai_lab_testing.assessment_studies.inference_reuse_study import ROOT


class EvidenceIntegration(unittest.TestCase):
    def test_real_scheme_evidence_survives_repeat_and_rebuilds_after_withdrawal(self):
        code='''
import copy,os
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceStore
from agentic_ai_lab_testing.assessment_studies import inference_reuse_study as s
with ReasoningRuntime() as engine:
  for i in range(4):
    case=s.workload(i);source=case['source'];contract=s.oracle_contract(case)
    p=s.program(source,contract);sources=[r for r in p['relations'] if r['source']]
    with EvidenceStore(engine,sources) as evidence:
      first=evidence.query(p);second=evidence.query(p)
      assert not first['retainedCompleted'] and second['retainedCompleted']
      assert first['result']==second['result']
      assert sorted(first['result']['relations']['answer'])==s.expected(case,source)
      invalid=copy.deepcopy(p);invalid['relations'][0]['rows']=[]
      try:evidence.query(invalid);raise AssertionError('source forgery admitted')
      except ValueError:pass
      assert evidence.query(p)['result']==first['result']
      current=s.updated(case);newp=s.program(current,contract)
      evidence.replace([r for r in newp['relations'] if r['source']])
      changed=evidence.query(newp)
      assert changed['sourceIdentity']!=first['sourceIdentity']
      assert changed['pathIdentity']==first['pathIdentity']
      assert changed['retainedPath'] and not changed['retainedCompleted']
      assert sorted(changed['result']['relations']['answer'])==s.expected(case,current)
      assert evidence.query(newp)['retainedCompleted']
      assert evidence.scan(['mentor'])['sourceIdentity']==changed['sourceIdentity']
      print('EVIDENCE-LOOP-OK',case['name'],flush=True)
  case=s.workload(0);source=case['source']
  a,b,c,f,d,k=[s.var(n) for n in ('a','b','c','f','d','k')]
  stage1={'relations':[{'name':'eligible_z','types':['Actor','Film']}],
    'rules':[s.rule(s.atom('eligible_z',c,f),s.atom('cast',f,c),s.atom('directed',f,d),
                   s.atom('citizen',d,k),s.atom('selected_country',k))]}
  p1=s.program(source,stage1);p1['queries']=['eligible_z']
  with EvidenceStore(engine,[r for r in p1['relations'] if r['source']]) as evidence:
    first=evidence.query(p1);alias=first['publishedEvidence'][0]['relation']
    stage2={'relations':[], 'rules':[s.rule(s.atom('answer',a),s.atom('mentor',a,b),
                                          s.atom('mentor',b,c),s.atom(alias,c,f))]}
    p2=s.program(source,stage2)
    second=evidence.query(p2)
    assert sorted(second['result']['relations']['answer'])==s.expected(case,source)
    assert evidence.query(p2)['retainedCompleted']
    current=s.updated(case);newbase=s.program(current,{'relations':[],'rules':[]})
    evidence.replace([r for r in newbase['relations'] if r['source']])
    try:evidence.scan([alias]);raise AssertionError('stale subgoal still visible')
    except ValueError:pass
    stale=s.program(current,stage2)
    try:evidence.query(stale);raise AssertionError('stale subgoal accepted')
    except Exception as error:
      assert not isinstance(error,AssertionError)
    newp1=s.program(current,stage1);newp1['queries']=['eligible_z']
    third=evidence.query(newp1)
    assert third['sourceIdentity']!=first['sourceIdentity']
    freshalias=third['publishedEvidence'][0]['relation']
    stage2['rules'][0]['body'][-1]['relation']=freshalias
    fourth=evidence.query(s.program(current,stage2))
    assert sorted(fourth['result']['relations']['answer'])==s.expected(case,current)
    print('EVIDENCE-SUBGOAL-COMPOSITION-OK',flush=True)
'''
        subprocess.run([sys.executable,'-u','-'],input=code,text=True,check=True,
                       env={**os.environ,'PYTHONPATH':str(ROOT/'packages/python-testing/src')})


if __name__=='__main__':unittest.main()
