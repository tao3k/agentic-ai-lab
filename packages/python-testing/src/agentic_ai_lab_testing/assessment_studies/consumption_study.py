# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Text consumption versus checked execution on shared initial real responses."""
import argparse, contextlib, copy, hashlib, io, json, random, time
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime, ReasoningError
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from .correction_study import balanced
from .trajectory_study import atom, rule
from .model_study import provider
from .movie_study import provider_key


def parse(raw):
    decoder=json.JSONDecoder()
    for index,char in enumerate(raw):
        if char!='{':continue
        try:obj,_=decoder.raw_decode(raw[index:])
        except ValueError:continue
        if isinstance(obj,dict) and isinstance(obj.get('rule'),dict):return obj
    return None


def oracle(sources):
    s={r['name']:r['rows'] for r in sources};pairs={(c,x,y) for c, in s['context'] for x,y in s['epsilon']};blocked=set(map(tuple,s['denied']))
    while True:
        more=pairs|{(c,x,z) for c,x,y in pairs for d,y2,z in pairs if c==d and y==y2}
        more|={(c,x,z) for c,a,b in pairs for x,a2,k in s['opening'] for b2,z,l in s['closing']
               if a==a2 and b==b2 and k==l and (c,x,a) not in blocked and (c,b,z) not in blocked}
        if more==pairs:return pairs
        pairs=more


def corpus():
    cases=[balanced(2026105301,34,4,160),balanced(2026105302,36,5,192)]
    for c in cases:
        rng=random.Random(c['seed']+1123);jobs=[r[0] for r in next(s for s in c['sources'] if s['name']=='needs')['rows']]
        rename={j:f'job_{v:012x}' for j,v in zip(jobs,rng.sample(range(1<<48),len(jobs)))}
        for source in c['sources']:source['rows']=[[rename.get(x,x) for x in r] for r in source['rows']]
        c['program']['relations']=copy.deepcopy(c['sources'])+[r for r in c['program']['relations'] if not r['source']]
        expected=copy.deepcopy(c['program']);expected['rules'][-1]=rule(atom('answer','j'),atom('needs','j','c','x','y','d','u','v'),atom('balanced','c','x','y'),atom('balanced','d','u','v',negative=True),atom('excluded','j',negative=True))
        pairs=oracle(c['sources']);excluded={r[0] for r in next(s for s in c['sources'] if s['name']=='excluded')['rows']}
        need=next(s for s in c['sources'] if s['name']=='needs')['rows']
        first=sorted(j for j,a,x,y,b,u,v in need if (a,x,y) in pairs and (b,u,v) in pairs and j not in excluded)
        changed=sorted(j for j,a,x,y,b,u,v in need if (a,x,y) in pairs and (b,u,v) not in pairs and j not in excluded)
        assert first and changed and first!=changed
        base=copy.deepcopy(c['program']);base['rules']=base['rules'][:-1];base['queries']=['balanced'];base['relations']=[r for r in base['relations'] if r['name']!='answer']
        c.update(base=base,programs=[c['program'],c['program'],expected],gold=[first,first,changed],
            goals=['Return all non-excluded jobs for which BOTH requested context-specific balanced paths exist.',
                   'Select every eligible job whose first path is balanced in its own context AND whose second path is balanced in its respective context. Omit excluded jobs. This is the complete set, not an update delta.',
                   'Return all non-excluded jobs whose FIRST context-specific path exists but whose SECOND context-specific balanced path does NOT exist.'],
            schema='needs(j,c,x,y,d,u,v): first path is (c,x,y); second is (d,u,v). balanced(context,from,to) is completed recursive evidence. answer(j) is unary.')
    return cases


def proposed(case,stage,obj):
    program=copy.deepcopy(case['programs'][stage]);program['rules'][-1]=obj['rule'];return program


