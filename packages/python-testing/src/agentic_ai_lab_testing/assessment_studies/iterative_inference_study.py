# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Scheme evidence in the model's inference loop, measured until verified answer."""
import argparse
import hashlib
import json
import shutil
import time
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceStore
from . import inference_reuse_study as study
from . import complex_inference_workload as complex_workload
from .inference_effort import until_verified,paired_reduction
from .query_contract import output_format
from .model_study import provider,response_outcome
from .movie_study import provider_key,MAX_OUTPUT_TOKENS


def action_format(assisted,initial=False):
    def obj(properties):return {'type':'object','properties':properties,'required':list(properties),'additionalProperties':False}
    text={'type':'string'}
    relation_name={'type':'string','pattern':'^[A-Za-z_][A-Za-z0-9_-]*$'}
    choices=[obj({'action':{'enum':['scan']},'relations':{'type':'array','items':{'enum':list(study.SCHEMA)},'minItems':1}}),
             obj({'action':{'enum':['answer']},'answer':{'type':'array','items':text}})]
    if assisted:choices.append(obj({'action':{'enum':['query']},'contract':output_format()['schema'],
                    'queries':{'type':'array','items':relation_name,'minItems':1,'maxItems':16}}))
    if initial:choices=[choice for choice in choices if choice['properties']['action']['enum']!=['answer']]
    return {'type':'json_schema','name':'ascent_inference_action','schema':{'anyOf':choices}}


def evidence_program(source,action):
    p=study.program(source,action['contract']);p['queries']=action['queries']
    derived={r['name']:r for r in p['relations'] if not r['source']}
    for name in p['queries']:
        if '(' in name or ')' in name:
            raise ValueError('queries requires bare relation names, e.g. ["witness"], not ["witness(X,Y,T)"]; full rows are returned')
    if any(name not in derived for name in p['queries']):raise ValueError('use scan for raw relations; query must build derived evidence')
    return p


