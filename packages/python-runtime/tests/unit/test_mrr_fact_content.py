# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import os
from pathlib import Path
import pytest
from agentic_ai_lab_runtime.scheme_wire import loads
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntimeError

def request():
    return dict(schema='agentic-ai-lab.mrr-fact-request.v1',identity='id',generation='generation',
                relationId='relation',evaluatorRelation='edge',row=[1,True])

def test_original_mrr_fact_oracle(runtime):
    path=os.environ.get('AGENTIC_AI_LAB_MRR_FACT_ORACLE')
    if not path: pytest.skip('original MRR fact oracle must be configured')
    for case in loads(Path(path).read_text()):
        assert runtime.canonical_mrr_fact_content(case['request']) == case['expected']

@pytest.mark.parametrize('mode',['float','empty','extra','schema','range'])
def test_fact_content_rejects_unqualified_profile(runtime,mode):
    p=request()
    if mode=='float':p['row']=[1.0]
    if mode=='empty':p['row']=[]
    if mode=='extra':p['proofAdmitted']=True
    if mode=='schema':p['schema']='agentic-ai-lab.mrr-fact-request.v2'
    if mode=='range':p['row']=[2**63]
    with pytest.raises(SemanticRuntimeError):runtime.canonical_mrr_fact_content(p)
