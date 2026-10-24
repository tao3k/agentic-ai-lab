# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""First-round evidence tools, independent truths, and whole-task ledgers."""
import argparse
import sys
import contextlib
import copy
import hashlib
import io
import json
import random
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceOperation, EvidenceInteraction, EvidenceConversation
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import identity
from .correction_study import balanced, tagged
from .trajectory_study import atom, rule, relation, extract
from .consumption_study import oracle as balanced_oracle
from .model_study import provider
from .movie_study import provider_key


def tagged_oracle(sources):
    s={r['name']:set(map(tuple,r['rows'])) for r in sources}
    flow=set(s['start']);permit=set(s['permission'])
    while True:
        p=permit|{(y,t) for x,y,t in s['grant'] if (x,t) in flow and (y,t) not in s['blocked']}
        f=flow|{(y,t) for x,y in s['edge'] for a,t in flow if x==a and (y,t) in p and (y,t) not in s['blocked']}
        f|={(x,u) for x,t,u in s['convert'] if (x,t) in flow and (x,u) not in s['blocked']}
        if (f,p)==(flow,permit):return f,p
        flow,permit=f,p


def corpus(seed_offset=0):
    cases=[balanced(2026106301+seed_offset,30,4,40),tagged(2026106302+seed_offset,True)]
    for c in cases:
        # Opaque identifiers remove construction ordinal hints.
        rng=random.Random(c['seed']+819);needs=next(s for s in c['sources'] if s['name']=='needs')
        needs['rows']=needs['rows'][:40]
        mapping={r[0]:f'job_{rng.getrandbits(64):016x}' for r in needs['rows']}
        for s in c['sources']:s['rows']=[[mapping.get(x,x) for x in r] for r in s['rows']]
        base=copy.deepcopy(c['program']);base['rules']=base['rules'][:-1]
        base['relations']=copy.deepcopy(c['sources'])+[r for r in base['relations'] if not r['source'] and r['name']!='answer']
        base['queries']=c['intermediates']
        if c['family']=='context-balanced-paths':
            description=('Balanced(c,x,y) is the LEAST relation containing supplied epsilon pairs in context c, closed under concatenation '
                         'and matching opening(x,a,k), balanced(c,a,b), closing(b,y,k). Both wrapping edges must not be denied in c. '
                         'Opening and closing labels must match; denial is scoped to the exact context and edge. Cycles require a fixed point. '
                         'needs(job,c,x,y,d,u,v) asks for those two paths. bridge(z,y) is an ordinary directed edge, not a balanced segment.')
            goals=['Return every non-excluded job for which BOTH requested balanced paths exist.',
                   'Select all eligible jobs with a balanced first request and a balanced second request, each in its own context. Omit excluded jobs. This is the same intent expressed differently.',
                   'After the source update, return every non-excluded job for which SOME balanced segment from x to z in context c is followed by bridge(z,y), AND the second requested balanced path exists. Recheck old support.']
            bridged=relation('bridged',False,3)
            base['relations'].append(bridged)
            base['rules'].append(rule(atom('bridged','c','x','y'),atom('balanced','c','x','z'),atom('bridge','z','y')))
            operations={'balanced':EvidenceOperation(base,'balanced','Arguments [context,from,to]: a context-specific balanced path exists.',True),
                        'bridged':EvidenceOperation(base,'bridged','Arguments [context,from,to]: some balanced prefix followed by one bridge exists.',True)}
        else:
            description=('flow and permit are mutually recursive LEAST relations. start(node,tag) seeds flow, permission(node,tag) seeds permit. '
                         'A flow(x,t) and grant(x,y,t) give permit(y,t) when blocked(y,t) is absent. '
                         'A flow(x,t), edge(x,y), and permit(y,t) give flow(y,t) when blocked(y,t) is absent. '
                         'A flow(x,t) and convert(x,t,u) give flow(x,u) when blocked(x,u) is absent. '
                         'Blocking is tag-specific; start and permission seeds are unconditional. needs(job,x,t,y,u,z,v,w,q) requires all four flow facts.')
            goals=['Return every non-excluded job whose FOUR requested flow facts all hold.',
                   'Return the complete set of eligible jobs for which each of the four listed node/tag states is reachable by flow. Exclude the excluded jobs. This repeats the same intent.',
                   'After the source update, return every non-excluded job whose FOUR requested flow facts all hold. Recheck old support.']
            operations={n:EvidenceOperation(base,n,'Arguments [node,tag]: the local '+n+' condition holds under the mutually recursive least fixed point.',True) for n in ('flow','permit')}
        changed=copy.deepcopy(c['sources'])
        # Withdraw or change actual assumptions, independently of model behavior.
        if c['family']=='context-balanced-paths':
            next(s for s in changed if s['name']=='denied')['rows']+=[[context[0],x,y] for context in next(s for s in changed if s['name']=='context')['rows'] for x,y,k in next(s for s in changed if s['name']=='opening')['rows'][:8]]
        else:
            next(s for s in changed if s['name']=='start')['rows']=next(s for s in changed if s['name']=='start')['rows'][:2]
            next(s for s in changed if s['name']=='grant')['rows']=next(s for s in changed if s['name']=='grant')['rows'][::3]
        c.update(base=base,operations=operations,description=description,goals=goals,changed=changed)
        c['gold']=[gold(c,c['sources'],False),gold(c,c['sources'],False),gold(c,changed,True)]
        assert c['gold'][0] and c['gold'][0]!=c['gold'][2]
    return cases


