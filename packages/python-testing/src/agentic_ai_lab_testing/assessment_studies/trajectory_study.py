# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Fresh relational tasks, independent oracle, actual provider call trajectories.

No server-side output schema. Native evidence is supplied only after an actual
failed model attempt; known repeat answers require no additional model call.
"""
import argparse
import contextlib
import hashlib
import io
import json
import random
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceChain, evidence_graph
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from .movie_study import provider_key
from .model_study import provider


def relation(name, source, arity, rows=()):
    return {'name':name,'source':source,'columns':[{'kind':'symbol'} for _ in range(arity)],'rows':list(rows)}

def atom(name,*variables,negative=False):
    return {'relation':name,'terms':[{'var':v} for v in variables], **({'not':True} if negative else {})}

def rule(head,*body):
    return {'head':[head],'body':list(body)}


def closure(edges, seeds, blocked):
    found=set(seeds)
    while True:
        next_found=found|{b for a,b in edges if a in found and b not in blocked}
        if next_found==found:return found
        found=next_found


def task(family, seed):
    rng=random.Random(seed)
    count=36+family*4
    nodes=[f'v{seed:x}_{i:x}' for i in range(count)]
    islands=3 if family%2==0 else 4
    edges=set()
    for i,a in enumerate(nodes):
        choices=[b for j,b in enumerate(nodes) if j%islands==i%islands and a!=b]
        for b in rng.sample(choices,3):edges.add((a,b))
    bridges=[(nodes[rng.randrange(count//islands)*islands],nodes[1+islands*rng.randrange(count//islands)])]
    edges.update(bridges)
    blocked=set(rng.sample(nodes,5+family));seeds=[nodes[0],nodes[islands]]
    blocked-=set(seeds)
    targets=rng.sample(nodes,22)
    inputs=[relation('edge',True,2,sorted(map(list,edges))),relation('start',True,1,[[x] for x in seeds]),
            relation('blocked',True,1,[[x] for x in sorted(blocked)])]
    derived=[relation('reach',False,1),relation('answer',False,1)]
    rules=[rule(atom('reach','x'),atom('start','x')),
           rule(atom('reach','y'),atom('reach','x'),atom('edge','x','y'),atom('blocked','y',negative=True))]
    reached=closure(edges,seeds,blocked)
    if family==0:
        label='recursive-scoped-reachability'
        inputs.append(relation('target',True,1,[[x] for x in targets]))
        rules.append(rule(atom('answer','x'),atom('reach','x'),atom('target','x')))
        gold=sorted(reached&set(targets))
    elif family==1:
        label='taint-propagation-with-sanitizers'
        excluded=set(rng.sample(targets,6))
        inputs += [relation('sink',True,1,[[x] for x in targets]),relation('approved',True,1,[[x] for x in sorted(excluded)])]
        rules.append(rule(atom('answer','x'),atom('reach','x'),atom('sink','x'),atom('approved','x',negative=True)))
        gold=sorted((reached&set(targets))-excluded)
    elif family==2:
        label='conjunctive-prerequisite-closure'
        needs=[[f'job{seed:x}_{i}',*rng.sample(nodes,2)] for i in range(24)]
        deferred={n[0] for n in rng.sample(needs,5)}
        inputs += [relation('needs',True,3,needs),relation('deferred',True,1,[[x] for x in sorted(deferred)])]
        rules.append(rule(atom('answer','job'),atom('needs','job','a','b'),atom('reach','a'),atom('reach','b'),atom('deferred','job',negative=True)))
        gold=sorted(job for job,a,b in needs if a in reached and b in reached and job not in deferred)
    else:
        label='bidirectional-recursive-impact'
        finish=rng.sample(nodes,3)
        reverse=closure({(b,a) for a,b in edges},finish,blocked)
        inputs += [relation('finish',True,1,[[x] for x in finish]),relation('target',True,1,[[x] for x in targets])]
        derived.append(relation('back',False,1))
        rules += [rule(atom('back','x'),atom('finish','x')),
                  rule(atom('back','x'),atom('back','y'),atom('edge','x','y'),atom('blocked','x',negative=True)),
                  rule(atom('answer','x'),atom('reach','x'),atom('back','x'),atom('target','x'))]
        gold=sorted(reached&reverse&set(targets))
    program={'relations':inputs+derived,'rules':rules,'queries':['answer']}
    prompt=('Compute the COMPLETE answer relation of this finite least-fixed-point program. '
            'Rules are conjunctive; shared variables join; not means scoped absence from the declared source relation. '
            'Blocked nodes cannot be entered by recursive propagation, but explicitly supplied start/finish seeds are initial facts. '
            'Cycles do not bound the number of fixed-point rounds. No external tools are available. '
            'Reason carefully and finish with FINAL_JSON: {"answer": ["symbol", ...]}. '
            'Explanations are welcome; the API does not enforce a JSON schema.\n'+json.dumps(program,separators=(',',':')))
    return {'case':f'{label}-{seed}','family':label,'seed':seed,'program':program,'sources':inputs,'gold':gold,
            'question':prompt,'complexity':{'nodes':count,'edges':len(edges),'negativeSourceRows':len(blocked),
                'rules':len(rules),'derivedRelations':len(derived),'answerRows':len(gold)},
            'provenance':'Fresh seeded relational instances inspired by DatalogBench recursive/dataflow use cases; not official benchmark items or a claim of training-set exclusion.'}


def extract(raw):
    decoder=json.JSONDecoder()
    # Select the final answer object, allowing reasoning and Markdown around it.
    matches=[]
    for i,char in enumerate(raw):
        if char!='{':continue
        try:value,_=decoder.raw_decode(raw[i:])
        except ValueError:continue
        if isinstance(value,dict) and isinstance(value.get('answer'),list):matches.append(value['answer'])
    if not matches:return None
    value=matches[-1]
    return sorted(set(value)) if all(isinstance(x,str) for x in value) else None


def run(library,output,live):
    output.mkdir(parents=True,exist_ok=False)
    cases=[task(family,2026101300+family*17+repeat) for repeat in range(2) for family in range(4)]
    plan={'schema':'ascent.trajectory-study.v1','cases':cases,'arms':['reflection-only','native-evidence'],
          'maxAttempts':3,'maxOutputTokens':131072,'model':'deepseek-flash','effort':'high',
          'primary':'Actual cumulative provider thinking through first independently verified correct answer, including failures and repairs.',
          'sampling':'Eight independent generated cases; arm order alternates; evidence appears only after an actual error.',
          'providerOutputSchemaEnforced':False,'sourceHashes':{p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in
            ['program/evidence-dag.ss','program/trajectory.ss','rust/ascent-python/src/api/trajectory.rs',__file__]},
          'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest()}
    (output/'plan.json').write_text(json.dumps(plan,indent=2))
    engine=ReasoningRuntime();records=[];key=provider_key() if live else None
    try:
        for index,case in enumerate(cases):
            # Independently derived closure must agree with actual Scheme execution.
            with EvidenceChain(engine,case['sources']) as preflight:
                feedback=preflight.query(case['program'])
                native=sorted(x[0] for x in feedback['result']['relations']['answer'])
                if native!=case['gold']:raise AssertionError(f'oracle mismatch: {case["case"]}')
                dag=evidence_graph(case['program'])
                positions={n['id']:i for i,n in enumerate(dag['nodes'])}
                assert all(positions[e['from']]<positions[e['to']] for e in dag['edges'])
                (output/f'{case["case"]}-dag.json').write_text(json.dumps(dag,indent=2))
            if not live:continue
            arms=plan['arms'] if index%2==0 else list(reversed(plan['arms']))
            for arm in arms:
                folder=output/f'{case["case"]}-{arm}';folder.mkdir()
                trajectory=Trajectory(engine,case['case'],identity(case['sources']))
                chain=EvidenceChain(engine,case['sources'],trajectory=trajectory) if arm=='native-evidence' else None
                history=ResponseHistory(case['question']);calls=[];reference=None
                for attempt in range(1,4):
                    request={'model':plan['model'],'input':history.input(),'reasoning':{'effort':plan['effort']},
                             'max_output_tokens':plan['maxOutputTokens'],'stream':True,'store':False}
                    (folder/f'{attempt}-request.json').write_text(json.dumps(request,indent=2))
                    print(f'CALL {case["case"]} {arm} attempt={attempt}',flush=True)
                    with contextlib.redirect_stdout(io.StringIO()):
                        raw,meta=provider(request,key,folder/f'{attempt}-provider.json')
                    (folder/f'{attempt}-answer.txt').write_text(raw)
                    terminal=meta.get('terminal') or {};usage=terminal.get('usage')
                    trajectory.model_call(f'{case["case"]}:{arm}:{attempt}',attempt,usage)
                    prediction=extract(raw);correct=prediction==case['gold']
                    trajectory.verify(correct,'independent-fixed-point-oracle.v1',round=attempt,candidate=prediction)
                    calls.append({'attempt':attempt,'correct':correct,'prediction':prediction,'usage':usage,
                                  'error':meta.get('error'),'status':terminal.get('status'),'providerSeconds':meta['providerSeconds']})
                    print(f'RESULT correct={correct} usagePresent={bool(usage)} status={terminal.get("status")}',flush=True)
                    if meta.get('error') or terminal.get('status') in ('failed','incomplete'):
                        break
                    if correct:break
                    history.append_response(terminal)
                    if chain:
                        feedback=chain.query(case['program']);reference=feedback['resultReference']
                        history.append_feedback({'instruction':'Reflect on the previous error. Continue using these source-bound native facts.',
                                                 'evidence':feedback})
                    else:history.append_feedback({'correct':False,'instruction':'Reflect on the previous error and recompute the complete answer relation, including all joins and scoped negative conditions.'})
                primary=trajectory.snapshot();repeated=None;invalidation=None
                if chain and primary['verified']:
                    if reference is None:reference=chain.query(case['program'])['resultReference']
                    before=trajectory.snapshot()['totals']['modelCalls']
                    repeat_answer=sorted(row[0] for row in chain.answer(reference,'answer'))
                    trajectory.verify(repeat_answer==case['gold'],'independent-repeat-oracle.v1')
                    repeated={'correct':repeat_answer==case['gold'],'actualModelCalls':trajectory.snapshot()['totals']['modelCalls']-before}
                    # Withdraw all starts: old result must be rejected; fresh result is empty.
                    changed=json.loads(json.dumps(case['sources']));next(r for r in changed if r['name']=='start')['rows']=[]
                    chain.replace(changed)
                    try:chain.answer(reference,'answer');stale_rejected=False
                    except ValueError:stale_rejected=True
                    changed_program=json.loads(json.dumps(case['program']))
                    changed_program['relations']=[next((r for r in changed if r['name']==old['name']),old) for old in changed_program['relations']]
                    fresh=chain.query(changed_program)
                    fresh_correct=fresh['result']['relations']['answer']==[]
                    trajectory.verify(fresh_correct,'independent-withdrawal-oracle.v1')
                    invalidation={'staleRejected':stale_rejected,'freshCorrect':fresh_correct,'reusedComponents':len(fresh['reusedComponents'])}
                if chain is None and primary['verified']:
                    repeat_request={'model':plan['model'],'input':ResponseHistory(case['question']).input(),
                                    'reasoning':{'effort':plan['effort']},'max_output_tokens':plan['maxOutputTokens'],
                                    'stream':True,'store':False}
                    (folder/'repeat-request.json').write_text(json.dumps(repeat_request,indent=2))
                    print(f'REPEAT {case["case"]} {arm}',flush=True)
                    with contextlib.redirect_stdout(io.StringIO()):
                        raw,meta=provider(repeat_request,key,folder/'repeat-provider.json')
                    (folder/'repeat-answer.txt').write_text(raw)
                    usage=(meta.get('terminal') or {}).get('usage')
                    trajectory.model_call(f'{case["case"]}:{arm}:repeat',len(calls)+1,usage)
                    correct=extract(raw)==case['gold']
                    trajectory.verify(correct,'independent-repeat-oracle.v1')
                    repeated={'correct':correct,'actualModelCalls':1,'usage':usage,'error':meta.get('error')}
                closed=trajectory.close('first-correct' if primary['verified'] else 'attempt-budget-or-provider-error')
                if chain:chain.close()
                record={'case':case['case'],'arm':arm,'calls':calls,'primary':primary,'trajectory':closed,
                        'repeat':repeated,'invalidation':invalidation}
                records.append(record);(output/'records.json').write_text(json.dumps(records,indent=2))
                if calls and calls[-1]['error']:
                    # A transport rejection is not a model reasoning failure: stop
                    # further paid requests, preserve this censored trajectory.
                    raise RuntimeError('Provider transport rejected; see recorded provider response, not output schema.')
        result={'preparedCases':len(cases),'records':records,'offlineOracleAgreement':len(cases)}
        (output/'result.json').write_text(json.dumps(result,indent=2));print(f'DONE cases={len(cases)} trajectories={len(records)}',flush=True)
    finally:engine.close()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--library',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);parser.add_argument('--live',action='store_true')
    args=parser.parse_args();run(args.library.resolve(),args.output.resolve(),args.live)

if __name__=='__main__':main()
