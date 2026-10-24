# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Two adaptive continuation turns; primary four-turn failure stays censored."""
import argparse
import hashlib
import json
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceStore
from . import iterative_inference_study as loop
from .inference_effort import until_verified
from . import inference_reuse_study as study
from .model_study import provider,response_outcome
from .movie_study import provider_key,MAX_OUTPUT_TOKENS


def recover(plan_dir,results_dir,output):
    pp=plan_dir/'plan.json';rp=results_dir/'result.json'
    plan=json.loads(pp.read_text());primary=json.loads(rp.read_text())
    episode=next(e for e in primary['episodes'] if e['case']=='recursive-mentor' and e['arm']=='scheme-evidence')
    if 'pairs' not in primary or episode['effort']['verified']:raise ValueError('expected completed censored primary episode')
    case=next(c for c in plan['cases'] if c['name']==episode['case']);source=case['source']
    library=plan_dir/plan['library'];output.mkdir(parents=True,exist_ok=False)
    if hashlib.sha256(library.read_bytes()).hexdigest()!=plan['librarySha256']:raise ValueError('engine identity')
    transcript=[{'action':a.get('action'),'feedback':a.get('feedback')} for a in episode['attempts']]
    attempts=[];receipt={'schema':'ascent.iterative-evidence-recovery.v1','adaptive':True,'primaryScoresChanged':False,
        'maxAdditionalCalls':2,'primaryAttempts':len(episode['attempts']),
        'primarySha256':hashlib.sha256(rp.read_bytes()).hexdigest(),'planSha256':hashlib.sha256(pp.read_bytes()).hexdigest(),
        'producerSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'attempts':attempts}
    key=provider_key()
    with ReasoningRuntime() as engine:
        base=study.program(source,{'relations':[],'rules':[]})
        with EvidenceStore(engine,[r for r in base['relations'] if r['source']]) as evidence:
            for index in range(2):
                context={'question':case['question'],'schema':study.SCHEMA,'sourceIdentity':evidence.source_identity,'priorTurns':transcript}
                instruction=('Continue the original inference episode. The previous query selector was invalid: '
                  'queries must contain bare relation names such as ["witness"], never ["witness(X,Y,T)"]. '
                  'This is an interface correction, not a change to query intent. Source heads remain forbidden. '
                  'First submit the corrected derived witness query; then answer from the returned Scheme evidence. '
                  'No gold answers are provided. Return one JSON action.')
                req={'model':'deepseek-flash','input':[{'role':'user','content':instruction+'\n'+json.dumps(context,sort_keys=True)}],
                    'reasoning':{'effort':'high'},'max_output_tokens':MAX_OUTPUT_TOKENS,'stream':True,'store':False,
                    'text':{'format':loop.action_format(True,index==0)}}
                (output/f'{index}.request.json').write_text(json.dumps(req,indent=2)+'\n')
                raw,meta=provider(req,key,output/f'{index}.response.json');(output/f'{index}.raw.txt').write_text(raw)
                attempt={'providerCalls':1,'adaptive':True,'correct':False,'usage':(meta.get('terminal') or {}).get('usage'),
                         'providerSeconds':meta['providerSeconds'],'providerOutcome':response_outcome(meta),'requestSha256':study.identity(req)}
                attempts.append(attempt)
                if attempt['providerOutcome']!='completed_ungraded':break
                action=json.loads(raw);attempt['action']=action
                if action['action']=='query':feedback=evidence.query(loop.evidence_program(source,action))
                elif action['action']=='answer':
                    value=action['answer'];attempt['correct']=sorted([[a] for a in value])==study.expected(case,source)
                    feedback={'verification':'verified' if attempt['correct'] else 'not_verified'}
                else:feedback=evidence.scan(action['relations'])
                attempt['feedback']=feedback;transcript.append({'action':action,'feedback':feedback})
                (output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
                if attempt['correct']:break
    receipt['cumulativeEffort']=until_verified(episode['attempts']+attempts)
    receipt['outcome']='verified' if receipt['cumulativeEffort']['verified'] else 'unverified'
    (output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('ITERATIVE-EVIDENCE-RECOVERY',receipt['outcome'],flush=True)


def main():
    p=argparse.ArgumentParser()
    for name in ('plan','results','output'):p.add_argument(name,type=Path)
    a=p.parse_args();recover(a.plan,a.results,a.output)


if __name__=='__main__':main()
