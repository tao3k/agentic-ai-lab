# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Matched tool-mediated thinking with complete stateless Responses history."""
import argparse
import concurrent.futures
import contextlib
import copy
import hashlib
import json
import multiprocessing
import shutil
import time
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceStore
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from . import iterative_inference_study as loop
from . import inference_reuse_study as study
from . import complex_inference_workload as workload
from .inference_effort import until_verified,paired_reduction
from .movie_study import provider_key
from .model_study import provider,response_outcome

_ENGINE=None


def tool_definitions(assisted):
    choices=loop.action_format(assisted)['schema']['anyOf'];result=[]
    names={'scan':'scan_facts','query':'check_evidence','answer':'submit_answer'}
    descriptions={'scan':'Read only the named finite source relations.',
                  'query':'Check and retain executable claims in Scheme, returning source-bound evidence and aliases. Compile intent without manually enumerating joins. contract.relations contains ONLY new derived declarations, never sources or the already declared answer relation. Rules have head arrays. Query selectors are bare names. Evidence certifies rule consequences, not natural-language intent.',
                  'answer':'Submit unique actor identifiers for independent verification. Only verified/not_verified is returned.'}
    for choice in choices:
        kind=choice['properties']['action']['enum'][0]
        parameters=copy.deepcopy(choice);parameters['properties'].pop('action');parameters['required'].remove('action')
        result.append({'type':'function','name':names[kind],'description':descriptions[kind],'parameters':parameters})
    return result


