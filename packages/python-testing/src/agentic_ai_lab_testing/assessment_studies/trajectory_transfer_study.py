# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Two-goal bundles: reuse checked intermediate relations for a new query."""
import argparse
import contextlib
import copy
import hashlib
import io
import json
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from .trajectory_study import task, atom, rule, closure, extract
from .model_study import provider
from .movie_study import provider_key


def followup(case):
    program=copy.deepcopy(case['program']);sources={r['name']:r['rows'] for r in case['sources']}
    edges={tuple(row) for row in sources['edge']};blocked={r[0] for r in sources['blocked']}
    reached=closure(edges,[r[0] for r in sources['start']],blocked)
    rules=[r for r in program['rules'] if r['head'][0]['relation']!='answer']
    family=case['family']
    if family=='recursive-scoped-reachability':
        rules.append(rule(atom('answer','x'),atom('reach','x'),atom('target','x'),atom('edge','x','y'),atom('edge','y','z'),atom('blocked','z')))
        targets={r[0] for r in sources['target']}
        gold={x for x in reached&targets if any(a==x and c==b and d in blocked for a,b in edges for c,d in edges)}
    elif family=='taint-propagation-with-sanitizers':
        rules.append(rule(atom('answer','x'),atom('reach','x'),atom('sink','x'),atom('approved','x',negative=True),atom('edge','x','y'),atom('approved','y')))
        sinks={r[0] for r in sources['sink']};approved={r[0] for r in sources['approved']}
        gold={x for x in (reached&sinks)-approved if any(a==x and b in approved for a,b in edges)}
    elif family=='conjunctive-prerequisite-closure':
        rules.append(rule(atom('answer','job'),atom('needs','job','a','b'),atom('reach','a'),atom('blocked','b'),atom('deferred','job',negative=True)))
        deferred={r[0] for r in sources['deferred']}
        gold={job for job,a,b in sources['needs'] if a in reached and b in blocked and job not in deferred}
    else:
        rules.append(rule(atom('answer','x'),atom('reach','x'),atom('back','x'),atom('target','x'),atom('edge','x','y'),atom('blocked','y')))
        back=closure({(b,a) for a,b in edges},[r[0] for r in sources['finish']],blocked)
        targets={r[0] for r in sources['target']}
        gold={x for x in reached&back&targets if any(a==x and b in blocked for a,b in edges)}
    program['rules']=rules
    return program,sorted(gold)


