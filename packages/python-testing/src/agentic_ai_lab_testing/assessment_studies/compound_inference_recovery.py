# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Adaptive continuation of censored episodes; frozen primary scores never change."""
import argparse
import copy
import hashlib
import json
import time
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceStore
from . import iterative_inference_study as loop
from . import inference_reuse_study as study
from . import complex_inference_workload as workload
from .inference_effort import until_verified
from .model_study import provider,response_outcome
from .movie_study import provider_key


def censored_episodes(primary):
    if 'pairs' not in primary:raise ValueError('primary study must finish before adaptive recovery')
    return [e for e in primary['episodes'] if not e['effort']['verified']]


def recover(plan_dir,primary_dir,output):
    pp=plan_dir/'plan.json';rp=primary_dir/'result.json'
    plan=json.loads(pp.read_text());primary=json.loads(rp.read_text());failed=censored_episodes(primary)
    if hashlib.sha256(pp.read_bytes()).hexdigest()!=primary['planSha256']:raise ValueError('plan identity')
    library=plan_dir/plan['library']
    if hashlib.sha256(library.read_bytes()).hexdigest()!=plan['librarySha256']:raise ValueError('engine identity')
    output.mkdir(parents=True,exist_ok=False)
    protocol={'schema':'ascent.compound-inference-recovery-plan.v1','adaptive':True,
              'primaryScoresChanged':False,'primarySha256':hashlib.sha256(rp.read_bytes()).hexdigest(),
              'originalPlanSha256':primary['planSha256'],'maxAdditionalTurnsPerEpisode':2,
              'maxOutputTokens':131072,'maxProviderCalls':len(failed)*2,
              'episodes':[{'case':e['case'],'repetition':e['repetition'],'arm':e['arm']} for e in failed],
              'producerSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'policy':'Continue every censored episode with the same facts, schema, action set and binary verifier, increasing the output ceiling. No gold feedback, no replacing original outcomes, and every original failed token stays charged.'}
    (output/'plan.json').write_text(json.dumps(protocol,indent=2)+'\n');(output/'paid-claim.json').open('x').close()
    key=provider_key();receipt={'schema':'ascent.compound-inference-recovery.v1','protocol':protocol,
                              'providerCalls':0,'additionalPeakEstimateUsd':0,'episodes':[]}
    def save():(output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    save()
    with ReasoningRuntime() as engine:
        for episode in failed:
            case=next(c for c in plan['cases'] if c['name']==episode['case']);source=case['source']
            assisted=episode['arm']=='scheme-evidence'
            recovered={'case':episode['case'],'repetition':episode['repetition'],'arm':episode['arm'],
                       'primaryEffort':episode['effort'],'attempts':[]};receipt['episodes'].append(recovered)
            transcript=[{'action':a.get('action'),'feedback':a.get('feedback') or {'outcome':a.get('outcome')}} for a in episode['attempts']]
            last=episode['attempts'][-1];stem=f"{case['name']}-rep-{episode['repetition']}-{episode['arm']}-{last['turn']}"
            previous_request=json.loads((primary_dir/(stem+'.request.json')).read_text())
            instruction=previous_request['input'][0]['content'].split('\n',1)[0]
            base=study.program(source,{'relations':[],'rules':[]});started=time.monotonic()
            with EvidenceStore(engine,[r for r in base['relations'] if r['source']]) as evidence:
                # Restore only the model's actually admitted programs. No gold
                # query is introduced by this recovery client.
                for a in episode['attempts']:
                    if a.get('outcome')=='evidence_progress' and a.get('action',{}).get('action')=='query':
                        restored=evidence.query(loop.evidence_program(source,a['action']))
                        if restored['pathIdentity']!=a['feedback']['pathIdentity']:raise ValueError('evidence replay identity')
                recovered['setupSeconds']=time.monotonic()-started
                for turn in range(1,3):
                    context={'question':case['question'],'schema':study.SCHEMA,'sourceIdentity':evidence.source_identity,
                             'priorTurns':transcript,'remainingTurns':3-turn,'adaptiveRecovery':True}
                    request=copy.deepcopy(previous_request)
                    request['max_output_tokens']=protocol['maxOutputTokens'];request['text']={'format':loop.action_format(assisted)}
                    request['input']=[{'role':'user','content':instruction+
                        ' This is adaptive continuation of the unverified episode with a higher output ceiling. Continue reasoning from the same external facts and evidence; no gold answers are provided.\n'+json.dumps(context,sort_keys=True)}]
                    name=f"{case['name']}-rep-{episode['repetition']}-{episode['arm']}-recovery-{turn}"
                    (output/(name+'.request.json')).write_text(json.dumps(request,indent=2)+'\n')
                    print('COMPOUND-RECOVERY',case['name'],episode['repetition'],episode['arm'],turn,flush=True)
                    raw,meta=provider(request,key,output/(name+'.response.json'));(output/(name+'.raw.txt')).write_text(raw)
                    outcome=response_outcome(meta);usage=(meta.get('terminal') or {}).get('usage')
                    attempt={'turn':turn,'providerCalls':1,'adaptive':True,'correct':False,'usage':usage,
                             'providerSeconds':meta['providerSeconds'],'providerOutcome':outcome,'requestSha256':study.identity(request)}
                    recovered['attempts'].append(attempt);receipt['providerCalls']+=1
                    if usage:receipt['additionalPeakEstimateUsd']+=study.price(usage)
                    save()
                    if not usage or meta.get('error'):raise RuntimeError('provider failure; partial recovery receipt preserved')
                    if outcome!='completed_ungraded':attempt['outcome']=outcome;break
                    started=time.monotonic()
                    try:
                        action=json.loads(raw);attempt['action']=action;kind=action.get('action')
                        if kind=='scan':feedback=evidence.scan(action['relations'])
                        elif kind=='query' and assisted:feedback=evidence.query(loop.evidence_program(source,action))
                        elif kind=='answer':
                            value=action['answer'];attempt['correct']=isinstance(value,list) and all(isinstance(a,str) for a in value) and sorted([[a] for a in value])==workload.expected(case,source)
                            feedback={'verification':'verified' if attempt['correct'] else 'not_verified'}
                        else:raise ValueError('action unavailable in this arm')
                        attempt['outcome']='verified_answer' if attempt['correct'] else 'answer_not_verified' if kind=='answer' else 'evidence_progress'
                    except Exception as error:feedback={'error':str(error)[:2048]};attempt['outcome']='action_failure'
                    attempt['feedback']=feedback;attempt['schemeSeconds']=time.monotonic()-started
                    transcript.append({'action':attempt.get('action'),'feedback':feedback})
                    recovered['cumulativeEffort']=until_verified(episode['attempts']+recovered['attempts']);save()
                    if attempt['correct']:break
            recovered['cumulativeEffort']=until_verified(episode['attempts']+recovered['attempts'])
            recovered['additionalEffort']=until_verified(recovered['attempts']);save()
    receipt['completed']=True;save();print('COMPOUND-RECOVERY-COMPLETE',receipt['providerCalls'],flush=True)


def main():
    p=argparse.ArgumentParser()
    for n in ('plan','primary','output'):p.add_argument(n,type=Path)
    a=p.parse_args();recover(a.plan,a.primary,a.output)


if __name__=='__main__':main()
