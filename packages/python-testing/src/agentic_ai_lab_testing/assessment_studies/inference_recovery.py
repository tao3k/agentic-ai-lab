# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Adaptive single-rule recovery probe; never a held-out primary score."""
import argparse
import hashlib
import json
from pathlib import Path
from ascent import Engine
from . import inference_reuse_study as study
from .model_study import provider,response_outcome
from .movie_study import provider_key


def recover(plan_dir,results_dir,library,output):
    plan_path=plan_dir/'plan.json';result_path=results_dir/'result.json'
    plan=json.loads(plan_path.read_text());primary=json.loads(result_path.read_text())
    if primary['providerCalls']!=32 or 'summary' not in primary:raise ValueError('primary not complete')
    case=next(c for c in plan['cases'] if c['name']=='witness-local-exclusion')
    req=study.request(case,case['source'],'compact')
    req['input'][0]['content']+=('\nAdaptive recovery after an incomplete response consumed its entire reasoning budget. '
        'The question is a single existential conjunction with a witness-local negative film test. '
        'Use one answer rule and no auxiliary relations. Retain the film witness until the banned_film test, '
        'with shared film and director variables across the positive atoms. Return the contract directly. '
        'No source rows or gold answers are provided.')
    schema=req['text']['format']['schema']
    schema['properties']['relations']['maxItems']=0
    schema['properties']['rules'].update(minItems=1,maxItems=1)
    output.mkdir(parents=True,exist_ok=False)
    (output/'request.json').write_text(json.dumps(req,indent=2)+'\n')
    raw,meta=provider(req,provider_key(),output/'response.json');(output/'raw.txt').write_text(raw)
    usage=(meta.get('terminal') or {}).get('usage')
    result={'schema':'ascent.inference-budget-recovery.v1','primaryScoresChanged':False,
        'purpose':'adaptive operator decomposition; not a held-out score','goldAnswersSupplied':False,
        'maxCalls':1,'requestSha256':study.identity(req),'usage':usage,
        'producerSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'planSha256':hashlib.sha256(plan_path.read_bytes()).hexdigest(),
        'primarySha256':hashlib.sha256(result_path.read_bytes()).hexdigest(),
        'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest(),
        'providerSeconds':meta['providerSeconds'],'outcome':response_outcome(meta),
        'peakEstimateUsd':study.price(usage) if usage else None,'checks':[]}
    if result['outcome']=='completed_ungraded':
        try:
            contract=json.loads(raw)
            with Engine() as engine:
                with engine.open(study.program(case['source'],contract)) as session:
                    for phase in ('cold','repeat','updated'):
                        source=study.updated(case) if phase=='updated' else case['source']
                        if phase=='updated':session.replace([{'relation':n,'rows':r} for n,r in source['rows'].items()])
                        actual=session.run(0 if phase=='repeat' else 1000000000)
                        correct=actual['complete'] and sorted(actual['relations']['answer'])==study.expected(case,source)
                        result['checks'].append({'phase':phase,'correct':correct,'answers':actual['relations']['answer']})
            result.update(contract=contract,outcome='correct' if all(c['correct'] for c in result['checks']) else 'answer_mismatch')
        except Exception as error:result.update(outcome='admission_or_execution_failure',failure=str(error)[:2048])
    (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print('INFERENCE-BUDGET-RECOVERY',result['outcome'],flush=True)


def main():
    p=argparse.ArgumentParser()
    for name in ('plan','results','library','output'):p.add_argument(name,type=Path)
    a=p.parse_args();recover(a.plan,a.results,a.library,a.output)


if __name__=='__main__':main()
