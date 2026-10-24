# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Continue a genuinely failed control prefix with checked intermediate facts.

The failed response is replayed identically; all preceding actual usage is
charged again to this alternative policy, but not to physical expenditure.
"""
import argparse,contextlib,copy,hashlib,io,json
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from .trajectory_study import extract
from .model_study import provider
from .movie_study import provider_key


def run(source,library,output):
    plan=json.loads((source/'plan.json').read_text());records=json.loads((source/'records.json').read_text())
    control=next(r for r in records if r['arm']=='reflection')
    failures=[(i,c) for i,c in enumerate(control['calls']) if c['stage']==2 and c['failureKind']=='semantic']
    if not failures:raise ValueError('no eligible real second-query semantic failure')
    index,failed=failures[0];case=next(c for c in plan['cases'] if c['case']==control['case'])
    remaining=3-failed['attempt']
    if remaining<=0:raise ValueError('no remaining matched repair allowance')
    request_path=source/(case['case']+'-reflection')/f"2-{failed['attempt']+1}-request.json"
    request=json.loads(request_path.read_text());history=ResponseHistory.restore(request['input'])
    output.mkdir(parents=True,exist_ok=False)
    repair_plan={'schema':'ascent.failed-prefix-repair.v1','case':case,'source':str(source),'control':control,
       'prefix':control['calls'][:index+1],'remainingRepairs':remaining,'pairedRepairRequestSha256':hashlib.sha256(request_path.read_bytes()).hexdigest(),
       'eligibility':'First actual semantic failure in second-query reflection condition; all eligible held-out tasks are retained.',
       'primary':'Whole-task cumulative thinking including every shared/failed prefix call until both goals pass.',
       'librarySha256':hashlib.sha256(library.read_bytes()).hexdigest(),'sourceSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (output/'plan.json').write_text(json.dumps(repair_plan,indent=2))
    engine=ReasoningRuntime();trajectory=Trajectory(engine,'failed-prefix:'+case['case'],identity(case['sources']));calls=[];key=provider_key()
    try:
        for c in repair_plan['prefix']:
            trajectory.model_call(c['callId'],c['round'],c['usage'])
            trajectory.verify(c['correct'],'independent-relational-oracle.v2',round=c['round'],scope='subgoal',candidate=c['prediction'])
        with EvidenceChain(engine,case['sources'],trajectory=trajectory) as chain:
            first=chain.query(case['program']);second=chain.query(case['secondProgram'])
            packet=chain.intermediates(second['resultReference'],case['intermediates'])
            assert 'answer' not in packet['facts']
            restored_input=history.input()
            feedback=json.loads(restored_input[-1]['content']);feedback['verifiedIntermediates']=packet
            restored_input[-1]['content']=json.dumps(feedback,sort_keys=True)
            history=ResponseHistory.restore(restored_input)
            for attempt in range(1,remaining+1):
                request['input']=history.input();(output/f'{attempt}-request.json').write_text(json.dumps(request,indent=2))
                print('CALL repair',case['case'],attempt,flush=True)
                with contextlib.redirect_stdout(io.StringIO()):raw,meta=provider(request,key,output/f'{attempt}-provider.json')
                (output/f'{attempt}-answer.txt').write_text(raw);terminal=meta.get('terminal') or {};usage=terminal.get('usage')
                correct=terminal.get('status')=='completed' and meta.get('error') is None and extract(raw)==case['gold'][1]
                round=failed['round']+attempt;call={'callId':'repair:'+case['case']+':'+str(attempt),'round':round,
                    'usage':usage,'correct':correct,'prediction':extract(raw),'status':terminal.get('status'),
                    'error':meta.get('error'),'providerSeconds':meta['providerSeconds']}
                calls.append(call);trajectory.model_call(call['callId'],round,usage)
                if meta.get('error'):break
                trajectory.verify(correct,'independent-relational-oracle.v2',round=round,
                                  scope='task' if correct else 'subgoal',candidate=call['prediction'])
                print('RESULT repair',case['case'],attempt,correct,flush=True)
                if correct:break
                if terminal.get('status')=='completed':history.append_response(terminal)
                # Keep the control's scalar feedback identical on every repair.
                history.append_feedback(feedback)
            result={'case':case['case'],'prefix':repair_plan['prefix'],'calls':calls,'packet':packet,
                    'reusedComponents':second['reusedComponents'],'trajectory':trajectory.close('correct' if calls[-1]['correct'] else 'attempt-budget-or-provider-error')}
            (output/'result.json').write_text(json.dumps(result,indent=2));print('DONE repair',case['case'],flush=True)
    finally:trajectory.close('exception');engine.close()


def main():
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--library',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();run(a.source.resolve(),a.library.resolve(),a.output.resolve())
if __name__=='__main__':main()
