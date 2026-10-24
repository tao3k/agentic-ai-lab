# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Movie-study byte preparation and offline dispatch; Scheme owns all semantics.

Small mechanism pilot only; complex capability evaluation is a separate study.
Scheme owns gold construction and grading; Python records provider byte IO.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import shlex
import re
import shutil
from agentic_ai_lab_runtime.reasoning import rows_equal

ROOT = Path(os.environ.get('ASCENT_REPOSITORY', Path.cwd())).resolve()
SCHEME_ENTRY = 't/qualification/ascent-movie-cast-test.ss'
PRODUCERS = [SCHEME_ENTRY, 'applications/movie-cast-query.ss',
             't/qualification/fixtures/movie-cast/source.json',
             'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/movie_study.py',
             'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/model_study.py']
MAX_INPUT_BYTES = 32768
MAX_OUTPUT_TOKENS = int(os.environ.get('ASCENT_MODEL_MAX_OUTPUT_TOKENS', '65536'))
if MAX_OUTPUT_TOKENS <= 0: raise ValueError('ASCENT_MODEL_MAX_OUTPUT_TOKENS must be positive')


def provider_fatal(response):
    terminal = response.get('terminal') or {}
    return (response.get('error') is not None or terminal.get('error') is not None
            or terminal.get('status') not in ('completed', 'incomplete'))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def provider_key():
    if os.environ.get('DEEPSEEK_API_KEY'):
        return os.environ['DEEPSEEK_API_KEY']
    path = ROOT/'.env'
    if path.is_file():
        for line in path.read_text().splitlines():
            text = line.strip()
            if text.startswith('export '): text = text[7:].lstrip()
            if text.split('=', 1)[0].strip() != 'DEEPSEEK_API_KEY': continue
            parts = shlex.split(text.split('=', 1)[1].strip(), comments=True)
            if len(parts) != 1 or not parts[0]:
                raise ValueError('invalid DEEPSEEK_API_KEY assignment in .env')
            return parts[0]
    raise ValueError('DEEPSEEK_API_KEY is not configured')


def identities():
    paths = {path: ROOT/path for path in PRODUCERS}
    for directory in ('core', 'table', 'program', 'applications'):
        for source in (ROOT/directory).glob('*.ss'):
            paths[str(source.relative_to(ROOT))] = source
        for artifact in (ROOT/'.gerbil/lib/gerbil-ascent'/directory).glob('*'):
            if artifact.is_file() and (re.fullmatch(r'\.o\d*', artifact.suffix)
                                      or artifact.suffix in ('.ssi', '.scm')
                                      or artifact.name.endswith('.ssxi.ss')):
                paths[str(artifact.relative_to(ROOT))] = artifact
    return {path: digest(file.read_bytes()) for path, file in paths.items()}


def scheme(*arguments):
    env = os.environ.copy()
    env['GERBIL_LOADPATH'] = str(ROOT/'.gerbil/lib') + (':' + env['GERBIL_LOADPATH'] if env.get('GERBIL_LOADPATH') else '')
    env['GERBIL_PATH'] = str(ROOT/'.gerbil')
    env.pop('DEEPSEEK_API_KEY', None)
    invocation = '(begin (import :gerbil-ascent/t/qualification/ascent-movie-cast-test) (main '+ ' '.join(json.dumps(str(arg), ensure_ascii=False) for arg in arguments)+') (exit 0))'
    # Report actual completed compiler imports while the scheme root expands.
    code = '''(import :gerbil/expander)
(let ((loader (current-expander-module-import)) (count 0))
 (parameterize ((current-expander-module-import
  (lambda (path reload?)
   (let (context (loader path reload?))
    (when context (set! count (+ count 1))
     (when (zero? (modulo count 8)) (displayln "MOVIE-IMPORTS " count " " (expander-context-id context)) (force-output))) context))))
  (eval '\n'''+invocation+')))'
    command = [sys.executable, '-m', 'agentic_ai_lab_testing.assessment_studies.supervision', '--',
               'timeout', '120s', 'gxi', '-:max-heap=2G,debug=q', '-e',
               code]
    subprocess.run(command, cwd=ROOT, env=env, check=True)


