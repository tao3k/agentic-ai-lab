# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Uniform adaptive continuation, preserving primary history and charged effort."""
import argparse
import concurrent.futures
import contextlib
import copy
import hashlib
import json
import multiprocessing
from pathlib import Path

from agentic_ai_lab_runtime.reasoning import ResponseHistory
from . import repository_model_study as study


def restored_history(directory, record):
    last = record['attempts'][-1]['turn']
    request = json.loads((directory / f'{last}.request.json').read_text())
    terminal = json.loads((directory / f'{last}.response.json').read_text())['terminal']
    history = ResponseHistory.restore(request['input'])
    calls = history.append_response(terminal)
    results = {action['callId']: action['result'] for action in record['attempts'][-1]['actions'] if 'callId' in action}
    for call in calls:
        history.append_result(call['call_id'], results[call['call_id']])
    if not calls:
        actions = record['attempts'][-1]['actions']
        if not actions: raise ValueError('last implicit feedback unavailable; cannot restore exact history')
        history.append_feedback(actions[-1]['result'])
    return history, request


def replay_source(workspace, original, record):
    """Reconstruct actual evidence state without rerunning historical tests or models."""
    for attempt in record['attempts']:
        terminal = json.loads((original / f"{attempt['turn']}.response.json").read_text())['terminal']
        actions = {action.get('callId'): action for action in attempt['actions']}
        for call in terminal['output']:
            if call.get('type') != 'function_call': continue
            action = actions[call['call_id']]
            result = action.get('result')
            if isinstance(result, dict) and ('error' in result or 'skipped' in result): continue
            args = study.loose_json(call['arguments'])
            if call['name'] == 'edit_source': workspace.edit(args['edits'])
            elif call['name'] == 'read_source': workspace.read(args['path'], args.get('start', 1), args.get('end'))
    for relative in workspace.case['editable']:
        if (workspace.root / relative).read_bytes() != (original / 'workspace' / relative).read_bytes():
            raise ValueError('replay did not reproduce primary source identity')
    return copy.deepcopy(workspace.journal)


def dispatch(workspace, call):
    args = study.loose_json(call['arguments'])
    name = call['name']
    if name == 'read_source': return workspace.read(args['path'], args.get('start', 1), args.get('end'))
    if name == 'search_source': return workspace.search(args['text'], args.get('path'))
    if name == 'edit_source': return workspace.edit(args['edits'])
    if name == 'run_reproducer': return workspace.execute(reproducer=True)
    if name == 'run_checks': return workspace.execute()
    if name == 'submit_patch': return workspace.execute(grading=True)
    raise ValueError('unknown tool')


