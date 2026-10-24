# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Budget-bounded provider IO and computed feedback context."""
import json
import os
from pathlib import Path
import sys
import time
import statistics
from .tasks import digest
from .native import score_candidate
from .worker import NativeStudyWorker, worker_source

def _request(plan, preview, item, initial):
    source = (preview/f"{item['case']}.input.ss").read_text()
    inputs = [{'role': 'user', 'content': source}]
    if item['arm'] in ('transfer-history', 'transfer-feedback'):
        previous = initial[item['family']]
        # Context reuse preserves the real initial task/output and the native
        # observation. It does not insert a natural-language teaching template.
        # Reuse exact implementation bytes; the new task is a separate module
        # input rather than pretending that a mutated datum is the old state.
        modules_end = source.index('\n(import :std/test :gerbil-ascent/program/scheme-language)')
        first_source = (preview/f"{item['family']}-initial.input.ss").read_text()
        transfer = source[modules_end:]
        observation = json.dumps(previous['observation'], sort_keys=True)
        inputs = [{'role': 'user', 'content': first_source},
                  {'role': 'assistant', 'content': previous['raw']},
                  {'role': 'user', 'content': (observation + '\n' if item['arm'] == 'transfer-feedback' else '') + transfer}]
    request = {'model': plan['model'], 'input': inputs,
               'reasoning': {'effort': item['reasoningEffort']},
               'max_output_tokens': plan['maxOutputTokens'], 'stream': True}
    encoded_input = json.dumps(inputs, ensure_ascii=False).encode()
    if len(encoded_input) > plan['maxInputBytes']:
        raise ValueError('frozen input byte ceiling exceeded before provider call')
    return request

def _provider_response(client, request, response_path):
    started = time.perf_counter(); raw = ''; terminal = None; reasoning_events = 0
    with response_path.with_suffix('.events.jsonl').open('a') as events:
        for event in client.responses.create(**request):
            events.write(event.model_dump_json()+'\n'); events.flush()
            if event.type == 'response.output_text.delta':
                raw += event.delta
                sys.stdout.write('.'); sys.stdout.flush()
            elif event.type.startswith('response.reasoning'):
                reasoning_events += 1
                sys.stdout.write('r'); sys.stdout.flush()
            elif event.type in ('response.completed', 'response.incomplete', 'response.failed'):
                terminal = event.response
            else:
                sys.stdout.write(f'[{event.type}]'); sys.stdout.flush()
    if terminal is None:
        raise RuntimeError('provider omitted terminal response; batch stops without retry')
    response_path.write_text(terminal.model_dump_json(indent=2)+'\n')
    return raw, terminal, reasoning_events, time.perf_counter()-started