def gold(case,sources,updated):
    s={r['name']:r['rows'] for r in sources};excluded={r[0] for r in s['excluded']}
    if case['family']=='context-balanced-paths':
        pairs=balanced_oracle(sources)
        return sorted(j for j,c,x,y,d,u,v in s['needs'] if j not in excluded and (d,u,v) in pairs and
                      (any((c,x,z) in pairs and b==y for z,b in s['bridge']) if updated else (c,x,y) in pairs))
    flow,_=tagged_oracle(sources)
    return sorted(row[0] for row in s['needs'] if row[0] not in excluded and all(tuple(row[i:i+2]) in flow for i in range(1,9,2)))


def public(case):
    return {k:v for k,v in case.items() if k in ('case','seed','family','sources','changed','description','goals','gold','complexity')}


def obligation_acceptance(verdicts):
    """Later correction of the same unchanged goal resolves its earlier error.

    Only stages 0/1 have a benchmark-declared identical finite contract.
    A stage-0 success cannot answer the subsequently issued paraphrase; a
    stage-2 answer uses changed sources and cannot repair an earlier obligation.
    """
    accepted=[False]*3;first=[None]*3
    for verdict in verdicts:
        if not verdict['correct']:continue
        stage=verdict['stage']
        for index in ([0,1] if stage==1 else [stage]):
            if not accepted[index]:first[index]=verdict['providerCall']
            accepted[index]=True
    return accepted,first


