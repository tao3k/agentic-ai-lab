# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Replay public admitted edits and independently grade first valid candidates.

No provider reasoning is inspected. Offline grades are not model feedback and do
not replace the frozen primary submission endpoint.
"""
import argparse
import concurrent.futures
import copy
import hashlib
import json
import multiprocessing
from pathlib import Path
from . import repository_model_study as study
from .inference_effort import until_verified
from .inference_reuse_study import price


def admitted_edits(record, directory):
    for attempt in record['attempts']:
        actions=[a for a in attempt['actions'] if a['name'] in ('edit_source','implicit_edit')
                 and isinstance(a.get('result'),dict) and a['result'].get('edited')]
        if not actions:continue
        response=json.loads((directory/f"{attempt['turn']}.response.json").read_text())['terminal']
        calls={x['call_id']:x for x in response['output'] if x['type']=='function_call'}
        for action in actions:
            if action['name']=='implicit_edit':
                text=''.join(c['text'] for x in response['output'] if x['type']=='message'
                             for c in x.get('content',[]) if c.get('type')=='output_text')
                payload=study.loose_json(text)
            else:
                call=calls[action['callId']]
                assert call['name']=='edit_source'
                payload=study.loose_json(call['arguments'])
            yield attempt['turn'],payload['edits'],action['result']['sourceIdentity']


def audit_one(plan_dir, output, case, record_path):
    record=json.loads(record_path.read_text());directory=record_path.parent
    target=output/'candidate-audit'/directory.name;target.mkdir(parents=True,exist_ok=False)
    workspace=study.Workspace(plan_dir,target,case,'ordinary-tools')
    assessments=[];first_valid=None;first_failure=None;last_grade=None
    def assess():
        try:return workspace.execute(grading=True)
        except TimeoutError as error:
            return {'verified':False,'boundedFailure':'execution-timeout',
                    'sourceIdentity':workspace.source_identity,'error':str(error)}
    try:
        for turn,edits,expected in admitted_edits(record,directory):
            result=workspace.edit(edits)
            if result['sourceIdentity']!=expected:raise ValueError('admitted candidate identity differs during replay')
            if first_valid is None:
                grade=assess()
                last_grade=(expected,grade)
                assessments.append({'turn':turn,'sourceIdentity':expected,'grade':grade})
                if grade['verified']:first_valid=turn
                elif first_failure is None:first_failure=turn
        final_identity=study.identity({p:hashlib.sha256((directory/'workspace'/p).read_bytes()).hexdigest() for p in case['editable']})
        if workspace.source_identity!=final_identity:raise ValueError('final candidate replay differs; implicit edits require explicit audit support')
        if last_grade is not None and last_grade[0]==final_identity:final_grade=last_grade[1]
        else:final_grade=assess()
        attempts=copy.deepcopy(record['attempts'])
        for a in attempts:a['correct']=first_valid is not None and a['turn']==first_valid
        effort=until_verified(attempts)
        if first_failure is not None and (first_valid is None or first_failure<=first_valid):
            prefix=[a for a in attempts if a['turn']>=first_failure];repair=until_verified(prefix)
        else:repair={'observedReasoningTokens':0,'modelCalls':0,'reasoningUsageComplete':True}
        selected=attempts[:effort['attempts']]
        receipt={'task':record['task'],'arm':record['arm'],'repetition':record['repetition'],
                 'primaryStatus':record['status'],'firstValidCandidateTurn':first_valid,
                 'firstRejectedCandidateTurn':first_failure,'effort':effort,'repairEffort':repair,
                 'peakDollarEstimate':sum(price(a['usage']) for a in selected) if effort['modelUsageComplete'] else None,
                 'finalCandidateVerified':final_grade['verified'],'finalCandidateGrade':final_grade,
                 'assessments':assessments,'episodeSha256':hashlib.sha256(record_path.read_bytes()).hexdigest(),
                 'boundary':'Post-run offline selected-grader assessment of admitted edits. No feedback or provider calls. Whole-turn cost; independent candidate discovery is distinct from model submission.'}
        (target/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        print('CANDIDATE-AUDIT',directory.name,'first='+str(first_valid),'final='+str(final_grade['verified']),flush=True)
        return receipt
    finally:workspace.close()


def audit(plan_dir, output, workers):
    plan=json.loads((plan_dir/'plan.json').read_text())
    result=json.loads((output/'result.json').read_text())
    if not result['complete']:raise ValueError('candidate audit requires a completed frozen run')
    jobs=[(plan_dir,output,next(c for c in plan['tasks'] if c['name']==r['task']),output/f"{r['task']}-rep-{r['repetition']}-{r['arm']}"/'episode.json') for r in result['episodes']]
    with concurrent.futures.ProcessPoolExecutor(max_workers=workers,mp_context=multiprocessing.get_context('spawn'),max_tasks_per_child=1) as pool:
        futures=[pool.submit(audit_one,*job) for job in jobs]
        receipts=[f.result() for f in futures]
    destination=output/'candidate-audit.json'
    destination.write_text(json.dumps({'schema':'ascent.candidate-discovery-audit.v1','planSha256':hashlib.sha256((plan_dir/'plan.json').read_bytes()).hexdigest(),'producerSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'trajectories':receipts},indent=2)+'\n')
    print('CANDIDATE-AUDIT-COMPLETE',len(receipts),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('plan',type=Path);parser.add_argument('output',type=Path);parser.add_argument('--workers',type=int,default=2)
    args=parser.parse_args();audit(args.plan.resolve(),args.output.resolve(),args.workers)