def request_for(source, case, arm):
    # Explicit declared family reuse. No automatic NL intent equivalence claim.
    public = {k: case[k] for k in ('template', 'left', 'right', 'blocked')}
    if arm == 'baseline':
        context = {'finiteSource': source, 'question': public}
        instruction = 'Using only the supplied finite P161 cast facts, answer the question. Return only a JSON array of actor QIDs; no prose. Missing claims mean absent only in this finite extract.'
    elif arm == 'scheme-contract':
        # Intent compilation does not require actor enumeration. The engine
        # retains the actual facts; this hash binds identity, not correctness.
        context = {'question':public,
                   'sourceIdentity':digest(json.dumps(source,ensure_ascii=False,sort_keys=True).encode()),
                   'executor':{'castColumns':['Film','Actor'],
                               'bindings':{'left':'Film','right':'Film','blocked':'Actor'},
                               'operators':['union','intersection','branch-scoped exclusion']}}
        instruction = ('Compile the declared question template, not its answer. Return only a JSON object with exactly two fields: '
                       '"combine": "any" (OR) or "all" (AND), and "exclude_scope": "none", "left", or "both". '
                       'The scheme engine will substitute movie/actor bindings and preserve typed evidence before projection. No prose.')
    else:
        raise ValueError('unknown movie study arm')
    task = json.dumps(context, ensure_ascii=False, sort_keys=True)
    request = {'model': 'deepseek-flash', 'input': [{'role': 'user', 'content': instruction+'\n'+task}],
               'reasoning': {'effort': 'high'}, 'max_output_tokens': MAX_OUTPUT_TOKENS, 'stream': True, 'store': False}
    if len(json.dumps(request, ensure_ascii=False).encode()) > MAX_INPUT_BYTES:
        raise ValueError('movie request exceeds frozen input bound')
    return request


def prepare(output):
    output.mkdir(parents=True, exist_ok=False)
    scheme('prepare', output/'scheme-scenario.json')
    scenario = json.loads((output/'scheme-scenario.json').read_text())
    private = output/'private'; private.mkdir()
    public_cases = []
    for case in scenario['cases']:
        # Gold contract and answers stay outside every provider request.
        public_cases.append({k: v for k, v in case.items() if k not in ('combine', 'exclude_scope', 'expected')})
        (private/(case['id']+'.answer.json')).write_text(json.dumps(case['expected'])+'\n')
        (private/(case['family']+'.contract.json')).write_text(json.dumps({k: case[k] for k in ('combine', 'exclude_scope')})+'\n')
    order = []
    for index, case in enumerate(public_cases):
        scheduled = [('baseline', case['id'])]
        if case['id'].endswith('-seed'):
            scheduled.append(('scheme-contract', case['family']))
        if index % 2:
            scheduled.reverse()
        for arm, identity in scheduled:
            request = request_for(scenario['source'], case, arm)
            data = (json.dumps(request, ensure_ascii=False, sort_keys=True)+'\n').encode()
            name = identity+'.'+arm+'.request.json'; (output/name).write_bytes(data)
            order.append({'arm': arm, 'id': identity, 'request': name, 'sha256': digest(data), 'inputBytes': len(data)})
    plan = {'schema': 'ascent.movie-cast-plan.v1', 'sourceHead': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            'producerHashes': identities(), 'model': 'deepseek-flash', 'cases': public_cases, 'order': order,
            'scheduledBaselineCalls': 6, 'scheduledContractCalls': 3, 'retries': 0, 'maxInputBytes': MAX_INPUT_BYTES,
            'maxOutputTokens': MAX_OUTPUT_TOKENS, 'providerCallsExecuted': 0, 'liveAuthorized': False,
            'candidateBudgetCeilingUsd': 1, 'priceSource': 'https://api-docs.deepseek.com/quick_start/pricing/',
            'conservativeScheduledUpperUsd': sum((item['inputBytes']+1024)*.3+MAX_OUTPUT_TOKENS*1.2 for item in order)/1_000_000,
            'purpose': 'mechanism-regression', 'capabilityEvaluationEligible': False,
            'primaryMetric': 'Scheme contract admission, scoped evidence and binding substitution only; six questions cannot establish model reasoning ability or economic benefit',
            'reuseBoundary': 'Caller-declared identical template only; hashes bind source, implementation, schema and prompt bytes; answers recomputed from current bindings, not reused',
            'target': 'No capability or savings target for this regression; the 6:3 call schedule is constructed, not an experimental cost result'}
    (output/'plan.json').write_text(json.dumps(plan, indent=2)+'\n')
    print('MOVIE-STUDY-PREPARED cases=6 scheduledCalls=9 executedCalls=0', flush=True)