def prepare(directory,library):
    directory.mkdir(parents=True,exist_ok=False);shutil.copy2(library,directory/library.name)
    paths=[Path(__file__),Path(study.__file__),Path(__file__).with_name('inference_effort.py'),Path(complex_workload.__file__),
           Path(__file__).with_name('model_study.py'),Path(__file__).with_name('movie_study.py'),
           Path(__file__).with_name('query_contract.py'),study.ROOT/'rust/ascent-python/src/api/evidence.rs',
           study.ROOT/'rust/ascent-python/src/api/exports.rs']
    plan={'schema':'ascent.iterative-inference-plan.v2','maxTurns':8,'maxProviderCalls':128,
          'maxOutputTokens':MAX_OUTPUT_TOKENS,'conservativePeakCeilingUsd':12,
          'library':library.name,'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest(),
          'cases':[complex_workload.workload(i,20261010+i*101) for i in range(4)],
          'repetitions':2,
          'arms':['raw-fact-reasoning','scheme-evidence'],
          'scope':'Frozen synthetic compound tasks with opaque entities; two trials per task. Newly designed evaluation, not an independently annotated real-world benchmark.',
          'primaryMetric':'First independently verified answer: model turns and cumulative input/output/reasoning tokens, including scans, queries, failed answers and correction. Unsatisfied episodes are censored.',
          'sourceBoundary':'Both arms can scan identical raw facts. Assisted reasoning may submit executable claims for Scheme checking and retention at any round; no mandatory subproblem decomposition or forced evidence-first action. Untreated assisted episodes remain in the assigned-arm denominator.',
          'mechanism':'The model reasons about the complete complex question. Scheme checks and retains externally expressed claims against admitted facts and rules. Source-bound evidence supports subsequent thinking; hidden model thoughts are neither read nor certified.',
          'verificationFeedback':'Only verified or not_verified; no gold answers or missing-actor list.',
          'producerHashes':{str(p.relative_to(study.ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
    with ReasoningRuntime(directory/library.name) as engine:
        for case in plan['cases']:
            for source in (case['source'],study.updated(case)):
                with engine.open(study.program(source,complex_workload.oracle_contract(case))) as session:
                    result=session.run()
                    if not result['complete'] or sorted(result['relations']['answer'])!=complex_workload.expected(case,source):
                        raise ValueError('compound-task oracle disagreement')
            print('COMPLEX-ORACLE',case['name'],len(complex_workload.expected(case,case['source'])),flush=True)
    (directory/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')


def live(directory,output):
    pp=directory/'plan.json';plan=json.loads(pp.read_text());library=directory/plan['library']
    for name,sha in plan['producerHashes'].items():
        if hashlib.sha256((study.ROOT/name).read_bytes()).hexdigest()!=sha:raise ValueError('producer changed')
    if hashlib.sha256(library.read_bytes()).hexdigest()!=plan['librarySha256']:raise ValueError('library changed')
    if plan['maxProviderCalls']!=len(plan['cases'])*len(plan['arms'])*plan['repetitions']*plan['maxTurns']:raise ValueError('plan bounds')
    key=provider_key();output.mkdir(parents=True,exist_ok=False);(directory/'paid-claim.json').open('x').close()
    receipt={'schema':'ascent.iterative-inference-result.v1','planSha256':hashlib.sha256(pp.read_bytes()).hexdigest(),
             'scope':plan['scope'],'providerCalls':0,'peakEstimateUsd':0,'episodes':[]}
    def save():(output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    with ReasoningRuntime() as engine:
        trials=[(case,rep) for case in plan['cases'] for rep in range(plan['repetitions'])]
        for ci,(case,rep) in enumerate(trials):
            arms=plan['arms'] if ci%2==0 else list(reversed(plan['arms']))
            for arm in arms:
                episode={'case':case['name'],'repetition':rep,'arm':arm,'attempts':[],'evidenceJournal':[]}
                receipt['episodes'].append(episode)
                source=case['source'];assisted=arm=='scheme-evidence'
                base=study.program(source,{'relations':[],'rules':[]})
                trusted=[r for r in base['relations'] if r['source']]
                transcript=[]
                with EvidenceStore(engine,trusted) as evidence:
                    for turn in range(1,plan['maxTurns']+1):
                        context={'question':case['question'],'schema':study.SCHEMA,'sourceIdentity':evidence.source_identity,
                                 'priorTurns':transcript,'remainingTurns':plan['maxTurns']-turn+1}
                        instruction=('Reason about the complete complex question and choose one externally observable action: scan raw source relations, '
                            +('submit executable reasoning claims to Scheme for checking and retention, ' if assisted else '')+'or answer with unique actor identifiers. '
                            'No source facts are initially known; scan or query before answering. '
                            'Use source-bound verified evidence to enhance your next reasoning round, avoiding repeated joins and rejected branches. There is no required subproblem decomposition. Do not repeat completed work. '
                            'Rules use head arrays, shared variables join, multiple rules union, positive recursion reaches a least fixed point, '
                            'and stratified negation tests absence. Never define source heads. '
                            'answer(Actor) is already declared; declare every other derived relation with types. '
                            'Queries may return derived witness relations with Film/Actor/Director/Country columns. '
                            'queries must contain bare relation names, e.g. ["witness"], never "witness(X,Y,T)". '
                            'Retain supporting witness variables when useful for later verification or correction; unary checked claims are also allowed. Scheme certifies consequences of your admitted rules, not that those rules match the question. '
                            'publishedEvidence contains trusted subgoal relation aliases tied to the current source. Use them in later rule bodies without redeclaring them or defining their heads; extend established paths instead of repeating their rules. '
                            +('Scheme is available to check and retain your expressed reasoning evidence; choose when it can improve subsequent thinking. ' if assisted else
                              'Reason over scanned raw facts yourself. Derived query execution is unavailable. ')
                            +'The verifier returns no gold answers. Return only one JSON action.')
                        if turn==1:instruction+=' Acquire facts or check an executable claim before submitting a final answer.'
                        req={'model':'deepseek-flash','input':[{'role':'user','content':instruction+'\n'+json.dumps(context,sort_keys=True)}],
                             'reasoning':{'effort':'high'},'max_output_tokens':MAX_OUTPUT_TOKENS,'stream':True,'store':False,
                             'text':{'format':action_format(assisted,turn==1)}}
                        stem=f'{case["name"]}-rep-{rep}-{arm}-{turn}'
                        (output/(stem+'.request.json')).write_text(json.dumps(req,indent=2)+'\n')
                        print('ITERATIVE-TURN',case['name'],arm,turn,'/',plan['maxTurns'],flush=True)
                        raw,meta=provider(req,key,output/(stem+'.response.json'));(output/(stem+'.raw.txt')).write_text(raw)
                        usage=(meta.get('terminal') or {}).get('usage');outcome=response_outcome(meta)
                        attempt={'turn':turn,'providerCalls':1,'requestSha256':study.identity(req),
                                 'usage':usage,'providerSeconds':meta['providerSeconds'],'providerOutcome':outcome,
                                 'correct':False,'sourceIdentity':evidence.source_identity}
                        episode['attempts'].append(attempt);receipt['providerCalls']+=1
                        if usage:receipt['peakEstimateUsd']+=study.price(usage)
                        save()
                        if not usage or meta.get('error') or (meta.get('terminal') or {}).get('status')=='failed':
                            raise RuntimeError('provider/usage failure; partial receipt retained')
                        if outcome!='completed_ungraded':attempt['outcome']=outcome;break
                        started=time.monotonic()
                        try:
                            action=json.loads(raw);kind=action['action'];attempt['action']=action
                            if kind=='scan':feedback=evidence.scan(action['relations'])
                            elif kind=='query' and assisted:
                                p=evidence_program(source,action)
                                feedback=evidence.query(p);episode['evidenceJournal'].append(feedback)
                            elif kind=='answer':
                                value=action['answer']
                                correct=isinstance(value,list) and all(isinstance(a,str) for a in value) and sorted([[a] for a in value])==complex_workload.expected(case,source)
                                attempt['correct']=correct
                                feedback={'verification':'verified' if correct else 'not_verified'}
                            else:raise ValueError('action unavailable in this arm')
                            attempt.update(outcome='verified_answer' if attempt['correct'] else 'evidence_progress' if kind!='answer' else 'answer_not_verified',feedback=feedback)
                        except Exception as error:feedback={'error':str(error)[:2048]};attempt.update(outcome='action_failure',feedback=feedback)
                        attempt['schemeSeconds']=time.monotonic()-started
                        transcript.append({'action':action if 'action' in attempt else raw,'feedback':feedback})
                        episode['effort']=until_verified(episode['attempts'])
                        save()
                        print('ITERATIVE-FEEDBACK',attempt['outcome'],flush=True)
                        if attempt['correct']:break
                episode['effort']=until_verified(episode['attempts'])
                episode['evidenceAdoption']=bool(episode['evidenceJournal'])
                save()
    pairs=[]
    for case,rep in trials:
        baseline=next(e['effort'] for e in receipt['episodes'] if e['case']==case['name'] and e['repetition']==rep and e['arm']=='raw-fact-reasoning')
        assisted=next(e['effort'] for e in receipt['episodes'] if e['case']==case['name'] and e['repetition']==rep and e['arm']=='scheme-evidence')
        pairs.append({'case':case['name'],'repetition':rep,'baseline':baseline,'assisted':assisted,
                      'modelTurnReduction':paired_reduction(baseline,assisted,'modelCalls'),
                      'reasoningTokenReduction':paired_reduction(baseline,assisted,'observedReasoningTokens'),
                      'allModelTokenReduction':paired_reduction(baseline,assisted,'totalModelTokens')})
    receipt['pairs']=pairs;save();print('ITERATIVE-COMPLETE',receipt['providerCalls'],flush=True)


def main():
    p=argparse.ArgumentParser();p.add_argument('mode',choices=('prepare','live'));p.add_argument('directory',type=Path)
    p.add_argument('target',type=Path);a=p.parse_args()
    if a.mode=='prepare':prepare(a.directory.resolve(),a.target.resolve())
    else:live(a.directory.resolve(),a.target.resolve())


if __name__=='__main__':main()