def run(library,output,live):
    output.mkdir(parents=True,exist_ok=False)
    cases=[]
    for family in range(4):
        case=task(family,2026102300+family*19)
        second,gold=followup(case);case.update(secondProgram=second,secondGold=gold)
        cases.append(case)
    plan={'schema':'ascent.trajectory-transfer-study.v1','cases':cases,'model':'deepseek-flash',
          'effort':'high','maxOutputTokens':131072,'maxAttemptsPerStage':3,
          'primary':'Cumulative actual thinking until BOTH predeclared query obligations are independently verified correct.',
          'intervention':'Second stage receives ONLY completed reach/back facts from stage one, never the second answer.',
          'histories':'Both conditions retain all actual reasoning/messages opaquely.',
          'sourceHashes':{p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in
             [__file__,'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/trajectory_study.py','program/trajectory.ss','program/evidence-dag.ss']},
          'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest()}
    (output/'plan.json').write_text(json.dumps(plan,indent=2))
    engine=ReasoningRuntime();records=[];key=provider_key() if live else None
    try:
        for index,case in enumerate(cases):
            with EvidenceChain(engine,case['sources']) as preflight:
                for program,gold in [(case['program'],case['gold']),(case['secondProgram'],case['secondGold'])]:
                    result=preflight.query(program)
                    assert sorted(row[0] for row in result['result']['relations']['answer'])==gold
            if not live:continue
            arms=['reflection-history','verified-intermediates']
            if index%2:arms.reverse()
            for arm in arms:
                folder=output/f'{case["case"]}-{arm}';folder.mkdir()
                trajectory=Trajectory(engine,'two-query-bundle:'+case['case'],identity(case['sources']))
                history=ResponseHistory('This task has TWO successive queries over unchanged sources. Complete the first now; '
                                        'the second query will follow. Success requires BOTH complete relations.\n'+case['question'])
                chain=EvidenceChain(engine,case['sources'],trajectory=trajectory) if arm=='verified-intermediates' else None
                calls=[];round=0;all_correct=True;support=None;reused=[]
                for stage,(program,gold) in enumerate([(case['program'],case['gold']),(case['secondProgram'],case['secondGold'])],1):
                    if stage==2:
                        history.append_feedback({'instruction':'Now solve the SECOND query. Sources are unchanged. '
                                                 'Join the explicit body atoms; do not confuse an edge test with recursive propagation. '
                                                 'Finish with FINAL_JSON: {"answer": [...]} .',
                                                 'program':program,**({'verifiedIntermediates':support} if support else {})})
                    correct=False
                    for attempt in range(1,4):
                        round+=1
                        request={'model':plan['model'],'input':history.input(),'reasoning':{'effort':plan['effort']},
                                 'max_output_tokens':plan['maxOutputTokens'],'stream':True,'store':False}
                        (folder/f'{round}-request.json').write_text(json.dumps(request,indent=2))
                        print(f'CALL {case["case"]} {arm} stage={stage} attempt={attempt}',flush=True)
                        with contextlib.redirect_stdout(io.StringIO()):raw,meta=provider(request,key,folder/f'{round}-provider.json')
                        (folder/f'{round}-answer.txt').write_text(raw)
                        terminal=meta.get('terminal') or {};usage=terminal.get('usage')
                        trajectory.model_call(f'{case["case"]}:{arm}:{round}',round,usage)
                        prediction=extract(raw);correct=prediction==gold
                        calls.append({'round':round,'stage':stage,'correct':correct,'usage':usage,'error':meta.get('error'),
                                      'prediction':prediction,'providerSeconds':meta['providerSeconds']})
                        print(f'RESULT correct={correct} stage={stage} usagePresent={bool(usage)}',flush=True)
                        if stage==2 or not correct:trajectory.verify(correct,'independent-two-query-oracle.v1',round=round,candidate=prediction)
                        if meta.get('error'):
                            raise RuntimeError('Provider transport error; response saved independently of answer formatting.')
                        history.append_response(terminal)
                        if correct:break
                        history.append_feedback({'correct':False,'instruction':'Reflect on and repair the incorrect complete relation; both query obligations must pass.'})
                    if not correct:all_correct=False;break
                    if stage==1 and chain:
                        feedback=chain.query(program)
                        facts={};keys={}
                        for descriptor in feedback['freshComponents']+feedback['reusedComponents']:
                            for name in descriptor['relations']:
                                if name in ('reach','back'):
                                    alias=chain.certificates[descriptor['fingerprint']][name]
                                    facts[name]=chain.scan([alias])['relations'][alias]
                                    keys[name]=descriptor['fingerprint']
                        support={'sourceIdentity':feedback['sourceIdentity'],'pathIdentity':feedback['pathIdentity'],
                                 'resultReference':feedback['resultReference'],'componentFingerprints':keys,'facts':facts}
                        assert 'answer' not in facts
                if chain and all_correct:
                    final=chain.query(case['secondProgram']);reused=final['reusedComponents']
                    assert sorted(row[0] for row in final['result']['relations']['answer'])==case['secondGold']
                record={'case':case['case'],'arm':arm,'calls':calls,'verifiedBoth':all_correct,
                        'intermediatePacket':support,'nativeReusedComponents':reused,
                        'trajectory':trajectory.close('both-correct' if all_correct else 'attempt-budget')}
                if chain:chain.close()
                records.append(record);(output/'records.json').write_text(json.dumps(records,indent=2))
        (output/'result.json').write_text(json.dumps({'cases':len(cases),'records':records,'offlineOracleAgreement':8},indent=2))
        print(f'DONE bundles={len(cases)} trajectories={len(records)}',flush=True)
    finally:engine.close()


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--library',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);parser.add_argument('--live',action='store_true')
    args=parser.parse_args();run(args.library.resolve(),args.output.resolve(),args.live)

if __name__=='__main__':main()
