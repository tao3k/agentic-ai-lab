# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import os
import subprocess
import sys
import unittest
from agentic_ai_lab_testing.assessment_studies.inference_reuse_study import ROOT


class CompoundInferenceQualification(unittest.TestCase):
    def test_compound_oracles_withdrawal_and_scope_mutations(self):
        code='''
import copy,os
from ascent import Engine
from agentic_ai_lab_testing.assessment_studies import complex_inference_workload as c
from agentic_ai_lab_testing.assessment_studies import inference_reuse_study as s
with Engine() as engine:
  def evaluate(case,source,contract):
    with engine.open(s.program(source,contract)) as session:
      result=session.run()
      assert result['complete']
      return sorted(result['relations']['answer'])
  for i in range(4):
    case=c.workload(i,20261010+i*101);contract=c.oracle_contract(case)
    original=evaluate(case,case['source'],contract)
    assert original==c.expected(case,case['source']) and original
    changed=s.updated(case)
    assert evaluate(case,changed,contract)==c.expected(case,changed)
    assert c.expected(case,changed)!=original
    print('COMPOUND-ORACLE-OK',case['family'],len(original),len(c.expected(case,changed)),flush=True)
    if i==0:
      mutant=copy.deepcopy(contract)
      four=next(r for r in mutant['rules'] if r['head'][0]['relation']=='four')
      four['body']=four['body'][:2]+[s.atom('mentor',s.var('q'),s.var('z'))]
      assert evaluate(case,case['source'],mutant)!=original
      print('FOUR-VS-THREE-HOP-FAULT-DETECTED',flush=True)
    if i==2:
      mutant=copy.deepcopy(contract)
      mutant['rules'][-1]['body'].append(s.atom('excluded',s.var('a'),negative=True))
      assert evaluate(case,case['source'],mutant)!=original
      print('BRANCH-SCOPE-FAULT-DETECTED',flush=True)
    if i==3:
      mutant=copy.deepcopy(contract)
      mutant['rules'][-1]['body']=[a for a in mutant['rules'][-1]['body'] if a['relation']!='incomplete']
      assert evaluate(case,case['source'],mutant)!=original
      print('UNIVERSAL-TO-EXISTENTIAL-FAULT-DETECTED',flush=True)
'''
        subprocess.run([sys.executable,'-u','-'],input=code,text=True,check=True,
                       env={**os.environ,'PYTHONPATH':str(ROOT/'packages/python-testing/src')})


if __name__=='__main__':unittest.main()
