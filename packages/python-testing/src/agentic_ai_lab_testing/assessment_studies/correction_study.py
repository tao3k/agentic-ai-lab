# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Shared-prefix, whole-task correction controls on fresh recursive programs."""
import argparse, contextlib, copy, hashlib, io, json, random
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from agentic_ai_lab_runtime.reasoning import EvidenceChain, evidence_graph
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from .trajectory_study import relation, atom, rule, extract
from .model_study import provider
from .movie_study import provider_key


def tagged(seed, mutual=False):
    rng=random.Random(seed);n=72 if mutual else 64
    nodes=[f'n{seed:x}_{i:x}' for i in range(n)];tags=[f't{i}' for i in range(4)]
    states=[(x,t) for x in nodes for t in tags]
    edge={(nodes[i],nodes[i+1]) for i in range(n-1)}
    edge|={tuple(rng.sample(nodes,2)) for _ in range(n+16)}
    blocked=set(rng.sample(states,n));starts=set(rng.sample(states,7))
    converts={tuple([x,*rng.sample(tags,2)]) for x in rng.choices(nodes,k=n+20)}
    blocked-=starts
    sources=[relation('edge',True,2,sorted(edge)),relation('start',True,2,sorted(starts)),
             relation('blocked',True,2,sorted(blocked)),relation('convert',True,3,sorted(converts))]
    derived=[relation('flow',False,2),relation('answer',False,1)]
    rules=[rule(atom('flow','x','t'),atom('start','x','t')),
           rule(atom('flow','x','u'),atom('flow','x','t'),atom('convert','x','t','u'),atom('blocked','x','u',negative=True))]
    grants={(a,b,t) for a,b in sorted(edge) for t in rng.sample(tags,2)}
    permitted=set(rng.sample(states,n+16))
    if mutual:
        sources+=[relation('permission',True,2,sorted(permitted)),relation('grant',True,3,sorted(grants))]
        derived.append(relation('permit',False,2))
        rules+=[rule(atom('permit','x','t'),atom('permission','x','t')),
                rule(atom('permit','y','t'),atom('flow','x','t'),atom('grant','x','y','t'),atom('blocked','y','t',negative=True)),
                rule(atom('flow','y','t'),atom('flow','x','t'),atom('edge','x','y'),atom('permit','y','t'),atom('blocked','y','t',negative=True))]
    else:rules.append(rule(atom('flow','y','t'),atom('flow','x','t'),atom('edge','x','y'),atom('blocked','y','t',negative=True)))
    flow=set(starts);permit=set(permitted);rounds=0
    while True:
        rounds+=1
        p=permit|{(b,t) for a,b,t in grants if (a,t) in flow and (b,t) not in blocked} if mutual else permit
        f=flow|{(b,t) for a,b in edge for t in tags if (a,t) in flow and (b,t) not in blocked and (not mutual or (b,t) in p)}
        f|={(x,u) for x,t,u in converts if (x,t) in flow and (x,u) not in blocked}
        if (f,p)==(flow,permit):break
        flow,permit=f,p
    requests=[]
    for i in range(96):
        chosen=rng.choices(sorted(flow) if i<48 else states,k=4)
        requests.append([f'j{seed:x}_{i:x}',*[v for pair in chosen for v in pair]])
    rng.shuffle(requests);excluded={r[0] for r in rng.sample(requests,13)};policy={r[0] for r in rng.sample(requests,66)}
    sources += [relation('needs',True,9,requests),relation('excluded',True,1,[[x] for x in sorted(excluded)]),relation('policy',True,1,[[x] for x in sorted(policy)])]
    head=atom('answer','j');body=[atom('needs','j','a','t','b','u','c','v','d','w'),atom('flow','a','t'),atom('flow','b','u'),atom('flow','c','v')]
    first=rules+[rule(head,*body,atom('flow','d','w'),atom('excluded','j',negative=True))]
    second=rules+[rule(head,*body,atom('blocked','d','w',negative=True),atom('policy','j'),atom('excluded','j',negative=True))]
    gold1=[];gold2=[]
    for j,a,t,b,u,c,v,d,w in requests:
        if j in excluded:continue
        if {(a,t),(b,u),(c,v)}<=flow:
            if (d,w) in flow:gold1.append(j)
            if (d,w) not in blocked and j in policy:gold2.append(j)
    label='mutual-permission-taint' if mutual else 'tag-scoped-taint'
    return make_case(label,seed,sources,derived,first,second,gold1,gold2,
        ['flow','permit'] if mutual else ['flow'],{'nodes':n,'tags':4,'edges':len(edge),'blockedStates':len(blocked),
        'conversions':len(converts),'oracleRounds':rounds,'intermediateRows':len(flow)+(len(permit) if mutual else 0),'requests':96})