def prepare(original,directory):
    plan=json.loads((original/'plan.json').read_text());directory.mkdir(parents=True,exist_ok=False)
    shutil.copy2(original/plan['library'],directory/plan['library'])
    if hashlib.sha256((directory/plan['library']).read_bytes()).hexdigest()!=plan['librarySha256']:raise ValueError('engine identity')
    paths=[Path(__file__),Path(loop.__file__),Path(study.__file__),Path(workload.__file__),
           Path(__file__).with_name('inference_effort.py'),Path(__file__).with_name('model_study.py'),
           Path(__file__).with_name('movie_study.py'),Path(__file__).with_name('query_contract.py'),
           Path(__file__).with_name('complex_movie_study.py'),
           study.ROOT/'rust/ascent/src/conversation.rs',study.ROOT/'rust/ascent-python/src/api/evidence.rs',
           study.ROOT/'rust/ascent-python/src/api/exports.rs']
    plan.update(schema='ascent.tool-thinking-plan.v1',maxOutputTokens=131072,workers=2,
                scope='Corrected tool-history development evaluation on the same frozen compound questions; follows diagnosis of the original protocol. Not a new independent holdout.',
                conservativePeakCeilingUsd=24,
                originalPlanSha256=hashlib.sha256((original/'plan.json').read_bytes()).hexdigest(),
                historyPolicy='Both arms retain complete provider reasoning/message/function_call items and matched function_call_output items. Never use unsupported server conversation ids.',
                sourceBoundary='Identical raw-fact scan and binary verifier. Additional Scheme evidence checking is available in the assisted arm. No forced subproblem or forced first query. No gold values in prompts.',
                scheduling='At most two spawned worker processes; one active provider call per process, one retained runtime per process, fresh evidence store per trajectory. Pair order counterbalanced.',
                producerHashes={str(p.relative_to(study.ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths})
    (directory/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    print('TOOL-THINKING-PREPARED','trajectories',16,'workers',2,'maxCalls',128,flush=True)


def run_episode(plan,plan_dir,output,case,rep,arm):
    global _ENGINE
    directory=output/f"{case['name']}-rep-{rep}-{arm}";directory.mkdir(exist_ok=False)
    (directory/'paid-claim.json').open('x').close()
    with (directory/'progress.txt').open('w') as log,contextlib.redirect_stdout(log):
        key=provider_key();assisted=arm=='scheme-evidence';started=time.monotonic()
        if _ENGINE is None:_ENGINE=ReasoningRuntime(plan_dir/plan['library'])
        base=study.program(case['source'],{'relations':[],'rules':[]})
        history=ResponseHistory(json.dumps({'question':case['question'],'schema':study.SCHEMA},sort_keys=True))
        episode={'case':case['name'],'repetition':rep,'arm':arm,'attempts':[],'evidenceJournal':[],
                 'protocol':'tool-mediated complete reasoning history'}
        def save():(directory/'episode.json').write_text(json.dumps(episode,indent=2)+'\n')
        instruction=('Solve the complete complex question using only supplied finite facts. No source facts are initially known; acquire facts or check evidence before answering. '
                     'Use function calls. Retain established evidence rather than repeat completed reasoning. No required subproblem decomposition. '
                     'cast relates Film to Actor, directed Film to Director, citizen Director to Country, mentor directed Actor to Actor. '
                     'Rules use head arrays; shared variables join; multiple rules union; positive recursion reaches a least fixed point; negation is stratified with variables positively bound. '
                     'answer(Actor) and source declarations already exist; contract.relations declares only new derived relations. Never define source heads. '
                     'Source-bound evidence aliases can be referenced in later rule bodies without redeclaring them. '
                     'Submit an answer with submit_answer; verifier reveals no gold values. '
                     +('Scheme checks and retains expressed reasoning evidence to support later thinking.' if assisted else 'Reason over scanned raw facts; derived query execution is unavailable.'))
        with EvidenceStore(_ENGINE,[r for r in base['relations'] if r['source']]) as evidence:
            episode['setupSeconds']=time.monotonic()-started;observed=False;save()
            for turn in range(1,plan['maxTurns']+1):
                request={'model':'deepseek-flash','instructions':instruction,'input':history.input(),
                         'tools':tool_definitions(assisted),'tool_choice':'auto','reasoning':{'effort':'high'},
                         'max_output_tokens':plan['maxOutputTokens'],'stream':True,'store':False}
                (directory/f'{turn}.request.json').write_text(json.dumps(request,indent=2)+'\n')
                print('TOOL-THINKING',case['name'],rep,arm,turn,flush=True)
                raw,meta=provider(request,key,directory/f'{turn}.response.json');(directory/f'{turn}.raw.txt').write_text(raw)
                terminal=meta.get('terminal') or {};outcome=response_outcome(meta)
                attempt={'turn':turn,'providerCalls':1,'correct':False,'usage':terminal.get('usage'),
                         'providerSeconds':meta['providerSeconds'],'providerOutcome':outcome,
                         'requestSha256':study.identity(request),'priorReasoningItems':history.reasoning_items,
                         'sourceIdentity':evidence.source_identity,'toolActions':[]}
                episode['attempts'].append(attempt);save()
                if not attempt['usage'] or meta.get('error'):raise RuntimeError('provider failure; partial trajectory preserved')
                if outcome!='completed_ungraded':attempt['outcome']=outcome;break
                calls=history.append_response(terminal)
                if not calls:
                    # Thinking mode permits auto tool choice. Final messages are
                    # graded independently; malformed prose gets typed feedback.
                    try:
                        value=json.loads(raw)
                        if isinstance(value,dict):value=value['answer']
                        if not observed:raise ValueError('acquire facts or checked evidence before answering')
                        attempt['correct']=isinstance(value,list) and all(isinstance(a,str) for a in value) and sorted([[a] for a in value])==workload.expected(case,case['source'])
                        attempt['action']={'action':'answer','answer':value}
                        feedback={'verification':'verified' if attempt['correct'] else 'not_verified'}
                        attempt['outcome']='verified_answer' if attempt['correct'] else 'answer_not_verified'
                    except Exception as error:
                        feedback={'error':str(error)[:2048],'guidance':'Use scan_facts, check_evidence if available, or submit_answer. Return actor identifiers, not prose.'}
                        attempt['outcome']='action_failure'
                    attempt['feedback']=feedback;history.append_feedback(feedback)
                    episode['effort']=until_verified(episode['attempts']);save()
                    if attempt['correct']:break
                    continue
                started=time.monotonic()
                for call in calls:
                    record={'name':call['name'],'callId':call['call_id']};attempt['toolActions'].append(record)
                    try:
                        args=json.loads(call['arguments']);record['arguments']=args
                        if call['name']=='scan_facts':
                            feedback=evidence.scan(args['relations']);observed=True;kind='scan'
                            action={'action':kind,**args}
                        elif call['name']=='check_evidence' and assisted:
                            kind='query';action={'action':kind,**args}
                            feedback=evidence.query(loop.evidence_program(case['source'],action));observed=True
                            episode['evidenceJournal'].append(feedback)
                        elif call['name']=='submit_answer':
                            kind='answer';action={'action':kind,**args}
                            if not observed:raise ValueError('acquire facts or checked evidence before answering')
                            value=args['answer'];correct=isinstance(value,list) and all(isinstance(a,str) for a in value) and sorted([[a] for a in value])==workload.expected(case,case['source'])
                            attempt['correct'] |= correct
                            feedback={'verification':'verified' if correct else 'not_verified'}
                        else:raise ValueError('tool unavailable in this arm')
                        record.update(action=action,correct=correct if kind=='answer' else False,
                                      outcome='verified_answer' if kind=='answer' and attempt['correct'] else 'answer_not_verified' if kind=='answer' else 'evidence_progress')
                    except Exception as error:
                        feedback={'error':str(error)[:2048]};record['outcome']='action_failure'
                    record['feedback']=feedback;history.append_result(call['call_id'],feedback)
                # One response may contain several calls; charge its usage once.
                attempt['outcome']='verified_answer' if attempt['correct'] else 'action_failure' if any(x['outcome']=='action_failure' for x in attempt['toolActions']) else 'answer_not_verified' if any(x['outcome']=='answer_not_verified' for x in attempt['toolActions']) else 'evidence_progress'
                if len(attempt['toolActions'])==1:
                    attempt['action']=attempt['toolActions'][0].get('action',{})
                    attempt['feedback']=attempt['toolActions'][0]['feedback']
                attempt['schemeSeconds']=time.monotonic()-started;episode['effort']=until_verified(episode['attempts']);save()
                print('TOOL-FEEDBACK',attempt['outcome'],'retainedReasoningItems',history.reasoning_items,flush=True)
                if attempt['correct']:break
        episode['effort']=until_verified(episode['attempts']);episode['evidenceAdoption']=bool(episode['evidenceJournal']);save()
    return episode


def live(directory,output):
    pp=directory/'plan.json';plan=json.loads(pp.read_text())
    for path,sha in plan['producerHashes'].items():
        if hashlib.sha256((study.ROOT/path).read_bytes()).hexdigest()!=sha:raise ValueError('producer changed')
    if hashlib.sha256((directory/plan['library']).read_bytes()).hexdigest()!=plan['librarySha256']:raise ValueError('engine changed')
    output.mkdir(parents=True,exist_ok=False);(directory/'paid-claim.json').open('x').close()
    receipt={'schema':'ascent.tool-thinking-result.v1','planSha256':hashlib.sha256(pp.read_bytes()).hexdigest(),
             'scope':plan['scope'],'providerCalls':0,'peakEstimateUsd':0,'episodes':[]}
    def save():(output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    save();jobs=[]
    for ci,case in enumerate(plan['cases']):
        for rep in range(plan['repetitions']):
            arms=plan['arms'] if rep%2==0 else list(reversed(plan['arms']))
            jobs.extend((case,rep,arm) for arm in arms)
    with concurrent.futures.ProcessPoolExecutor(max_workers=plan['workers'],mp_context=multiprocessing.get_context('spawn')) as pool:
        iterator=iter(jobs)
        pending={pool.submit(run_episode,plan,directory,output,*next(iterator)) for _ in range(min(plan['workers'],len(jobs)))}
        while pending:
            done,pending=concurrent.futures.wait(pending,return_when=concurrent.futures.FIRST_COMPLETED)
            for future in done:
                episode=future.result();receipt['episodes'].append(episode)
                receipt['providerCalls']+=sum(a['providerCalls'] for a in episode['attempts'])
                receipt['peakEstimateUsd']+=sum(study.price(a['usage']) for a in episode['attempts'] if a.get('usage'))
                save();print('TOOL-EPISODE-COMPLETE',episode['case'],episode['repetition'],episode['arm'],episode['effort'],flush=True)
                job=next(iterator,None)
                if job is not None:pending.add(pool.submit(run_episode,plan,directory,output,*job))
    receipt['episodes'].sort(key=lambda e:(e['case'],e['repetition'],e['arm']))
    pairs=[]
    for case in plan['cases']:
        for rep in range(plan['repetitions']):
            b,a=[next(e['effort'] for e in receipt['episodes'] if e['case']==case['name'] and e['repetition']==rep and e['arm']==arm) for arm in plan['arms']]
            pairs.append({'case':case['name'],'repetition':rep,'baseline':b,'assisted':a,'reasoningTokenReduction':paired_reduction(b,a,'observedReasoningTokens')})
    receipt['pairs']=pairs;save();print('TOOL-THINKING-COMPLETE',receipt['providerCalls'],flush=True)


def main():
    p=argparse.ArgumentParser();p.add_argument('mode',choices=('prepare','live'));p.add_argument('directory',type=Path);p.add_argument('target',type=Path)
    a=p.parse_args()
    if a.mode=='prepare':prepare(a.directory.resolve(),a.target.resolve())
    else:live(a.directory.resolve(),a.target.resolve())


if __name__=='__main__':main()