def live(root, preview, output, approved_digest, ascent=None):
    encoded = (preview/'plan.json').read_bytes()
    if approved_digest != digest(encoded):
        raise ValueError('new paid batch needs approval for this exact prepared plan')
    plan = json.loads(encoded)
    from .preview import producer_hashes, native_bindings, source_paths
    if ascent is None or any(digest(path.read_bytes()) != plan['modules'][name]
        for name, path in source_paths(root, ascent, plan['dependencyModules']).items()):
        raise ValueError('current Scheme source no longer matches frozen modules')
    if (producer_hashes() != plan['producerHashes'] or
        native_bindings(plan['dependencyModules']) != plan['nativeBindings'] or
        digest((root/'t/model-study/direct-understanding/prediction-score.ss').read_bytes()) != plan['scorerSha256'] or
        digest((root/'t/model-study/direct-understanding/source-closure.ss').read_bytes()) != plan['closureProbeSha256'] or
        digest((root/'t/model-study/direct-understanding/compute-loader.ss').read_bytes()) != plan['computeLoaderSha256'] or
        digest((root/'t/model-study/direct-understanding/prediction-core.ss').read_bytes()) != plan['predictionCoreSha256'] or
        digest((root/'t/model-study/direct-understanding/worker-loop.ss').read_bytes()) != plan['workerLoopSha256'] or
        digest(worker_source(root).encode()) != plan['workerScriptSha256'] or
        digest((preview/'native-worker.ss').read_bytes()) != plan['workerScriptSha256']):
        raise ValueError('producer/scorer/closure probe changed after preparation')
    for case in plan['cases']:
        if (digest((preview/f"{case['id']}.input.ss").read_bytes()) != case['inputSha256'] or
            digest((preview/'private'/f"{case['id']}.sexp").read_bytes()) != case['expectedSha256'] or
            digest((preview/f"{case['id']}.ss").read_bytes()) != case['nativeProgramSha256']):
            raise ValueError('prepared input or private oracle changed')
    from openai import OpenAI
    client = OpenAI(api_key=os.environ['DEEPSEEK_API_KEY'], base_url='https://api.deepseek.com',
                    max_retries=0, timeout=90)
    output.mkdir(parents=True, exist_ok=False)
    with (preview/'paid-batch-claim.json').open('x') as file:
        file.write(json.dumps({'planSha256': digest(encoded), 'output': str(output)})+'\n')
        file.flush(); os.fsync(file.fileno())
    initial = {}
    records = []
    worker = NativeStudyWorker(root, preview/'native-worker.ss', output/'native-worker.log')
    try:
        for index, item in enumerate(plan['order']):
            request = _request(plan, preview, item, initial)
            request_path = output/f'{index:02d}.request.json'
            request_path.write_text(json.dumps(request, ensure_ascii=False, indent=2)+'\n')
            attempt = dict(item, index=index, planSha256=digest(encoded),
                           requestSha256=digest(request_path.read_bytes()))
            with (output/'attempts.jsonl').open('a') as file:
                file.write(json.dumps(attempt)+'\n'); file.flush(); os.fsync(file.fileno())
            sys.stdout.write(f'MODEL START {index+1}/{plan['maxCalls']} {item["case"]} {item["arm"]}\n'); sys.stdout.flush()
            raw, terminal, reasoning_events, provider_seconds = _provider_response(
                client, request, output/f'{index:02d}.response.json')
            native_started = time.perf_counter()
            observation = score_candidate(root, preview/'private'/f"{item['case']}.sexp", raw,
                                          output/f'{index:02d}.guard', preview/f"{item['case']}.ss",
                                          normalize=True, worker=worker, case=item['case'])
            native_seconds = time.perf_counter()-native_started
            observation.update({'taskSha256': next(case['inputSha256'] for case in plan['cases']
                                                  if case['id'] == item['case']),
                                'sourceHeads': {'poo': plan['pooHead'], 'ascent': plan['ascentHead']}})
            record = dict(attempt, raw=raw, observation=observation,
                          responseId=terminal.id, responseStatus=terminal.status,
                          usage=terminal.usage.model_dump() if terminal.usage else None,
                          reasoningEvents=reasoning_events, providerSeconds=provider_seconds,
                          nativeSeconds=native_seconds, providerAndGuardSeconds=provider_seconds+native_seconds)
            with (output/'calls.jsonl').open('a') as file:
                file.write(json.dumps(record)+'\n'); file.flush(); os.fsync(file.fileno())
            records.append(record)
            if item['arm'] == 'initial-high':
                initial[item['family']] = record
            sys.stdout.write(f' DONE correct={observation["correct"]} status={terminal.status}\n'); sys.stdout.flush()
    finally:
        worker.close()
    _report(encoded, records, output)


def _report(encoded, records, output):
    if len({row['responseId'] for row in records}) != len(records):
        raise RuntimeError('duplicate response IDs')
    report = {'planSha256': digest(encoded), 'completedCalls': len(records), 'retries': 0,
              'scope': 'direct Scheme prediction and native-feedback transfer; not code generation or weight training'}
    for arm in ('initial-none', 'initial-high', 'transfer-fresh', 'transfer-history', 'transfer-feedback'):
        rows = [row for row in records if row['arm'] == arm]
        report[arm] = {'attempts': len(rows),
                      'completed': sum(row['responseStatus'] == 'completed' for row in rows),
                      'readable': sum(row['observation']['readable'] for row in rows),
                      'correct': sum(row['observation']['correct'] and row['responseStatus'] == 'completed'
                                     for row in rows)}
        report[arm]['providerMedianSeconds'] = statistics.median(row['providerSeconds'] for row in rows)
        report[arm]['providerAndGuardMedianSeconds'] = statistics.median(row['providerAndGuardSeconds'] for row in rows)
        if all(row['usage'] for row in rows):
            inputs = sum(row['usage']['input_tokens'] for row in rows)
            outputs = sum(row['usage']['output_tokens'] for row in rows)
            reasoning = [(row['usage'].get('output_tokens_details') or {}).get('reasoning_tokens') for row in rows]
            report[arm].update(inputTokens=inputs, outputTokens=outputs,
                estimatedUsdAtPeakCeiling=(inputs*.3+outputs*1.2)/1_000_000,
                reasoningTokens=sum(reasoning) if all(value is not None for value in reasoning) else None)
        else:
            report[arm]['usageAvailability'] = 'incomplete; cost unknown'
    report['teachingContrast'] = {'scope': 'native feedback versus identical initial task/answer history',
        'accuracyCountDifference': report['transfer-feedback']['correct']-report['transfer-history']['correct'],
        'attemptsPerCondition': report['transfer-history']['attempts']}
    (output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    sys.stdout.write(f'STUDY-OK {len(records)} calls; bounded six-family pilot\n'); sys.stdout.flush()