def validate(preview):
    plan = json.loads((preview/'plan.json').read_text())
    if plan['producerHashes'] != identities():
        raise ValueError('movie source/implementation changed: prepare a new plan')
    for item in plan['order']:
        if digest((preview/item['request']).read_bytes()) != item['sha256']:
            raise ValueError('movie prompt changed')
    return plan


def offline(preview, output):
    plan = validate(preview)
    output.mkdir(parents=True, exist_ok=False)
    observations = []; commands = []
    for item in plan['order']:
        mode = 'baseline' if item['arm'] == 'baseline' else 'family'
        kind = 'answer' if mode == 'baseline' else 'contract'
        destination = output/(item['id']+'.'+item['arm']+'.json')
        commands.append([mode, item['id'], str(preview/'private'/(item['id']+'.'+kind+'.json')), str(destination)])
    batch = output/'commands.json'; batch.write_text(json.dumps(commands)+'\n')
    scheme('batch', batch)
    for item in plan['order']:
        destination = output/(item['id']+'.'+item['arm']+'.json')
        value = json.loads(destination.read_text())
        observations.append({'arm': item['arm'], 'id': item['id'], 'scheme': value})
    result = {'schema': 'ascent.movie-cast-offline.v1', 'sourceHead': plan['sourceHead'],
              'providerCalls': 0, 'controlOrigin': 'Scheme gold fixture; not model predictions', 'observations': observations,
              'observedTokenSavings': None, 'observedCostSavings': None, 'observedModelAccuracy': None,
              'engineControlsCorrect': all(row['correct'] for item in observations for row in (item['scheme'] if isinstance(item['scheme'], list) else [item['scheme']]))}
    (output/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    if not result['engineControlsCorrect']:
        raise RuntimeError('scheme offline control failed; result retained')
    print('MOVIE-STUDY-OFFLINE-OK controls=9 providerCalls=0', flush=True)


def live(preview, output):
    from .model_study import provider
    plan = validate(preview)
    if plan.get('purpose') != 'mechanism-regression' or plan.get('capabilityEvaluationEligible') is not False:
        raise ValueError('expected frozen mechanism regression plan')
    bound = sum((len((preview/item['request']).read_bytes())+1024)*.3+plan['maxOutputTokens']*1.2
                for item in plan['order'])/1_000_000
    if len(plan['order']) != 9 or bound > 1:
        raise ValueError('pilot exceeds nine-call / one-dollar bound')
    key = provider_key()
    output.mkdir(parents=True, exist_ok=False)
    with (preview/'paid-batch-claim.json').open('x') as claim:
        claim.write(json.dumps({'planSha256': digest((preview/'plan.json').read_bytes()),
                                'output': str(output), 'maxCalls': 9, 'budgetCeilingUsd': 1})+'\n')
        claim.flush(); os.fsync(claim.fileno())
    records = []; commands = []; started = time.monotonic()
    try:
        for index, item in enumerate(plan['order']):
            validate(preview)
            request = json.loads((preview/item['request']).read_text())
            if request.get('model') != 'deepseek-flash' or request.get('max_output_tokens') != plan['maxOutputTokens']:
                raise ValueError('provider request limits changed')
            directory = output/f'{index:02d}'; directory.mkdir()
            (directory/'request.json').write_text(json.dumps(request)+'\n')
            print(f'MOVIE-CALL {index+1}/9 {item["arm"]} {item["id"]}', flush=True)
            raw, response = provider(request, key, directory/'response.json')
            raw_path = directory/'raw-output.txt'; raw_path.write_text(raw)
            terminal = response['terminal'] or {}
            record = {**item, 'providerCompleted': terminal.get('status') == 'completed' and not provider_fatal(response),
                      'resolvedModel': terminal.get('model'), 'responseId': terminal.get('id'),
                      'usage': terminal.get('usage'), 'providerError': response['error'],
                      'providerSeconds': response['providerSeconds'], 'gradePath': str(directory/'grade.json')}
            records.append(record)
            with (output/'calls.jsonl').open('a') as ledger:
                ledger.write(json.dumps(record)+'\n'); ledger.flush(); os.fsync(ledger.fileno())
            mode = 'baseline' if item['arm'] == 'baseline' else 'family'
            commands.append([mode, item['id'], str(raw_path), record['gradePath']])
            print(f'\nMOVIE-RESPONSE complete={record["providerCompleted"]}', flush=True)
            if provider_fatal(response): break  # Capped answers remain scheduled failures.
        batch = output/'commands.json'; batch.write_text(json.dumps(commands)+'\n')
        scheme('batch', batch)
        for record in records:
            record['engineObservation'] = json.loads(Path(record['gradePath']).read_text())
    finally:
        result = {'purpose': 'mechanism-regression', 'capabilityEvaluationEligible': False,
                  'scheduledCalls': 9, 'executedCalls': len(records), 'budgetCeilingUsd': 1,
                  'seconds': time.monotonic()-started, 'records': records,
                  'capabilityConclusion': None, 'costSavingsConclusion': None}
        (output/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    print('MOVIE-LIVE-PILOT-RECORDED', flush=True)


def continuation_plan(preview, output, frozen_root):
    """Bind preserved producers and the exact paid prefix before resuming."""
    plan = json.loads((preview/'plan.json').read_text())
    for path, expected in plan['producerHashes'].items():
        if digest((frozen_root/path).read_bytes()) != expected:
            raise ValueError('frozen producer mismatch: '+path)
    for item in plan['order']:
        data = (preview/item['request']).read_bytes()
        request = json.loads(data)
        if digest(data) != item['sha256'] or len(data) > MAX_INPUT_BYTES:
            raise ValueError('frozen request mismatch')
        if request['model'] != 'deepseek-flash' or request['max_output_tokens'] != plan['maxOutputTokens']:
            raise ValueError('frozen request budget mismatch')
    if (plan['purpose'] != 'mechanism-regression' or plan['capabilityEvaluationEligible']
            or len(plan['order']) != 9 or plan['retries'] != 0
            or plan['conservativeScheduledUpperUsd'] > 1):
        raise ValueError('unexpected pilot budget or scope')
    records = [json.loads(line) for line in (output/'calls.jsonl').read_text().splitlines()]
    if not 0 < len(records) < 9: raise ValueError('expected an unfinished paid prefix')
    for index, record in enumerate(records):
        if any(record[key] != plan['order'][index][key] for key in ('id', 'arm', 'sha256')):
            raise ValueError('paid prefix does not match frozen order')
    return plan, records


def ffi_grade(engine, wire, preview, plan, item, raw):
    """Protocol adaptation only; Scheme executes and compares answers."""
    cases = [c for c in plan['cases'] if (c['id'] == item['id'] if item['arm'] == 'baseline'
                                        else c['family'] == item['id'])]
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result: raise ValueError('duplicate prediction key')
            result[key] = value
        return result
    try:
        value = json.loads(raw, object_pairs_hook=pairs)
        if item['arm'] == 'baseline':
            if not isinstance(value, list) or not all(isinstance(x, str) for x in value):
                raise ValueError('expected actor array')
            expected = json.loads((preview/'private'/(item['id']+'.answer.json')).read_text())
            return [{'id':item['id'], 'correct':rows_equal([[x] for x in value], [[x] for x in expected])}]
        if (not isinstance(value, dict) or set(value) != {'combine','exclude_scope'}
                or value['combine'] not in ('any','all') or value['exclude_scope'] not in ('none','left','both')):
            raise ValueError('expected finite query contract')
        key = cases[0]['id']+':'+value['combine']+':'+value['exclude_scope']
        observations = []
        with engine.open(wire[key]) as session:
            for index, case in enumerate(cases):
                if index:
                    session.replace([{'relation':relation,'rows':[[case[field]]]}
                                     for relation,field in (('left_film','left'),('right_film','right'),('blocked_actor','blocked'))])
                result = session.run()
                expected = json.loads((preview/'private'/(case['id']+'.answer.json')).read_text())
                equal = rows_equal(result['relations']['actor_answer'], [[x] for x in expected])
                observations.append({'id':case['id'],'correct':bool(result['complete'] and equal),
                                     'scheme':result})
            return observations
    except (ValueError, TypeError, KeyError) as error:
        return [{'id':case['id'], 'correct':False, 'protocolError':str(error)} for case in cases]


def continue_ffi(preview, output, frozen_root, library, wire_path):
    from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
    from .model_study import provider
    plan, records = continuation_plan(preview, output, frozen_root)
    key = provider_key()
    # Exclusive claim: interrupted paid continuations require explicit audit,
    # never automatic retries or replay of already charged requests.
    cut = output/'ffi-cut'; cut.mkdir(exist_ok=False)
    copied = cut/library.name; shutil.copyfile(library, copied)
    shutil.copyfile(library.with_suffix(library.suffix+'.json'), cut/'build.json')
    shutil.copyfile(wire_path, cut/'wire.json')
    (cut/'transition.json').write_text(json.dumps({
        'schema':'ascent.movie-backend-transition.v1','paidPrefix':len(records),
        'planSha256':digest((preview/'plan.json').read_bytes()),
        'previousBackend':'frozen temporary Scheme AOT scorer',
        'currentBackend':'general Scheme C ABI via Python CFFI',
        'librarySha256':digest(copied.read_bytes()),'wireSha256':digest((cut/'wire.json').read_bytes()),
        'driverSha256':digest(Path(__file__).read_bytes()),
        'bindingSha256':digest((ROOT/'rust/ascent-python/src/api/exports.rs').read_bytes()),
        'maxTotalCalls':9,'retries':0,'budgetCeilingUsd':1},indent=2)+'\n')
    wire = json.loads((cut/'wire.json').read_text())
    started = time.monotonic()
    try:
        with ReasoningRuntime(copied) as engine:
            for index, record in enumerate(records):
                old = json.loads(Path(record['gradePath']).read_text())
                old = old if isinstance(old,list) else [old]
                grade = ffi_grade(engine,wire,preview,plan,record,(output/f'{index:02d}'/'raw-output.txt').read_text())
                if [r['correct'] for r in old] != [r['correct'] for r in grade]:
                    raise ValueError('previous AOT/CFFI grading disagreement')
                record['ffiObservation'] = grade
            for index in range(len(records),len(plan['order'])):
                item = plan['order'][index]; directory = output/f'{index:02d}';directory.mkdir()
                data = (preview/item['request']).read_bytes()
                if digest(data) != item['sha256']: raise ValueError('request changed during continuation')
                (directory/'request.json').write_bytes(data)
                print(f'MOVIE-CFFI-CALL {index+1}/9 {item["arm"]} {item["id"]}',flush=True)
                raw,response = provider(json.loads(data),key,directory/'response.json')
                (directory/'raw-output.txt').write_text(raw)
                terminal = response['terminal'] or {}
                record = {**item,'providerCompleted':terminal.get('status') == 'completed' and not provider_fatal(response),
                          'providerStatus':terminal.get('status'),'incompleteDetails':terminal.get('incomplete_details'),
                          'resolvedModel':terminal.get('model'),'responseId':terminal.get('id'),
                          'usage':terminal.get('usage'),'providerError':response['error'],
                          'providerSeconds':response['providerSeconds'],'gradePath':str(directory/'grade.json')}
                records.append(record)
                with (output/'calls.jsonl').open('a') as ledger:
                    ledger.write(json.dumps(record)+'\n');ledger.flush();os.fsync(ledger.fileno())
                grade = ffi_grade(engine,wire,preview,plan,item,raw)
                (directory/'grade.json').write_text(json.dumps(grade,indent=2)+'\n')
                record['ffiObservation'] = grade
                print(f'\nMOVIE-CFFI-GRADE completed={record["providerCompleted"]} correct={[x["correct"] for x in grade]}',flush=True)
                if provider_fatal(response): break
    finally:
        (output/'ffi-result.json').write_text(json.dumps({'purpose':'mechanism-regression',
            'capabilityEvaluationEligible':False,'scheduledCalls':9,'executedCalls':len(records),
            'continuationSeconds':time.monotonic()-started,'records':records,
            'capabilityConclusion':None,'costSavingsConclusion':None},indent=2)+'\n')


def reflect(preview, pilot, output, wire_path, library):
    """Two separately recorded diagnostic calls; never rewrite original scores."""
    from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
    from .model_study import provider, response_outcome
    plan = json.loads((preview/'plan.json').read_text())
    original = json.loads((pilot/'ffi-result.json').read_text())
    if original['executedCalls'] != 9: raise ValueError('expected completed original pilot')
    item = plan['order'][2]
    data = (preview/item['request']).read_bytes()
    if digest(data) != item['sha256']: raise ValueError('original request changed')
    response = json.loads((pilot/'02/response.json').read_text())
    if response_outcome(response) != 'output_budget_exhausted':
        raise ValueError('expected observed output-budget failure')
    original_request = json.loads(data)
    case = next(c for c in plan['cases'] if c['id'] == item['id'])
    observations = {k:response['terminal'].get(k) for k in
                    ('status','error','incomplete_details','max_output_tokens','usage')}
    reflection_request = {**original_request, 'max_output_tokens':MAX_OUTPUT_TOKENS, 'input':[{'role':'user','content':
        'Review the observable failure below. There was no visible answer, so do not invent a semantic mistake or blame account credits. '
        'Give concise evidence-based diagnosis, not internal chain-of-thought. Do not enumerate actors. '
        'The Scheme executor supports typed Film/Actor relations, branch-scoped exclusion, union/intersection, '
        'deduplication and source-backed evidence; it retains source data and replaces bindings. '
        'Return a JSON object with exactly diagnosis (string), hypotheses (array of strings), '
        'optimizations (array of strings), execution_contract (object with combine:any|all and exclude_scope:none|left|both). '
        'Derive the contract from the question, not from an answer oracle.\n'+
        json.dumps({'observableFailure':observations,'originalTask':original_request['input']},ensure_ascii=False)}],
        'text':{'format':{'type':'json_object'}}}
    optimized_request = {**original_request,'max_output_tokens':MAX_OUTPUT_TOKENS,'input':[{'role':'user','content':
        original_request['input'][0]['content']+'\nExecution discipline: treat the finite facts as sets. '
        'Filter each branch with only its declared exclusion, combine the branches, and deduplicate once. '
        'Do not speculate about outside facts or enumerate alternative interpretations. Return the final actor array.'}]}
    requests = [reflection_request,optimized_request]
    if any(len(json.dumps(r).encode()) > MAX_INPUT_BYTES for r in requests): raise ValueError('diagnostic input bound')
    ceiling=sum((len(json.dumps(r).encode())+1024)*.3+plan['maxOutputTokens']*1.2 for r in requests)/1_000_000
    if ceiling+plan['conservativeScheduledUpperUsd'] > 1: raise ValueError('diagnostic cost bound')
    key = provider_key();output.mkdir(parents=True,exist_ok=False)
    copied=output/library.name;shutil.copyfile(library,copied)
    shutil.copyfile(wire_path,output/'wire.json')
    for index,request in enumerate(requests):
        (output/f'{index:02d}.request.json').write_text(json.dumps(request,sort_keys=True)+'\n')
    receipt={'schema':'ascent.movie-failure-reflection.v1','purpose':'adaptive diagnostic, not independent benchmark',
             'originalCalls':9,'maxAdditionalCalls':2,'retries':0,'maxOutputTokens':MAX_OUTPUT_TOKENS,
             'originalOutcome':response_outcome(response),'originalRequestSha256':digest(data),
             'librarySha256':digest(copied.read_bytes()),'wireSha256':digest((output/'wire.json').read_bytes()),
             'driverSha256':digest(Path(__file__).read_bytes()),'originalScoresChanged':False,
             'additionalCalls':[],'recovery':None,'costSavingsConclusion':None}
    (output/'plan.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def call(index):
        request=json.loads((output/f'{index:02d}.request.json').read_text())
        print(f'MOVIE-DIAGNOSTIC-CALL {index+1}/2',flush=True)
        raw,meta=provider(request,key,output/f'{index:02d}.response.json')
        (output/f'{index:02d}.raw.txt').write_text(raw)
        terminal=meta['terminal'] or {}
        record={'requestSha256':digest((output/f'{index:02d}.request.json').read_bytes()),
                'outcome':response_outcome(meta),'status':terminal.get('status'),'usage':terminal.get('usage'),
                'incompleteDetails':terminal.get('incomplete_details'),'providerSeconds':meta['providerSeconds']}
        receipt['additionalCalls'].append(record)
        (output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
        return raw,meta,record
    try:
        raw,meta,record=call(0)
        if response_outcome(meta) != 'completed_ungraded': return
        reflection=json.loads(raw)
        if not isinstance(reflection,dict) or set(reflection) != {'diagnosis','hypotheses','optimizations','execution_contract'}:
            raise ValueError('invalid reflection shape')
        receipt['reflection']=reflection
        wire=json.loads((output/'wire.json').read_text())
        with ReasoningRuntime(copied) as engine:
            recovery=ffi_grade(engine,wire,preview,plan,{'arm':'scheme-contract','id':case['family']},
                               json.dumps(reflection['execution_contract']))
            receipt['recovery']=recovery
            print('\nMODEL-REFLECTION-CONTRACT', [g['correct'] for g in recovery],flush=True)
            raw,meta,record=call(1)
            grade=ffi_grade(engine,wire,preview,plan,item,raw)
            receipt['optimizedDirectGrade']=grade
            record['outcome']=response_outcome(meta,all(g['correct'] for g in grade))
            print('\nMODEL-DIAGNOSTIC-DIRECT',record['outcome'],flush=True)
    finally:
        (output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')


def budget_control(preview, pilot, output, wire_path, library):
    """Matched control: change only the output ceiling, keep original failure."""
    from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
    from .model_study import provider, response_outcome
    plan=json.loads((preview/'plan.json').read_text());item=plan['order'][2]
    original=(preview/item['request']).read_bytes()
    if digest(original) != item['sha256']: raise ValueError('original prompt changed')
    request=json.loads(original);before=dict(request)
    if MAX_OUTPUT_TOKENS <= request['max_output_tokens']: raise ValueError('expected increased output ceiling')
    request['max_output_tokens']=MAX_OUTPUT_TOKENS
    if {k:v for k,v in request.items() if k != 'max_output_tokens'} != {k:v for k,v in before.items() if k != 'max_output_tokens'}:
        raise ValueError('matched control changed context')
    key=provider_key();output.mkdir(parents=True,exist_ok=False)
    copied=output/library.name;shutil.copyfile(library,copied)
    shutil.copyfile(wire_path,output/'wire.json')
    (output/'request.json').write_text(json.dumps(request,sort_keys=True)+'\n')
    receipt={'schema':'ascent.movie-output-budget-control.v1','purpose':'adaptive single-case diagnostic',
             'changedFields':['max_output_tokens'],'previousMaxOutputTokens':before['max_output_tokens'],
             'maxOutputTokens':request['max_output_tokens'],'maxCalls':1,'retries':0,
             'originalRequestSha256':digest(original),'originalScoresChanged':False,
             'librarySha256':digest(copied.read_bytes()),'wireSha256':digest((output/'wire.json').read_bytes())}
    (output/'plan.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('OUTPUT-BUDGET-CONTROL',before['max_output_tokens'],'->',request['max_output_tokens'],flush=True)
    raw,meta=provider(request,key,output/'response.json');(output/'raw-output.txt').write_text(raw)
    with ReasoningRuntime(copied) as engine:
        grade=ffi_grade(engine,json.loads((output/'wire.json').read_text()),preview,plan,item,raw)
    terminal=meta['terminal'] or {}
    receipt.update(outcome=response_outcome(meta,all(g['correct'] for g in grade)),grade=grade,
                   usage=terminal.get('usage'),providerSeconds=meta['providerSeconds'],
                   status=terminal.get('status'),incompleteDetails=terminal.get('incomplete_details'))
    (output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('\nOUTPUT-BUDGET-CONTROL-RESULT',receipt['outcome'],flush=True)


def main():
    parser = argparse.ArgumentParser()
    modes = parser.add_subparsers(dest='mode', required=True)
    p = modes.add_parser('prepare'); p.add_argument('output', type=Path)
    p = modes.add_parser('offline'); p.add_argument('preview', type=Path); p.add_argument('output', type=Path)
    p = modes.add_parser('live'); p.add_argument('preview', type=Path); p.add_argument('output', type=Path)
    p = modes.add_parser('continue-ffi')
    for field in ('preview','output','frozen_root','library','wire'): p.add_argument(field,type=Path)
    p = modes.add_parser('reflect')
    for field in ('preview','pilot','output','wire','library'): p.add_argument(field,type=Path)
    p = modes.add_parser('budget-control')
    for field in ('preview','pilot','output','wire','library'): p.add_argument(field,type=Path)
    args = parser.parse_args()
    if args.mode == 'prepare': prepare(args.output.resolve())
    elif args.mode == 'offline': offline(args.preview.resolve(), args.output.resolve())
    elif args.mode == 'live': live(args.preview.resolve(), args.output.resolve())
    elif args.mode == 'continue-ffi': continue_ffi(*(getattr(args,field).resolve() for field in ('preview','output','frozen_root','library','wire')))
    elif args.mode == 'reflect': reflect(*(getattr(args,field).resolve() for field in ('preview','pilot','output','wire','library')))
    else: budget_control(*(getattr(args,field).resolve() for field in ('preview','pilot','output','wire','library')))


if __name__ == '__main__':
    main()