def balanced(seed, count=24, contexts_count=2, request_count=96):
    rng=random.Random(seed);nodes=[f'p{seed:x}_{i:x}' for i in range(count)];contexts=[f'c{i}' for i in range(contexts_count)]
    opening={(nodes[0],nodes[1],'a'),(nodes[1],nodes[2],'b')};closing={(nodes[3],nodes[4],'b'),(nodes[4],nodes[5],'a')}
    for collection in [opening,closing]:
        for _ in range(count+8):
            x,y=rng.sample(nodes,2);collection.add((x,y,rng.choice(['a','b'])))
    epsilon={(x,x) for x in nodes}|{(nodes[2],nodes[3])}
    denied={(rng.choice(contexts),x,y) for x,y,k in rng.sample(sorted(opening|closing),10)}
    closures={c:set(epsilon) for c in contexts};rounds=0
    while True:
        rounds+=1;new={}
        for c in contexts:
            pairs=closures[c]
            add={(x,z) for x,y in pairs for y2,z in pairs if y==y2}
            add|={(x,z) for x,a,k in opening for b,z,k2 in closing if k==k2 and (a,b) in pairs and (c,x,a) not in denied and (c,b,z) not in denied}
            new[c]=pairs|add
        if new==closures:break
        closures=new
    positive=[(c,x,y) for c in contexts for x,y in sorted(closures[c]) if x!=y]
    assert len(positive)>10
    universe=[(c,x,y) for c in contexts for x in nodes for y in nodes]
    requests=[]
    for i in range(request_count):
        a,b=rng.choices(positive if i<request_count//2 else universe,k=2)
        requests.append([f'j{seed:x}_{i:x}',*a,*b])
    rng.shuffle(requests);excluded={r[0] for r in rng.sample(requests,12)}
    bridge={(rng.choice(nodes),rng.choice(nodes)) for _ in range(count*2)}
    sources=[relation('context',True,1,[[c] for c in contexts]),relation('epsilon',True,2,sorted(epsilon)),
       relation('opening',True,3,sorted(opening)),relation('closing',True,3,sorted(closing)),
       relation('denied',True,3,sorted(denied)),relation('needs',True,7,requests),
       relation('excluded',True,1,[[x] for x in sorted(excluded)]),relation('bridge',True,2,sorted(bridge))]
    derived=[relation('balanced',False,3),relation('answer',False,1)]
    rules=[rule(atom('balanced','c','x','y'),atom('context','c'),atom('epsilon','x','y')),
       rule(atom('balanced','c','x','z'),atom('balanced','c','x','y'),atom('balanced','c','y','z')),
       rule(atom('balanced','c','x','z'),atom('opening','x','a','k'),atom('balanced','c','a','b'),atom('closing','b','z','k'),
            atom('denied','c','x','a',negative=True),atom('denied','c','b','z',negative=True))]
    first=rules+[rule(atom('answer','j'),atom('needs','j','c','x','y','d','u','v'),atom('balanced','c','x','y'),atom('balanced','d','u','v'),atom('excluded','j',negative=True))]
    second=rules+[rule(atom('answer','j'),atom('needs','j','c','x','y','d','u','v'),atom('balanced','c','x','z'),atom('bridge','z','y'),atom('balanced','d','u','v'),atom('excluded','j',negative=True))]
    g1=[j for j,c,x,y,d,u,v in requests if (x,y) in closures[c] and (u,v) in closures[d] and j not in excluded]
    g2=[j for j,c,x,y,d,u,v in requests if any(a==x and (b,y) in bridge for a,b in closures[c]) and (u,v) in closures[d] and j not in excluded]
    return make_case('context-balanced-paths',seed,sources,derived,first,second,g1,g2,['balanced'],
        {'nodes':count,'contexts':contexts_count,'openingEdges':len(opening),'closingEdges':len(closing),'oracleRounds':rounds,
         'intermediateRows':sum(len(v) for v in closures.values()),'requests':request_count})


def make_case(label,seed,sources,derived,rules,second,g1,g2,names,complexity):
    sources=json.loads(json.dumps(sources))
    program={'relations':sources+derived,'rules':rules,'queries':['answer']}
    second_program={'relations':sources+derived,'rules':second,'queries':['answer']}
    question=('This task has TWO predeclared query obligations over unchanged finite sources. Solve the first now; the second rule set follows later. '
      'Task completion requires BOTH complete answer sets. Evaluate the least fixed point of the explicit rules. Conjunction joins shared variables; '
      'negation is scoped to the exact tuple, not globally to a node or context. Recursive cycles require convergence, not a fixed depth. '
      'Opening/closing labels must match where joined; epsilon includes only the supplied pairs. No external tools are available. '
      'Explanations and Markdown are allowed. Finish with FINAL_JSON: {"answer": ["job", ...]}.\n'+json.dumps(program,separators=(',',':')))
    return {'case':f'{label}-{seed}','seed':seed,'family':label,'sources':sources,'program':program,'secondProgram':second_program,
            'gold':[sorted(g1),sorted(g2)],'intermediates':names,'question':question,'complexity':complexity}


def corpus():return [tagged(2026103301),tagged(2026103302,True),balanced(2026103303),balanced(2026103304,28,3)]

def run(library,output,live,cases=None):
    output.mkdir(parents=True,exist_ok=False);cases=corpus() if cases is None else cases
    plan={'schema':'ascent.correction-study.v1','cases':cases,'model':'deepseek-flash','effort':'high','maxOutputTokens':131072,
          'maxAttemptsPerStage':3,'primary':'Cumulative actual thinking until both query obligations independently pass, including all failed and repair calls.',
          'sharedPrefix':'One actual initial call is retained in both paired task trajectories and charged to BOTH policies; experimental expenditure counts it once.',
          'intervention':'Completed intermediate relations only, after a real failed initial answer or before the second query. No final answer in packets.',
          'sourceHashes':{p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in [__file__,'program/trajectory.ss',
             'rust/ascent/src/derivations.rs','rust/ascent-python/src/api/trajectory.rs']},
          'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest(),'outputSchemaEnforced':False}
    (output/'plan.json').write_text(json.dumps(plan,indent=2));engine=ReasoningRuntime();records=[];calls_audit=[];key=provider_key() if live else None
    def invoke(history,folder,stem):
        request={'model':plan['model'],'input':history.input(),'reasoning':{'effort':'high'},'max_output_tokens':131072,'stream':True,'store':False}
        (folder/f'{stem}-request.json').write_text(json.dumps(request,indent=2))
        print(f'CALL {folder.name} {stem}',flush=True)
        with contextlib.redirect_stdout(io.StringIO()):raw,meta=provider(request,key,folder/f'{stem}-provider.json')
        (folder/f'{stem}-answer.txt').write_text(raw);terminal=meta.get('terminal') or {}
        observation={'callId':folder.name+':'+str(stem),'usage':terminal.get('usage'),'status':terminal.get('status'),
                     'error':meta.get('error'),'prediction':extract(raw),'providerSeconds':meta['providerSeconds']}
        calls_audit.append(observation);(output/'actual-calls.json').write_text(json.dumps(calls_audit,indent=2))
        return observation,terminal
    try:
        for case_index,case in enumerate(cases):
            with EvidenceChain(engine,case['sources']) as preflight:
                for program,gold in zip([case['program'],case['secondProgram']],case['gold']):
                    feedback=preflight.query(program);assert sorted(r[0] for r in feedback['result']['relations']['answer'])==gold
                dag=evidence_graph(case['program']);(output/f'{case["case"]}-dag.json').write_text(json.dumps(dag,indent=2))
            if not live:continue
            common=output/(case['case']+'-shared');common.mkdir();initial_history=ResponseHistory(case['question'])
            initial,initial_terminal=invoke(initial_history,common,'initial')
            arms=['reflection','checked-intermediates'];arms=arms if case['seed']%2==0 else arms[::-1]
            stop=False
            for arm in arms:
                folder=output/(case['case']+'-'+arm);folder.mkdir();history=ResponseHistory(case['question'])
                trajectory=Trajectory(engine,case['case'],identity(case['sources']))
                chain=EvidenceChain(engine,case['sources'],trajectory=trajectory) if arm=='checked-intermediates' else None
                calls=[];packets=[];round=0;complete=True;fatal=False;reused=[]
                try:
                    for stage in [0,1]:
                        program=[case['program'],case['secondProgram']][stage];gold=case['gold'][stage]
                        if stage==1:
                            history.append_feedback({'instruction':'SECOND query: sources and derived component rules are unchanged. Compute the complete new answer relation.',
                               'rules':program['rules'],'queries':['answer']})
                        passed=False
                        for attempt in range(1,4):
                            round+=1
                            if stage==0 and attempt==1:obs,terminal=copy.deepcopy(initial),copy.deepcopy(initial_terminal)
                            else:obs,terminal=invoke(history,folder,f'{stage+1}-{attempt}')
                            completed=obs['status']=='completed' and obs['error'] is None
                            budget=obs['status']=='incomplete' and obs['error'] is None
                            passed=completed and obs['prediction']==gold
                            obs.update(stage=stage+1,attempt=attempt,round=round,correct=passed,
                               failureKind=None if passed else ('budget' if budget else 'transport' if not completed else 'format' if obs['prediction'] is None else 'semantic'))
                            obs['evidenceAlreadyExposed']=bool(chain and not(stage==0 and attempt==1))
                            calls.append(obs);trajectory.model_call(obs['callId'],round,obs['usage'])
                            if not completed and not budget:fatal=True;complete=False;break
                            trajectory.verify(passed,'independent-relational-oracle.v2',round=round,candidate=obs['prediction'],
                                              scope='task' if stage==1 and passed else 'subgoal')
                            # Incomplete output is archived, but cannot be replayed as a completed response.
                            if completed:history.append_response(terminal)
                            print(f'RESULT {case["case"]} {arm} stage={stage+1} attempt={attempt} correct={passed}',flush=True)
                            if chain:
                                feedback=chain.query(program);reused=feedback['reusedComponents']
                                packet=chain.intermediates(feedback['resultReference'],case['intermediates'])
                                assert 'answer' not in packet['facts'];packets.append({'round':round,'packet':packet})
                            if passed:
                                if stage==0 and chain:history.append_feedback({'verifiedIntermediates':packet,'instruction':'These completed relations are valid for subsequent queries on these same sources.'})
                                break
                            correction={'correct':False,'instruction':'Reflect on the incorrect complete answer and repair it. Re-evaluate scoped negation and all recursive joins; do not stop at a bounded path depth.'}
                            if chain:correction['verifiedIntermediates']=packet
                            history.append_feedback(correction)
                        if not passed:complete=False;break
                    snapshot=trajectory.close('both-correct' if complete else 'provider-error' if fatal else 'attempt-budget')
                    record={'case':case['case'],'arm':arm,'verifiedBoth':complete,'calls':calls,'packets':packets,'nativeReusedComponents':reused,'trajectory':snapshot}
                    records.append(record);(output/'records.json').write_text(json.dumps(records,indent=2))
                finally:
                    trajectory.close('exception')
                    if chain:chain.close()
                if fatal:stop=True;break
            if stop:break
        result={'preparedCases':len(cases),'records':records,'actualProviderRequests':len(calls_audit),'offlineQueryAgreement':len(cases)*2 if not live or not stop else None,
                'unstartedConditionTasks':len(cases)*2-len(records)}
        (output/'result.json').write_text(json.dumps(result,indent=2));print(f'DONE tasks={len(records)} actualCalls={len(calls_audit)}',flush=True)
    finally:engine.close()


def holdout_corpus():
    cases=[tagged(2026104301,True),balanced(2026104302,28,3,128),
           balanced(2026104303,32,3,128),balanced(2026104304,32,4,160)]
    for case in cases:
        rng=random.Random(case['seed']+991)
        jobs=[r[0] for r in next(s for s in case['sources'] if s['name']=='needs')['rows']]
        ids=rng.sample(range(1<<48),len(jobs))
        rename={job:f'job_{value:012x}' for job,value in zip(jobs,ids)}
        for source in case['sources']:
            source['rows']=[[rename.get(value,value) for value in row] for row in source['rows']]
        case['gold']=[sorted(rename[x] for x in gold) for gold in case['gold']]
        case['question']=case['question'].split('\n',1)[0]+'\n'+json.dumps(case['program'],separators=(',',':'))
        case['construction']='Satisfiable/unsatisfied candidates are mixed; opaque shuffled job identifiers are independent of class/construction index.'
    return cases


def main():
    p=argparse.ArgumentParser();p.add_argument('--library',required=True,type=Path);p.add_argument('--output',required=True,type=Path);p.add_argument('--live',action='store_true');p.add_argument('--holdout',action='store_true');p.add_argument('--case-index',type=int)
    a=p.parse_args();cases=holdout_corpus() if a.holdout else corpus()
    if a.case_index is not None:cases=[cases[a.case_index]]
    run(a.library.resolve(),a.output.resolve(),a.live,cases)
if __name__=='__main__':main()