def continue_episode(plan_dir, primary, output, case, rep, arm, ceiling):
    name = f"{case['name']}-rep-{rep}-{arm}"
    original = primary / name
    record = json.loads((original / 'episode.json').read_text())
    if record['status'] != 'censored': return record
    directory = output / name
    directory.mkdir()
    history, request_template = restored_history(original, record)
    workspace = study.Workspace(plan_dir, directory, case, arm)
    try:
        reconstructed = replay_source(workspace, original, record)
        record['reconstructionJournal'] = reconstructed
        record['primaryStatus'] = record['status']
        record['status'] = 'running'
        record['adaptiveContinuation'] = {'totalTurnCeiling': ceiling, 'primaryDirectory': str(original)}
        offset = len(workspace.journal)
        def save():
            record['evidenceJournal'] = json.loads((original / 'episode.json').read_text())['evidenceJournal'] + workspace.journal[offset:]
            record['effort'] = study.until_verified(record['attempts'])
            (directory / 'episode.json').write_text(json.dumps(record, indent=2) + '\n')
        save()
        key = study.provider_key()
        with (directory / 'progress.log').open('w') as log, contextlib.redirect_stdout(log):
            for turn in range(record['attempts'][-1]['turn'] + 1, ceiling + 1):
                request = {**request_template, 'input': history.input()}
                (directory / f'{turn}.request.json').write_text(json.dumps(request, indent=2) + '\n')
                raw, meta = study.provider(request, key, directory / f'{turn}.response.json')
                terminal = meta.get('terminal') or {}
                attempt = {'turn': turn, 'providerCalls': 1, 'usage': terminal.get('usage'), 'correct': False, 'adaptive': True, 'providerOutcome': study.response_outcome(meta), 'providerSeconds': meta['providerSeconds'], 'actions': [], 'sourceIdentity': workspace.source_identity}
                record['attempts'].append(attempt); save()
                if meta.get('error') or not attempt['usage']:
                    record['status'] = 'transport_failure'; attempt['error'] = meta.get('error'); break
                calls = history.append_response(terminal)
                if not calls:
                    try:
                        payload = study.loose_json(raw)
                        if isinstance(payload, dict) and 'edits' in payload: workspace.edit(payload['edits'])
                        result = workspace.execute(grading=True)
                        attempt['correct'] = result['verified']
                    except Exception as error:
                        result = {'error': type(error).__name__ + ': ' + str(error)[:1500]}
                    attempt['actions'].append({'name': 'implicit_submit', 'result': result})
                    history.append_feedback(result)
                for call in calls:
                    try:
                        result = {'skipped': 'repair already verified'} if attempt['correct'] else dispatch(workspace, call)
                        if call['name'] == 'submit_patch' and result.get('verified'): attempt['correct'] = True
                    except Exception as error:
                        result = {'error': type(error).__name__ + ': ' + str(error)[:1500]}
                    attempt['actions'].append({'name': call['name'], 'callId': call['call_id'], 'result': result})
                    history.append_result(call['call_id'], result)
                for action in attempt['actions']:
                    result = action['result']
                    if isinstance(result, dict) and (result.get('exitCode') == 65 or result.get('error', '').startswith(('RuntimeError: test environment', 'TimeoutError: test execution'))):
                        record['status'] = 'harness_failure'
                save()
                if record['status'] == 'harness_failure': break
                if attempt['correct']: record['status'] = 'verified'; break
        if record['status'] == 'running': record['status'] = 'censored'
        save()
    finally:
        workspace.close()
    print('REPOSITORY-CONTINUATION', name, record['status'], 'total-calls=' + str(len(record['attempts'])), flush=True)
    return record


def live(plan_dir, primary, output, ceiling=40):
    plan_dir, primary, output = plan_dir.resolve(), primary.resolve(), output.resolve()
    plan = json.loads((plan_dir / 'plan.json').read_text())
    result = json.loads((primary / 'result.json').read_text())
    if not result['complete']: raise ValueError('primary study must finish before uniform continuation')
    for path, digest in plan['producerHashes'].items():
        if hashlib.sha256((study.ROOT / path).read_bytes()).hexdigest() != digest: raise ValueError('producer drift')
    output.mkdir(parents=True, exist_ok=False)
    manifest = {'schema': 'ascent.repository-continuation.v1', 'totalTurnCeiling': ceiling, 'primarySha256': hashlib.sha256((primary / 'result.json').read_bytes()).hexdigest(), 'producerSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'policy': 'Continue every censored trajectory equally; preserve history, source state and all primary usage. Reconstruct source/evidence state with measured local work; no historical model or test calls are repeated.'}
    (output / 'plan.json').write_text(json.dumps(manifest, indent=2) + '\n')
    receipt = {'schema': manifest['schema'], 'complete': False, 'episodes': []}
    jobs = [(case, rep, arm) for case in plan['tasks'] for rep in range(plan['repetitions']) for arm in plan['arms']]
    with concurrent.futures.ProcessPoolExecutor(max_workers=2, mp_context=multiprocessing.get_context('spawn'),max_tasks_per_child=1) as pool:
        iterator = iter(jobs)
        pending = {pool.submit(continue_episode, plan_dir, primary, output, *next(iterator), ceiling) for _ in range(2)}
        while pending:
            done, pending = concurrent.futures.wait(pending, return_when=concurrent.futures.FIRST_COMPLETED)
            for future in done:
                record = future.result(); receipt['episodes'].append(record)
                (output / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')
                if record['status'] in ('harness_failure', 'transport_failure'): raise RuntimeError('stop new dispatch after failed execution or transport')
                job = next(iterator, None)
                if job: pending.add(pool.submit(continue_episode, plan_dir, primary, output, *job, ceiling))
    receipt['complete'] = True
    (output / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('REPOSITORY-CONTINUATION-COMPLETE', len(receipt['episodes']), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plan', type=Path); parser.add_argument('primary', type=Path); parser.add_argument('output', type=Path)
    parser.add_argument('--total-turns', type=int, default=40)
    args = parser.parse_args()
    live(args.plan, args.primary, args.output, args.total_turns)
