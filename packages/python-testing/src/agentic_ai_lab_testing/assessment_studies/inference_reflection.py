# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""One separately scored failure reflection after the frozen primary completes."""
import argparse
import hashlib
import json
from pathlib import Path
from ascent import Engine
from . import inference_reuse_study as study
from .movie_study import provider_key
from .model_study import provider, response_outcome


def reflect(plan_dir,results_dir,library,output):
    plan_path=plan_dir/'plan.json';result_path=results_dir/'result.json'
    plan=json.loads(plan_path.read_text());results=json.loads(result_path.read_text())
    if results['providerCalls']!=32 or 'summary' not in results:raise ValueError('primary not complete')
    failure=next(r for r in results['records'] if r['arm']=='direct' and r['outcome']=='answer_mismatch')
    case=next(c for c in plan['cases'] if c['name']==failure['case'])
    source=study.updated(case) if failure['phase']=='updated' else case['source']
    raw_path=results_dir/f'{failure["case"]}-{failure["repetition"]}-direct-{failure["phase"]}.raw.txt'
    original=json.loads(raw_path.read_text())
    req=study.request(case,source,'direct')
    req['input'][0]['content']+=('\nIndependent execution found your previous answer incorrect. '
        'Reflect using the original finite facts and question. Diagnose the error, return a corrected answer, '
        'and propose concrete search/relational-execution checks to prevent this class of failure. '
        'No gold answers or missing-actor list is supplied. Previous answer:\n'+json.dumps(original))
    properties={'diagnosis':{'type':'string'},'correctedAnswer':{'type':'array','items':{'type':'string'}},
                'proposedChecks':{'type':'array','items':{'type':'string'}}}
    req['text']={'format':{'type':'json_schema','name':'inference_failure_reflection',
        'schema':{'type':'object','properties':properties,'required':list(properties),'additionalProperties':False}}}
    output.mkdir(parents=True,exist_ok=False)
    (output/'request.json').write_text(json.dumps(req,indent=2)+'\n')
    receipt={'schema':'ascent.inference-reuse-reflection.v1','primaryScoresChanged':False,
             'goldAnswersSupplied':False,'maxCalls':1,'failure':failure,
             'planSha256':hashlib.sha256(plan_path.read_bytes()).hexdigest(),
             'resultSha256':hashlib.sha256(result_path.read_bytes()).hexdigest(),
             'requestSha256':study.identity(req),'producerSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
             'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest()}
    raw,meta=provider(req,provider_key(),output/'response.json');(output/'raw.txt').write_text(raw)
    receipt.update(outcome=response_outcome(meta),usage=(meta.get('terminal') or {}).get('usage'),providerSeconds=meta['providerSeconds'])
    if receipt['usage']:receipt['peakEstimateUsd']=study.price(receipt['usage'])
    if receipt['outcome']=='completed_ungraded':
        reflection=json.loads(raw);answer=reflection['correctedAnswer']
        correct=all(isinstance(a,str) for a in answer) and sorted([[a] for a in answer])==study.expected(case,source)
        receipt.update(outcome='correct' if correct else 'answer_mismatch',reflection=reflection)
    # Search the actual Scheme support relation for missed-answer witnesses.
    if case['name']=='mentor-chain':
        contract=study.oracle_contract(case)
        contract['relations']=[{'name':'support','types':['Actor','Actor','Actor','Film','Director','Country']}]
        contract['rules']=[study.rule(study.atom('support',*[study.var(n) for n in ('a','b','c','f','d','k')]),
                                      *contract['rules'][0]['body'])]
        p=study.program(source,contract);p['queries']=['support']
        with Engine() as engine:
            with engine.open(p) as session:
                result=session.run()
                if not result['complete']:raise ValueError('support search incomplete')
                missed={r[0] for r in study.expected(case,source)}-set(original)
                receipt['schemeMissingAnswerWitnesses']=[r for r in result['relations']['support'] if r[0] in missed]
    (output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('INFERENCE-REFLECTION',receipt['outcome'],flush=True)


def main():
    p=argparse.ArgumentParser()
    for name in ('plan','results','library','output'):p.add_argument(name,type=Path)
    a=p.parse_args();reflect(a.plan,a.results,a.library,a.output)


if __name__=='__main__':main()