def run(library,output,*,live=False,index=0,arm='retained',resume_prefix=None,failed_prefix=None,checkpoint_prefix=None,seed_offset=0):
    output.mkdir(parents=True,exist_ok=False);case=corpus(seed_offset)[index]
    paths=[__file__,'rust/ascent-python/src/api/evidence_conversation.rs','rust/ascent-python/src/api/trajectory.rs',
           'rust/ascent/src/derivations.rs','program/trajectory.ss','program/evidence-dag.ss']
    plan={'schema':'ascent.interactive-study.v1','case':public(case),'arm':arm,'model':'deepseek-flash',
          'maxOutputTokens':131072,'maxCallsPerStage':8,'maxFinalFailuresPerStage':3,
          'endpoint':'Entire three-stage task: all calls through first independently correct answer for every stage, including source update and repairs.',
          'sourceHashes':{p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in paths},
          'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest(),'strictOutputSchema':False,
          'runtimeInteractionSource':sys.modules[EvidenceInteraction.__module__].__file__,
          'runtimeInteractionSha256':hashlib.sha256(Path(sys.modules[EvidenceInteraction.__module__].__file__).read_bytes()).hexdigest(),
          'interpretation':'Fresh and retained expose identical domain checks from round one; source-only exposes ground source checks. No model query synthesis.',
          'replayedFirstCallFrom':str(resume_prefix) if resume_prefix is not None else None,
          'failedPrefixFrom':str(failed_prefix) if failed_prefix is not None else None,
          'checkpointPrefixFrom':str(checkpoint_prefix) if checkpoint_prefix is not None else None}
    (output/'plan.json').write_text(json.dumps(plan,indent=2));engine=ReasoningRuntime();calls=[];checks=[];verdicts=[]
    operations=case['operations']
    if arm=='source-only':operations={s['name']:EvidenceOperation({'relations':case['sources'],'rules':[],'queries':[]},s['name'],
        'Arguments are a ground tuple in source '+s['name']+'. Checks source membership only.',True) for s in case['sources']}
    def save(ledger=None):
        (output/'records.json').write_text(json.dumps({'calls':calls,'checks':checks,'verdicts':verdicts,'trajectory':ledger},indent=2))
    try:
        # Qualify compiled derived relations against independent oracles before paid calls.
        for sources in (case['sources'],case['changed']):
            with EvidenceInteraction(engine,sources,case['operations']) as preflight:
                p=copy.deepcopy(case['base']);p['relations']=[copy.deepcopy(next((s for s in sources if s['name']==r['name']),r)) if r['source'] else r for r in p['relations']]
                receipt=preflight.chain.query(p)
                if case['family']=='context-balanced-paths':expected=balanced_oracle(sources);assert set(map(tuple,receipt['result']['relations']['balanced']))==expected
                else:expected=tagged_oracle(sources);assert set(map(tuple,receipt['result']['relations']['flow']))==expected[0];assert set(map(tuple,receipt['result']['relations']['permit']))==expected[1]
        if not live:(output/'result.json').write_text(json.dumps({'preflight':'passed','paidCalls':0}));return
        question=(case['description']+'\n'+case['goals'][0]+'\nAvailable evidence tools can be called at any point in your reasoning, including before an answer. '
                  'Choose your own candidate branches and entity bindings. Local tool support does not itself solve the whole question. '
                  'Explanations/Markdown are welcome. Include the complete final job set as a JSON object with an answer array.\nFinite sources:\n'+json.dumps(case['sources'],separators=(',',':')))
        key=provider_key();all_correct=True;global_round=0;current_round=0;fatal=False
        with Trajectory(engine,case['case'],identity(case['sources'])) as trajectory:
            with EvidenceInteraction(engine,case['sources'],operations,trajectory=trajectory,retain=arm=='retained') as interaction:
                conversation=EvidenceConversation(question,interaction)
                prefix_count=0;start_stage=0
                prefix=failed_prefix or checkpoint_prefix
                if prefix is not None:
                    old=json.loads((prefix/'records.json').read_text())
                    failure=next(v for v in old['verdicts'] if not v['correct']) if failed_prefix else None
                    cut=next(i for i,c in enumerate(old['calls']) if c['id']==failure['providerCall'])+1 if failure else len(old['calls'])
                    start_stage=failure['stage'] if failure else 0
                    prefix_count=sum(c['stage']==start_stage for c in old['calls'][:cut])
                    next_stem=old['calls'][cut]['id'] if cut<len(old['calls']) else f'stage-{start_stage}-call-{prefix_count}'
                    original_input=json.loads((prefix/(next_stem+'-request.json')).read_text())['input']
                    if original_input[0]!={'role':'user','content':question}:raise ValueError('failed-prefix question changed')
                    conversation.restore_history(original_input)
                    for original in old['calls'][:cut]:
                        if original['stage']==2 and interaction.chain.source_identity!=identity(case['changed']):
                            interaction.replace(case['changed']);current_round=0
                        calls.append(copy.deepcopy(original));current_round+=1;global_round+=1
                        trajectory.model_call(original['id'],current_round,original['usage'])
                    verdicts.extend(copy.deepcopy(v) for v in old['verdicts'] if v['providerCall'] in {c['id'] for c in old['calls'][:cut]} and v is not failure)
                    if failure:
                        verdicts.append(copy.deepcopy(failure))
                        trajectory.verify(False,'independent-fixed-point-oracle.v1',round=current_round,scope='subgoal',candidate=failure['prediction'])
                    refreshed=[]
                    for check in old['checks']:
                        if check['stage']!=start_stage or check['providerCall'] not in {c['id'] for c in old['calls'][:cut]}:continue
                        arguments=json.loads(check['arguments'])
                        feedback=interaction.check(arguments['branches'],model_call=old['calls'][cut-1]['id'])
                        refreshed.append(feedback);checks.append({'providerCall':old['calls'][cut-1]['id'],'stage':start_stage,'revalidation':True,
                                                                  'callId':check['callId'],'arguments':check['arguments'],'feedback':feedback})
                    codec=getattr(sys.modules[EvidenceInteraction.__module__],'compact_feedback',lambda x:x)
                    conversation.history.append_feedback({'repairCheckpoint':'Previous local checks have been revalidated under the current implementation. Historical references cannot be used as current evidence.',
                                                          'checkedFragments':[codec(f) for f in refreshed],'taskAnswerProvided':False})
                    save(trajectory.snapshot())
                for stage in range(start_stage,3):
                    if stage==1:conversation.history.append_feedback({'nextGoal':case['goals'][stage],'sourcesUnchanged':True})
                    if stage==2 and not (prefix is not None and start_stage==2):
                        interaction.replace(case['changed']);current_round=0
                        conversation.history.append_feedback({'nextGoal':case['goals'][stage],'sourceUpdate':case['changed'],
                                                               'sourceIdentity':interaction.chain.source_identity,'oldEvidenceInvalidated':True})
                    success=False;failures=0
                    for attempt in range(8-(prefix_count if stage==start_stage else 0)):
                        global_round+=1;current_round+=1;stem=f'stage-{stage}-call-{attempt+(prefix_count if stage==start_stage else 0)}'
                        request={'model':'deepseek-flash','input':conversation.history.input(),'tools':interaction.tools,
                                 'tool_choice':'auto','reasoning':{'effort':'high'},'max_output_tokens':131072,'stream':True,'store':False}
                        (output/(stem+'-request.json')).write_text(json.dumps(request,indent=2));print('CALL',case['case'],arm,stem,flush=True)
                        if resume_prefix is not None and stage==0 and attempt==0:
                            original=json.loads((resume_prefix/(stem+'-request.json')).read_text())
                            if original['input']!=request['input']:raise ValueError('recovery must preserve original question bytes')
                            raw=(resume_prefix/(stem+'-answer.txt')).read_text();meta=json.loads((resume_prefix/(stem+'-provider.json')).read_text())
                            (output/(stem+'-provider.json')).write_text(json.dumps(meta,indent=2))
                        else:
                            with contextlib.redirect_stdout(io.StringIO()):raw,meta=provider(request,key,output/(stem+'-provider.json'))
                        (output/(stem+'-answer.txt')).write_text(raw);terminal=meta.get('terminal') or {}
                        observation={'id':stem,'stage':stage,'round':global_round,'usage':terminal.get('usage'),
                                     'status':terminal.get('status'),'error':meta.get('error'),'seconds':meta['providerSeconds'],'prediction':extract(raw)}
                        calls.append(observation);save(trajectory.snapshot())
                        if meta.get('error') or terminal.get('status')!='completed':
                            trajectory.model_call(stem,current_round,terminal.get('usage'));fatal=True;all_correct=False;break
                        results=conversation.accept(terminal,call_id=stem,round=current_round)
                        if results:
                            checks.extend([{'providerCall':stem,'stage':stage,**r} for r in results]);save(trajectory.snapshot());continue
                        prediction=observation['prediction'];success=prediction==case['gold'][stage]
                        verdicts.append({'providerCall':stem,'stage':stage,'correct':success,'prediction':prediction,'expected':case['gold'][stage]})
                        accepted,_=obligation_acceptance(verdicts)
                        trajectory.verify(success,'independent-fixed-point-oracle.v1',round=current_round,scope='task' if stage==2 and all(accepted) else 'subgoal',candidate=prediction)
                        save(trajectory.snapshot())
                        if success:break
                        failures+=1
                        if failures>=3:break
                        conversation.history.append_feedback({'verification':'not-correct','scope':'whole-current-goal',
                            'reason':'Complete job set does not match independently evaluated finite semantics. Check context/tag bindings, conjunction, exclusions, and source generation. Tools remain available.'})
                    all_correct=all(obligation_acceptance(verdicts)[0])
                    if fatal:break
                    if not success:conversation.history.append_feedback({'stageStatus':'unresolved-within-predeclared-budget','nextStageFollows':True})
            snapshot=trajectory.close('complete' if all_correct else 'unresolved-or-provider-failure')
        save(snapshot)
        complete=all(isinstance(c.get('usage'),dict) and isinstance((c['usage'].get('output_tokens_details') or {}).get('reasoning_tokens'),int) for c in calls)
        thinking=sum((c.get('usage') or {}).get('output_tokens_details',{}).get('reasoning_tokens',0) for c in calls)
        repairing=set();failed=False
        for c in calls:
            if failed:repairing.add(c['id'])
            verdict=next((v for v in verdicts if v['providerCall']==c['id']),None)
            if verdict:failed=not verdict['correct']
        repair_thinking=sum((c.get('usage') or {}).get('output_tokens_details',{}).get('reasoning_tokens',0) for c in calls if c['id'] in repairing)
        result={'case':case['case'],'family':case['family'],'arm':arm,'wholeTaskCorrect':all_correct,'censored':not all_correct,
                'stagesCorrect':sum(obligation_acceptance(verdicts)[0]),
                'obligationFirstSuccess':obligation_acceptance(verdicts)[1],
                'providerCalls':len(calls),'thinkingObserved':thinking,'thinkingComplete':complete,
                'throughFirstWholeCorrectThinking':thinking if all_correct and complete else None,
                'repairCalls':len(repairing),'repairThinkingObserved':repair_thinking,
                'failedFinalAnswers':sum(not v['correct'] for v in verdicts),'toolCalls':len(checks),
                'toolBranches':sum(len(x['feedback'].get('branches',[])) for x in checks),
                'reusedBranches':sum(bool(b.get('reusedComponents')) for x in checks for b in x['feedback'].get('branches',[])),
                'unknownBranches':sum(b.get('status')=='unknown' for x in checks for b in x['feedback'].get('branches',[])),
                'providerErrors':sum(bool(c['error']) or c['status']!='completed' for c in calls)}
        (output/'result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True)
    finally:engine.close()


def main():
    p=argparse.ArgumentParser();p.add_argument('--library',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--live',action='store_true');p.add_argument('--case-index',type=int,default=0);p.add_argument('--arm',choices=['source-only','fresh','retained'],default='retained');p.add_argument('--resume-prefix',type=Path);p.add_argument('--failed-prefix',type=Path);p.add_argument('--checkpoint-prefix',type=Path);p.add_argument('--seed-offset',type=int,default=0)
    a=p.parse_args();run(a.library,a.output,live=a.live,index=a.case_index,arm=a.arm,resume_prefix=a.resume_prefix,failed_prefix=a.failed_prefix,checkpoint_prefix=a.checkpoint_prefix,seed_offset=a.seed_offset)


if __name__=='__main__':main()
