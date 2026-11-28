# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Continue a censored raw-fact trajectory with its complete provider history."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from . import complex_inference_workload as workload
from .compound_inference_recovery import censored_episodes
from .inference_effort import until_verified
from .inference_reuse_study import price
from .model_study import provider,response_outcome
from .movie_study import provider_key


def continuation_history(request,terminal):
    history=ResponseHistory.restore(request['input'])
    calls=history.append_response(terminal)
    for call in calls:
        history.append_result(call['call_id'],{'error':'Incomplete response: tool not executed.'})
    history.append_feedback({'continuation':'The previous response exhausted its output ceiling without a verified answer. Continue the complete question from the retained facts and reasoning. Submit the complete actor set when ready. No gold answer is supplied.'})
    return history


def recover(plan_dir,primary_dir,output):
    plan=json.loads((plan_dir/'plan.json').read_text());primary=json.loads((primary_dir/'result.json').read_text())
    if hashlib.sha256((plan_dir/'plan.json').read_bytes()).hexdigest()!=primary['planSha256']:raise ValueError('plan identity')
    episodes=censored_episodes(primary)
    if any(e['arm']!='raw-fact-reasoning' for e in episodes):raise ValueError('This continuation supports only raw-fact control; do not silently omit assisted recovery.')
    output.mkdir(parents=True,exist_ok=False);(output/'paid-claim.json').open('x').close()
    protocol={'schema':'ascent.tool-history-recovery-plan.v1','adaptive':True,'primaryScoresChanged':False,
              'primarySha256':hashlib.sha256((primary_dir/'result.json').read_bytes()).hexdigest(),
              'maxAdditionalTurnsPerEpisode':2,'maxOutputTokens':plan['maxOutputTokens'],
              'producerSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'policy':'Same per-call ceiling; retain full incomplete reasoning and all previous tool history. Charge original exhaustion plus all continuation calls. No gold feedback.'}
    receipt={'schema':'ascent.tool-history-recovery.v1','protocol':protocol,'providerCalls':0,'additionalPeakEstimateUsd':0,'episodes':[]}
    def save():(output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    save();key=provider_key()
    for original in episodes:
        case=next(c for c in plan['cases'] if c['name']==original['case']);last=original['attempts'][-1]
        directory=primary_dir/f"{original['case']}-rep-{original['repetition']}-{original['arm']}"
        request=json.loads((directory/f"{last['turn']}.request.json").read_text())
        terminal=json.loads((directory/f"{last['turn']}.response.json").read_text())['terminal']
        history=continuation_history(request,terminal)
        episode={'case':original['case'],'repetition':original['repetition'],'arm':original['arm'],
                 'primaryEffort':original['effort'],'attempts':[]};receipt['episodes'].append(episode)
        for turn in range(1,3):
            request=copy.deepcopy(request);request['input']=history.input()
            stem=f"{case['name']}-rep-{original['repetition']}-recovery-{turn}"
            (output/(stem+'.request.json')).write_text(json.dumps(request,indent=2)+'\n')
            raw,meta=provider(request,key,output/(stem+'.response.json'));(output/(stem+'.raw.txt')).write_text(raw)
            response=meta.get('terminal')or{}
            attempt={'turn':turn,'providerCalls':1,'correct':False,'adaptive':True,'usage':response.get('usage'),
                     'providerSeconds':meta['providerSeconds'],'providerOutcome':response_outcome(meta),
                     'priorReasoningItems':history.reasoning_items}
            episode['attempts'].append(attempt);receipt['providerCalls']+=1
            if attempt['usage']:receipt['additionalPeakEstimateUsd']+=price(attempt['usage'])
            if meta.get('error') or not attempt['usage']:attempt['outcome']='provider_failure';save();raise RuntimeError('Provider failed; partial recovery preserved.')
            calls=history.append_response(response)
            feedback=[]
            for call in calls:
                try:
                    args=json.loads(call['arguments'])
                    if call['name']=='submit_answer':
                        value=args['answer'];correct=isinstance(value,list) and all(isinstance(x,str) for x in value) and sorted([[x] for x in value])==workload.expected(case,case['source'])
                        attempt['correct']|=correct;result={'verification':'verified' if correct else 'not_verified'}
                    elif call['name']=='scan_facts':
                        result={'relations':{name:case['source']['rows'][name] for name in args['relations']}}
                    else:raise ValueError('tool unavailable in raw-fact control')
                except Exception as error:result={'error':str(error)[:2048]}
                feedback.append(result);history.append_result(call['call_id'],result)
            if not calls:history.append_feedback({'guidance':'Use submit_answer with the complete actor identifier set.'})
            attempt['feedback']=feedback;attempt['outcome']='verified_answer' if attempt['correct'] else 'unverified_continuation'
            episode['additionalEffort']=until_verified(episode['attempts']);episode['cumulativeEffort']=until_verified(original['attempts']+episode['attempts']);save()
            if attempt['correct']:break


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('plan',type=Path);p.add_argument('primary',type=Path);p.add_argument('output',type=Path)
    a=p.parse_args();recover(a.plan,a.primary,a.output)
