# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Recover a receipted response interrupted by a local worker-pool failure."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
from . import repository_model_study as study
from .repository_continuation import continue_episode, replay_source, dispatch


def recover(plan_dir, primary, interrupted, output):
    plan_dir, primary, interrupted, output = (p.resolve() for p in (plan_dir, primary, interrupted, output))
    plan = json.loads((plan_dir/'plan.json').read_text())
    records = [json.loads(f.read_text()) for f in sorted(interrupted.glob('*/episode.json'))]
    unfinished = [r for r in records if r['status'] == 'running']
    if len(records) != 12 or len(unfinished) != 1: raise ValueError('recovery requires exactly one interrupted trajectory and eleven terminal records')
    record = copy.deepcopy(unfinished[0]); case = next(c for c in plan['tasks'] if c['name'] == record['task'])
    name = f"{record['task']}-rep-{record['repetition']}-{record['arm']}"
    original = interrupted/name
    output.mkdir(parents=True, exist_ok=False)
    prefix = output/'recovery-input'/name; prefix.mkdir(parents=True)
    last = record['attempts'][-1]['turn']
    for turn in range(1, last+1):
        source = primary/name if turn <= plan['maxTurns'] else original
        for kind in ('request','response'):
            shutil.copy2(source/f'{turn}.{kind}.json', prefix/f'{turn}.{kind}.json')
    terminal = json.loads((prefix/f'{last}.response.json').read_text())['terminal']
    if not terminal.get('usage'): raise ValueError('interrupted response has no usage; do not guess paid completion')
    manifest = {'schema':'ascent.repository-recovery.v1','reason':'local idle worker queue BlockingIOError broke the pool after a fully receipted model response','totalTurnCeiling':40,'interruptedRecordSha256':hashlib.sha256((original/'episode.json').read_bytes()).hexdigest(),'pendingResponseSha256':hashlib.sha256((prefix/f'{last}.response.json').read_bytes()).hexdigest(),'originalProducerHashes':plan['producerHashes'],'recoveryProducerHashes':{str(p.relative_to(study.ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (Path(__file__),Path(study.__file__),study.ROOT/'rust/ascent-python/src/api/exports.rs',Path(__file__).with_name('repository_continuation.py'))},'policy':'Keep every paid turn, complete only missing outputs from the saved response, then continue the same history serially. No repeated paid calls.'}
    (output/'plan.json').write_text(json.dumps(manifest,indent=2)+'\n')
    workspace = study.Workspace(plan_dir, prefix, case, record['arm'])
    try:
        prior = copy.deepcopy(record); prior['attempts'] = prior['attempts'][:-1]
        replay_source(workspace, prefix, prior)
        attempt = record['attempts'][-1]
        existing = {a.get('callId') for a in attempt['actions']}
        for call in terminal['output']:
            if call.get('type') != 'function_call' or call['call_id'] in existing: continue
            result = dispatch(workspace, call)
            attempt['actions'].append({'name':call['name'],'callId':call['call_id'],'result':result})
            if call['name']=='submit_patch' and result.get('verified'): attempt['correct']=True
        if not any(x.get('type') == 'function_call' for x in terminal['output']):
            raise ValueError('implicit response recovery needs an explicit saved feedback receipt')
        record['recoveryPreparationJournal'] = workspace.journal
        record['interruptedStatus'] = record['status']; record['status'] = 'verified' if attempt['correct'] else 'censored'
        (prefix/'episode.json').write_text(json.dumps(record,indent=2)+'\n')
    finally: workspace.close()
    destination = output/'continued'; destination.mkdir()
    completed = continue_episode(plan_dir, output/'recovery-input', destination, case, record['repetition'], record['arm'], 40)
    receipt = {'schema':manifest['schema'],'complete':completed['status'] in ('verified','censored'),'episodes':[r for r in records if r['status']!='running']+[completed]}
    (output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('REPOSITORY-RECOVERY-COMPLETE',completed['status'],'total-calls='+str(len(completed['attempts'])),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('plan','primary','interrupted','output'): parser.add_argument(name,type=Path)
    args=parser.parse_args();recover(args.plan,args.primary,args.interrupted,args.output)