def run(library,output,live,index=None):
    output.mkdir(parents=True,exist_ok=False);cases=corpus();cases=cases if index is None else [cases[index]]
    plan={'schema':'ascent.evidence-consumption-study.v1','cases':cases,'model':'deepseek-flash','maxOutputTokens':131072,
          'maxAttemptsPerGoal':3,'primary':'Whole task until all THREE goals pass, including shared initial usage and every failure/repair.',
          'intervention':'Checked executable continuation versus correct intermediate facts with manual result enumeration; this is tool offloading, not a pure reasoning-content treatment.',
          'sourceHashes':{p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in [__file__,'program/evidence-dag.ss','program/trajectory.ss','rust/ascent/src/derivations.rs','rust/ascent-python/src/api/trajectory.rs']},
          'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest()}
    (output/'plan.json').write_text(json.dumps(plan,indent=2));engine=ReasoningRuntime();records=[];audit=[];key=provider_key() if live else None
    def invoke(history,folder,stem):
        folder.mkdir(exist_ok=True);request={'model':'deepseek-flash','input':history.input(),'reasoning':{'effort':'high'},'max_output_tokens':131072,'stream':True,'store':False}
        (folder/(stem+'-request.json')).write_text(json.dumps(request,indent=2));print('CALL',folder.name,stem,flush=True)
        with contextlib.redirect_stdout(io.StringIO()):raw,meta=provider(request,key,folder/(stem+'-provider.json'))
        (folder/(stem+'-answer.txt')).write_text(raw);terminal=meta.get('terminal') or {}
        call={'callId':folder.name+':'+stem,'usage':terminal.get('usage'),'status':terminal.get('status'),'error':meta.get('error'),'parsed':parse(raw),'providerSeconds':meta['providerSeconds']}
        audit.append(copy.deepcopy(call));(output/'actual-calls.json').write_text(json.dumps(audit,indent=2));return call,terminal
    try:
        for case in cases:
            with EvidenceChain(engine,case['sources']) as preflight:
                for p,g in zip(case['programs'],case['gold']):assert sorted(r[0] for r in preflight.query(p)['result']['relations']['answer'])==g
            if not live:continue
            prompt=(case['schema']+'\nInterpret the goal as one closed relational rule with head answer(j). Base rules below define balanced paths with matching labels, concatenation and scoped denied edges. Do not change base rules.\n'+case['goals'][0]+'\nGive the rule AND compute the complete answer set. Explanations/Markdown are allowed; finish with a JSON object containing rule (head/body atoms using var terms and not for negation) and answer (job strings). No external tool is available for this initial response.\n'+json.dumps(case['base'],separators=(',',':')))
            initial,initial_terminal=invoke(ResponseHistory(prompt),output/(case['case']+'-shared'),'initial')
            for arm in (['text-evidence','executable-evidence'] if case['seed']%2 else ['executable-evidence','text-evidence']):
                folder=output/(case['case']+'-'+arm);folder.mkdir();history=ResponseHistory(prompt);calls=[];round=0;all_correct=True;fatal=False
                with Trajectory(engine,case['case'],identity(case['sources'])) as trajectory:
                    with EvidenceChain(engine,case['sources'],trajectory=trajectory) as chain:
                        base=chain.query(case['base']);reference=base['resultReference']
                        # Project via a result whose query is not the intermediate.
                        packet=chain.query(case['programs'][0]);facts=chain.intermediates(packet['resultReference'],['balanced'])
                        for stage in range(3):
                            if stage:history.append_feedback({'goal':case['goals'][stage],'schema':case['schema'],'instruction':'Produce only the closed query rule; Scheme executes admitted intent.' if arm=='executable-evidence' else 'Produce the query rule AND the complete manually computed answer set.','verifiedIntermediates':facts if arm=='text-evidence' else {'schema':facts['schema'],'columns':facts['columns'],'sourceIdentity':facts['sourceIdentity'],'available':['balanced']}})
                            passed=False
                            for attempt in range(1,4):
                                round+=1
                                obs,terminal=(copy.deepcopy(initial),copy.deepcopy(initial_terminal)) if stage==0 and attempt==1 else invoke(history,folder,f'{stage+1}-{attempt}')
                                trajectory.model_call(obs['callId'],round,obs['usage']);obj=obs['parsed'];admission=None;execution=None
                                completed=obs['status']=='completed' and obs['error'] is None
                                if completed and obj:
                                    try:
                                        candidate=proposed(case,stage,obj)
                                        if arm=='executable-evidence':
                                            execution=chain.consume(reference,candidate,case['programs'][stage],interpretation={'scope':'model-interpreted','utteranceIdentity':identity({'goal':case['goals'][stage],'schema':case['schema']}),'resolver':'deepseek-flash','modelCall':'call:'+obs['callId']});admission=execution
                                        else:admission=engine.request({'operation':'evidence-dag','action':'check-continuation','program':candidate,'contract':case['programs'][stage]})
                                    except (ReasoningError,KeyError,TypeError,ValueError) as e:admission={'accepted':False,'diagnostic':str(e)}
                                accepted=bool(admission and admission['accepted'])
                                actual=sorted(r[0] for r in execution['result']['relations']['answer']) if accepted and execution and 'result' in execution else sorted(obj['answer']) if obj and isinstance(obj.get('answer'),list) and all(isinstance(x,str) for x in obj['answer']) else None
                                passed=completed and accepted and actual==case['gold'][stage]
                                kind=None if passed else 'transport' if obs['error'] else 'budget' if not completed else 'format' if obj is None else 'intent' if not accepted else 'enumeration'
                                obs.update(stage=stage+1,attempt=attempt,round=round,correct=passed,failureKind=kind,admission=admission,actualAnswer=actual,
                                    consumedReference=execution.get('resultReference') if passed and arm=='executable-evidence' else None,
                                    reusedComponents=execution.get('reusedComponents',[]) if execution else [],retainedCompleted=execution.get('retainedCompleted') if execution else None)
                                calls.append(obs);print('RESULT',case['case'],arm,stage+1,attempt,passed,kind,flush=True)
                                if obs['error']:fatal=True;break
                                trajectory.verify(passed,'independent-relational-oracle-and-intent.v3',round=round,scope='task' if passed and stage==2 else 'subgoal',candidate=actual,consumption_reference=obs['consumedReference'])
                                if completed:history.append_response(terminal)
                                if passed:
                                    if arm=='executable-evidence':reference=execution['resultReference']
                                    break
                                history.append_feedback({'correct':False,'goal':case['goals'][stage],'schema':case['schema'],
                                    'intentDiagnostic':admission.get('diagnostic') if admission else 'No usable rule was returned.',
                                    'answerErrors':{'missing':len(set(case['gold'][stage])-set(actual or [])),'extra':len(set(actual or [])-set(case['gold'][stage]))},
                                    'instruction':'Repair the query intent; Scheme executes it. Do not enumerate results.' if arm=='executable-evidence' else 'Repair the query and recompute the complete answer using these correct facts.',
                                    'verifiedIntermediates':{'columns':facts['columns'],'available':['balanced']} if arm=='executable-evidence' else facts})
                            if not passed:all_correct=False;break
                        snapshot=trajectory.close('all-three-goals-correct' if all_correct else 'provider-error' if fatal else 'attempt-budget')
                        records.append({'case':case['case'],'arm':arm,'verifiedAll':all_correct,'calls':calls,'trajectory':snapshot});(output/'records.json').write_text(json.dumps(records,indent=2))
        (output/'result.json').write_text(json.dumps({'records':records,'preparedCases':len(cases),'oracleAgreements':len(cases)*3,'actualCalls':len(audit)},indent=2));print('DONE',len(records),len(audit),flush=True)
    finally:engine.close()


def legacy_repair(library,output):
    output.mkdir(parents=True,exist_ok=False);engine=ReasoningRuntime();records=[]
    try:
        for index in range(4):
            source=Path(f'.cache/ascent/correction/holdout-{index}');plan=json.loads((source/'plan.json').read_text());case=plan['cases'][0]
            control=next(r for r in json.loads((source/'records.json').read_text()) if r['arm']=='reflection');i=next(i for i,c in enumerate(control['calls']) if c['failureKind']=='semantic');prefix=control['calls'][:i+1];start=prefix[-1]['stage']-1
            with Trajectory(engine,case['case'],identity(case['sources'])) as trajectory:
                for c in prefix:
                    trajectory.model_call(c['callId'],c['round'],c['usage']);trajectory.verify(c['correct'],'original-independent-oracle',scope='subgoal',round=c['round'])
                with EvidenceChain(engine,case['sources'],trajectory=trajectory) as chain:
                    first=chain.query(case['program']);reference=first['resultReference'];receipts=[]
                    for stage in range(start,2):
                        program=[case['program'],case['secondProgram']][stage]
                        # Historical tasks already supplied the complete authorized
                        # query; no new model call is needed to rediscover it.
                        receipt=chain.consume(reference,program,program);assert receipt['accepted'];actual=sorted(r[0] for r in chain.answer(receipt['resultReference'],'answer'));assert actual==case['gold'][stage]
                        trajectory.verify(True,'original-independent-oracle',scope='task' if stage==1 else 'subgoal',consumption_reference=receipt['resultReference']);reference=receipt['resultReference'];receipts.append(receipt)
                    records.append({'case':case['case'],'source':str(source),'prefix':prefix,'control':control,'receipts':receipts,'newModelCalls':0,'trajectory':trajectory.close('authorized-query-executed')})
        (output/'result.json').write_text(json.dumps(records,indent=2));print('LEGACY-REPAIR-OK',len(records),'new-model-calls=0',flush=True)
    finally:engine.close()


def main():
    p=argparse.ArgumentParser();p.add_argument('--library',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--live',action='store_true');p.add_argument('--case-index',type=int);p.add_argument('--legacy-repair',action='store_true');a=p.parse_args()
    if a.legacy_repair:legacy_repair(a.library.resolve(),a.output.resolve())
    else:run(a.library.resolve(),a.output.resolve(),a.live,a.case_index)
if __name__=='__main__':main()
