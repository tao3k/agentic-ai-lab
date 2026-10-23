#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Frozen provider byte IO; Scheme owns task construction, truth and scoring."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import http.client
import statistics
import shutil

ROOT = Path(os.environ.get('ASCENT_REPOSITORY', Path.cwd())).resolve()
BINARY = ROOT / '.cache/ascent/compiled-library/dsl-closure'
HARNESS = [sys.executable, '-m', 'agentic_ai_lab_testing.assessment_studies.supervision', '--', 'timeout', '120s']
RUNTIME = [str(BINARY), '-:max-heap=1G,debug=q']
PRICE_URL = 'https://api-docs.deepseek.com/quick_start/pricing/'
MAX_INPUT_BYTES = 655360
MAX_OUTPUT_TOKENS = 8192
MAX_CALLS = 60
BUDGET_USD = 13
FRAME_TOKEN_PADDING = 1024
PROVIDER_IDLE_SECONDS = 45


def response_outcome(response, correct=None):
    """Classify observable completion separately from answer correctness."""
    if response.get('error') is not None: return 'transport_error'
    terminal = response.get('terminal') or {}
    if terminal.get('error') is not None or terminal.get('status') == 'failed':
        return 'provider_failure'
    if terminal.get('status') == 'incomplete':
        details = terminal.get('incomplete_details') or {}
        return 'output_budget_exhausted' if details.get('reason') == 'max_output_tokens' else 'incomplete'
    if terminal.get('status') != 'completed': return 'missing_terminal'
    if correct is None: return 'completed_ungraded'
    return 'correct' if correct else 'answer_mismatch'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def producer_hashes():
    from . import supervision
    paths = {'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/model_study.py': Path(__file__),
             'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/supervision.py': Path(supervision.__file__),
             't/model/response-projection.ss': ROOT/'t/model/response-projection.ss',
             't/model/source-closure.ss': ROOT/'t/model/source-closure.ss'}
    return {name: digest(path.read_bytes()) for name, path in paths.items()}


def module_path(name):
    if name.startswith('gerbil-ascent/'):
        return ROOT/(name.split('/',1)[1]+'.ss')
    if name in ('yuanxu/types.ssi','yuanxu/types.scm','yuanxu/types~0.scm'):
        return ROOT/'.data/dependencies/prefix/lib'/name
    raise ValueError('unrecognized source binding')


def native(command, log):
    with log.open('w') as output:
        process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, bufsize=1)
        for line in process.stdout:
            output.write(line); output.flush()
            sys.stdout.write(line); sys.stdout.flush()
        status = process.wait()
    text = log.read_text()
    markers = ('MODULE-OK', 'HARNESS-OK', '\nOK\n')
    errors = ('ERROR CASE', 'ERROR CHECK', 'ERROR HARNESS', 'ERROR MODULE', 'Heap overflow', 'Stack overflow')
    if status or not all(marker in text for marker in markers) or any(error in text for error in errors):
        raise RuntimeError(f'native gate failed with status {status}: {log}')
    return text


def source_environment():
    env = os.environ.copy()
    existing = env.get('GERBIL_LOADPATH', '')
    # Native executables do not inherit gxi's standard-library initialization.
    # Locate the installed SDK through the actual launcher, never a guessed ABI.
    launcher = shutil.which('gxi')
    if launcher is None:
        raise ValueError('installed Gerbil launcher is unavailable')
    sdk = Path(launcher).resolve().parent.parent
    if not (sdk/'lib/gerbil/core.ssi').is_file():
        raise ValueError('installed Gerbil standard-library interface is unavailable')
    env['GERBIL_HOME'] = str(sdk)
    env['GERBIL_LOADPATH'] = str(ROOT/'.cache/ascent/compiled-library/lib') + (':'+existing if existing else '') + ':' + str(sdk/'lib')
    return env


def source_closure(imports, log):
    command = HARNESS + RUNTIME + ['--source-closure', *imports]
    with log.open('w') as output:
        process = subprocess.Popen(command, cwd=ROOT, env=source_environment(), stdin=subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        for line in process.stdout:
            output.write(line); output.flush(); sys.stdout.write(line); sys.stdout.flush()
        status = process.wait()
    text = log.read_text()
    if status or not all(marker in text for marker in ('MODULE-OK', 'HARNESS-OK', '\nOK\n')):
        raise RuntimeError('compiler source closure failed')
    records = [json.loads(line.removeprefix('SOURCE-CLOSURE '))
               for line in text.splitlines() if line.startswith('SOURCE-CLOSURE ')]
    if {record['root'] for record in records} != set(imports):
        raise ValueError('compiler omitted an import root')
    return {record['root']: record['modules'] for record in records}


def probe(output):
    subprocess.run(['gxi', str(ROOT/'t/harness/artifact-admission.ss'), 'check'], cwd=ROOT, check=True)
    output.mkdir(parents=True, exist_ok=False)
    text = native(HARNESS + RUNTIME + ['t/qualification/scheme-model-closure-test.ss'], output/'preflight.native.log')
    cases = [json.loads(line.removeprefix('STUDY-CASE ')) for line in text.splitlines() if line.startswith('STUDY-CASE ')]
    if len(cases) != 24 or len({case['id'] for case in cases}) != 24:
        raise ValueError('expected 24 unique independent native truths')
    imports = sorted({name for case in cases for name in case['imports']})
    closures = source_closure(imports, output/'source-closure.native.log')
    return cases, closures


def prepare(output):
    cases, closures = probe(output)
    modules = {}
    families = list(dict.fromkeys(case['family'] for case in cases))
    if len(families) != 12:
        raise ValueError('expected twelve independent families')
    manifest = {'schema': 'ascent.model-closure-study-plan', 'version': 1,
                'model': 'deepseek-flash', 'baseUrl': 'https://api.deepseek.com',
                'sourceHead': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'maxCalls': MAX_CALLS, 'retries': 0, 'maxInputBytes': MAX_INPUT_BYTES,
                'maxOutputTokens': MAX_OUTPUT_TOKENS, 'budgetCeilingUsd': BUDGET_USD,
                'requestReadTimeoutSeconds': PROVIDER_IDLE_SECONDS, 'requestWallDeadlineSeconds': None,
                'providerProgressContract': 'Actual response/reasoning/text events renew the idle deadline; keepalive lines do not; no absolute cutoff while computation progresses',
                'priceSource': PRICE_URL, 'peakInputUsdPerMillion': .3, 'peakOutputUsdPerMillion': 1.2,
                'framingTokenPadding': FRAME_TOKEN_PADDING,
                'conservativeMaximumUsd': MAX_CALLS * ((MAX_INPUT_BYTES+FRAME_TOKEN_PADDING)*.3 + MAX_OUTPUT_TOKENS*1.2)/1_000_000,
                'inputContract': 'actual compiler-derived module sources and exact compiled Scheme expression with missing expected datum; no system instructions, examples, semantic recipe, answer prefill, tools or repair',
                'feedbackContract': 'only actual initial output and post-response current native score/truth; no corrective instruction',
                'outputContract': 'raw retained; unique inert literal/quoted assertion normalization without oracle; ambiguity, EOF and executable leaves reject',
                'primaryMetric': 'completed provider response and correct native-scored normalized datum; all scheduled attempts remain in denominator',
                'sourceBinding': json.loads((ROOT/'.cache/ascent/compiled-library/dsl-closure.json').read_text()),
                'producerHashes': producer_hashes(), 'modules': modules, 'cases': [], 'order': [], 'families': families}
    private = output/'private'; private.mkdir()
    for case in cases:
        deps = sorted({module for root in case['imports'] for module in closures[root]})
        owned = [name for name in deps if name.startswith('gerbil-ascent/')]
        lowered = ['yuanxu/types.ssi','yuanxu/types.scm','yuanxu/types~0.scm'] if 'yuanxu/types' in deps else []
        assumed = [name for name in deps if name not in owned and name!='yuanxu/types']
        if not owned:
            raise ValueError('compiler source closure has no project modules')
        context = ''
        for name in owned+lowered:
            path = module_path(name)
            if not path.is_file():
                raise ValueError(f'project module has no source: {name}')
            data = path.read_bytes(); modules[name] = digest(data)
            context += f';;; file: {name+".ss" if name in owned else name}\n'+data.decode()+'\n'
        task = '(import :std/test '+ ' '.join(case['imports']) + ')\n'
        task += '(define result '+case['expression']+")\n(check-equal? result '?)\n"
        payload = context + task
        encoded = payload.encode()
        # Historical transfer adds only the new task, not a duplicated implementation.
        # Actual request serialization and prior output must still pass the frozen byte bound.
        if len(encoded) > MAX_INPUT_BYTES - 65536:
            raise ValueError(f'source/task leaves insufficient bounded history space: {case["id"]}')
        (output/f'{case["id"]}.input.ss').write_bytes(encoded)
        (output/f'{case["id"]}.task.ss').write_text(task)
        expected = (case['nativeDatum']+'\n').encode()
        if case['nativeDatum'] != case['independentDatum']:
            raise ValueError('native truth did not match independent frozen fixture')
        (private/f'{case["id"]}.sexp').write_bytes(expected)
        manifest['cases'].append({'id':case['id'], 'family':case['family'], 'variant':case['variant'],
                                 'imports':case['imports'], 'dependencyModules':owned, 'compilerLoweredDependencyFiles':lowered,
                                 'assumedFrameworkModules':assumed,
                                 'inputBytes':len(encoded), 'inputSha256':digest(encoded),
                                 'taskSha256':digest(task.encode()), 'expectedSha256':digest(expected)})
    controls=[('literal','2',True,True),('quote',"'2",True,True),
              ('assertion','(check-equal? result 2)',True,True),
              ('quoted-assertion',"(check-equal? result '2)",True,True),
              ('wrong','3',True,False),('executable','(check-equal? result (+ 1 1))',False,False),
              ('ambiguous','2 2',False,False),('reader-label','#0=(2 . #0#)',False,False),
              ('deep','('*65+'2'+')'*65,False,False),('oversize','2'*8193,False,False)]
    observations=[]
    for label,datum,readable,correct in controls:
        observed=native_score('higher-input-initial',datum,output/f'control-{label}')
        if observed['readable']!=readable or observed['correct']!=correct:
            raise ValueError(f'native transport control failed: {label}')
        observations.append({'control':label,**observed})
    (output/'transport-controls.json').write_text(json.dumps(observations,indent=2)+'\n')
    manifest['nativeTransportControls']=len(observations)
    for index, family in enumerate(families):
        initial = [('initial-none','none','initial'),('initial-high','high','initial')]
        transfer = [('transfer-fresh','high','transfer'),('transfer-history','high','transfer'),('transfer-feedback','high','transfer')]
        rotation=index%3; transfer=transfer[rotation:]+transfer[:rotation]
        if index%2: initial.reverse(); transfer.reverse()
        for arm, effort, variant in initial+transfer:
            manifest['order'].append({'family':family,'arm':arm,'reasoningEffort':effort,'case':f'{family}-{variant}'})
    encoded=json.dumps(manifest,sort_keys=True,separators=(',',':')).encode()
    (output/'plan.json').write_bytes(encoded)
    print(f'PREPARED {digest(encoded)} native=24 modelCalls=0 modules={len(modules)}',flush=True)


def validate(preview, approved):
    encoded=(preview/'plan.json').read_bytes()
    if digest(encoded)!=approved:
        raise ValueError('approval digest does not match frozen plan')
    plan=json.loads(encoded)
    if (plan['maxCalls']!=60 or plan['retries']!=0 or plan['budgetCeilingUsd']!=13 or
        plan['maxInputBytes']!=MAX_INPUT_BYTES or plan['maxOutputTokens']!=MAX_OUTPUT_TOKENS or
        plan['producerHashes']!=producer_hashes() or
        plan['requestReadTimeoutSeconds']!=PROVIDER_IDLE_SECONDS or
        plan['requestWallDeadlineSeconds'] is not None):
        raise ValueError('frozen producer/budget contract changed')
    subprocess.run(['gxi',str(ROOT/'t/harness/artifact-admission.ss'),'check'],cwd=ROOT,check=True)
    if plan['sourceBinding']!=json.loads((ROOT/'.cache/ascent/compiled-library/dsl-closure.json').read_text()):
        raise ValueError('native artifact changed after preparation')
    for name, sha in plan['modules'].items():
        if digest(module_path(name).read_bytes())!=sha:
            raise ValueError('module bytes changed after preparation')
    for case in plan['cases']:
        for path, sha in [(preview/f'{case["id"]}.input.ss',case['inputSha256']),
                          (preview/f'{case["id"]}.task.ss',case['taskSha256']),
                          (preview/'private'/f'{case["id"]}.sexp',case['expectedSha256'])]:
            if digest(path.read_bytes())!=sha:
                raise ValueError('frozen case bytes changed')
    if len(plan['order'])!=60 or len(plan['cases'])!=24:
        raise ValueError('frozen inventory changed')
    return plan


def request_for(plan, preview, item, initial):
    source=(preview/f'{item["case"]}.input.ss').read_text()
    inputs=[{'role':'user','content':source}]
    if item['arm'] in ('transfer-history','transfer-feedback'):
        previous=initial[item['family']]
        inputs=[{'role':'user','content':(preview/f'{item["family"]}-initial.input.ss').read_text()}]
        if previous['raw']:
            inputs.append({'role':'assistant','content':previous['raw']})
        feedback=json.dumps(previous['nativeObservation'],sort_keys=True)+'\n' if item['arm']=='transfer-feedback' else ''
        inputs.append({'role':'user','content':feedback+(preview/f'{item["case"]}.task.ss').read_text()})
    if len(json.dumps(inputs,ensure_ascii=False).encode())>plan['maxInputBytes']:
        raise ValueError('serialized input exceeds frozen byte ceiling before call')
    return {'model':plan['model'],'input':inputs,'reasoning':{'effort':item['reasoningEffort']},
            'max_output_tokens':plan['maxOutputTokens'],'stream':True,'store':False}


def provider(request, api_key, destination):
    started=time.monotonic(); raw=''; terminal=None; reason_events=0; first_text=None
    packet=json.dumps(request,ensure_ascii=False).encode()
    response_error=None
    connection=http.client.HTTPSConnection('api.deepseek.com',timeout=PROVIDER_IDLE_SECONDS)
    try:
        connection.connect()
        wire=connection.sock
        wire.settimeout(PROVIDER_IDLE_SECONDS)
        connection.request('POST','/responses',body=packet,
                           headers={'Content-Type':'application/json','Authorization':'Bearer '+api_key})
        response=connection.getresponse()
        if response.status!=200:
            detail=response.read(8192).decode('utf-8',errors='replace').replace(api_key,'[redacted]')
            raise RuntimeError(f'provider HTTP status {response.status}: {detail}')
        last_progress=time.monotonic()
        with destination.with_suffix('.events.jsonl').open('x') as events:
            while True:
                remaining=PROVIDER_IDLE_SECONDS-(time.monotonic()-last_progress)
                if remaining<=0: raise TimeoutError('provider made no observable progress before idle deadline')
                wire.settimeout(remaining)
                line=response.readline()
                if time.monotonic()-last_progress>PROVIDER_IDLE_SECONDS:
                    raise TimeoutError('provider made no observable progress before idle deadline')
                if not line: break
                if not line.startswith(b'data: '): continue
                event=json.loads(line[6:]); events.write(json.dumps(event,ensure_ascii=False)+'\n');events.flush()
                kind=event.get('type','')
                if (kind.startswith(('response.output_text.', 'response.reasoning', 'response.function_call_arguments.')) or
                    kind in {'response.created','response.in_progress','response.output_item.added',
                             'response.output_item.done','response.content_part.added','response.content_part.done',
                             'response.completed','response.incomplete','response.failed'}):
                    last_progress=time.monotonic()
                if kind=='response.output_text.delta':
                    raw+=event['delta'];first_text=first_text or time.monotonic()-started
                    print('.',end='',flush=True)
                elif kind.startswith('response.reasoning'):
                    reason_events+=1;print('r',end='',flush=True)
                else: print(f'[{kind}]',end='',flush=True)
                if kind in ('response.completed','response.incomplete','response.failed'):
                    terminal=event['response'];break
            if terminal is None: raise RuntimeError('provider omitted terminal response')
    except Exception as failure:
        response_error={'type':type(failure).__name__,'message':str(failure).replace(api_key,'[redacted]')[:2048]}
    finally:
        connection.close()
    metadata={'terminal':terminal,'error':response_error,'reasoningEvents':reason_events,
              'providerSeconds':time.monotonic()-started,'firstVisibleTextSeconds':first_text,
              'progressIdleSeconds':PROVIDER_IDLE_SECONDS,'absoluteWallDeadlineSeconds':None}
    destination.write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
    return raw, metadata


def native_projection(raw_path, directory):
    text = native(HARNESS + RUNTIME + ['--study-project', str(raw_path)], directory/'projection.native.log')
    projected = json.loads(next(line.removeprefix('NATIVE-PROJECTION ') for line in text.splitlines()
                                if line.startswith('NATIVE-PROJECTION ')))['prediction']
    return projected if isinstance(projected, str) else None


def native_score(id, candidate, directory):
    directory.mkdir()
    path=directory/'candidate.sexp';path.write_text(candidate if candidate is not None else '')
    text=native(HARNESS+RUNTIME+['--study-score',id,str(path)],directory/'score.native.log')
    observation=json.loads(next(line.removeprefix('NATIVE-SCORE ') for line in text.splitlines() if line.startswith('NATIVE-SCORE ')))
    return observation


def summary(records, plan):
    def timing(group, key):
        values=[row[key] for row in group if row.get(key) is not None]
        return {'observed':len(values),'totalSeconds':sum(values),
                'medianSeconds':statistics.median(values) if values else None,
                'maximumSeconds':max(values) if values else None}
    def cost(group):
        usages=[row['usage'] for row in group if isinstance(row.get('usage'),dict)
                and isinstance(row['usage'].get('input_tokens'),int)
                and isinstance(row['usage'].get('output_tokens'),int)]
        return {'usageObserved':len(usages),'usageMissing':len(group)-len(usages),
                'inputTokensObserved':sum(x['input_tokens'] for x in usages),
                'outputTokensObserved':sum(x['output_tokens'] for x in usages),
                'observedUsagePeakPriceUpperUsd':sum(x['input_tokens']*.3+x['output_tokens']*1.2 for x in usages)/1_000_000,
                'actualInvoiceUsd':None}
    results=[]
    for arm in ('initial-none','initial-high','transfer-fresh','transfer-history','transfer-feedback'):
        group=[row for row in records if row['arm']==arm]
        results.append({'arm':arm,'scheduled':12,'attempted':len(group),
                        'completed':sum(row['providerCompleted'] for row in group),
                        'rawReadable':sum(row['rawObservation']['readable'] for row in group),
                        'normalizedReadable':sum(row['nativeObservation']['readable'] for row in group),
                        'correct':sum(row['endToEndCorrect'] for row in group),
                        'nativeCorrectObserved':sum(row['nativeObservation']['correct'] for row in group),
                        'providerFailures':sum(row['providerError'] is not None for row in group),
                        'providerTiming':timing(group,'providerSeconds'),
                        'nativeScoringTiming':timing(group,'nativeSeconds'),
                        'firstVisibleTiming':timing(group,'firstVisibleTextSeconds'),
                        'cost':cost(group)})
    paired=[]
    for a,b in [('initial-none','initial-high'),('transfer-fresh','transfer-history'),('transfer-history','transfer-feedback'),('transfer-fresh','transfer-feedback')]:
        left={row['family']:row for row in records if row['arm']==a};right={row['family']:row for row in records if row['arm']==b}
        shared=left.keys()&right.keys()
        wins=sum(not left[f]['endToEndCorrect'] and right[f]['endToEndCorrect'] for f in shared)
        losses=sum(left[f]['endToEndCorrect'] and not right[f]['endToEndCorrect'] for f in shared)
        paired.append({'baseline':a,'comparison':b,'matchedFamilies':len(shared),'wins':wins,'losses':losses,
                       'netAccuracyPoints':100*(wins-losses)/12})
    return {'schema':'ascent.model-closure-study-result','version':1,'sourceHead':plan['sourceHead'],
            'scheduledCalls':60,'attemptedCalls':len(records),'groups':results,'paired':paired,
            'cost':cost(records),'frozenBudgetCeilingUsd':plan['budgetCeilingUsd'],
            'claimBoundary':'twelve source-bound families; observed accuracy/latency/cost only; no universal gain claim'}


def live(preview,output,approved):
    plan=validate(preview,approved)
    key=os.environ.get('DEEPSEEK_API_KEY')
    if not key: raise ValueError('DEEPSEEK_API_KEY is not configured')
    output.mkdir(parents=True,exist_ok=False)
    with (preview/'paid-batch-claim.json').open('x') as claim:
        claim.write(json.dumps({'planSha256':approved,'output':str(output)})+'\n');claim.flush();os.fsync(claim.fileno())
    initial={};records=[]
    try:
        for index,item in enumerate(plan['order']):
            request=request_for(plan,preview,item,initial)
            destination=output/f'{index:02d}';destination.mkdir()
            packet=json.dumps(request,ensure_ascii=False,indent=2).encode();(destination/'request.json').write_bytes(packet)
            attempt={**item,'index':index,'planSha256':approved,'requestSha256':digest(packet)}
            with (output/'attempts.jsonl').open('a') as ledger:
                ledger.write(json.dumps(attempt)+'\n');ledger.flush();os.fsync(ledger.fileno())
            print(f'CALL {index+1}/60 {item["family"]} {item["arm"]} ',end='',flush=True)
            raw,response=provider(request,key,destination/'response.json');(destination/'raw-output.txt').write_text(raw)
            start=time.monotonic();canonical=native_projection(destination/'raw-output.txt',destination)
            raw_score=native_score(item['case'],raw,destination/'raw')
            observation=native_score(item['case'],canonical,destination/'normalized')
            truth=(preview/'private'/f'{item["case"]}.sexp').read_text().strip()
            if observation['nativeDatum']!=truth or raw_score['nativeDatum']!=truth:
                raise ValueError('current native truth changed; batch stops without retry')
            terminal=response['terminal'];completed=bool(terminal and terminal.get('status')=='completed' and response['error'] is None)
            record={**attempt,'raw':raw,'responseId':terminal.get('id') if terminal else None,
                    'resolvedModel':terminal.get('model') if terminal else None,'providerStatus':terminal.get('status') if terminal else None,
                    'providerCompleted':completed,'providerError':response['error'],'usage':terminal.get('usage') if terminal else None,
                    'rawObservation':raw_score,'nativeObservation':observation,'endToEndCorrect':bool(completed and observation['correct']),
                    'providerSeconds':response['providerSeconds'],'nativeSeconds':time.monotonic()-start,
                    'firstVisibleTextSeconds':response['firstVisibleTextSeconds'],'reasoningEvents':response['reasoningEvents']}
            with (output/'calls.jsonl').open('a') as ledger:
                ledger.write(json.dumps(record,ensure_ascii=False)+'\n');ledger.flush();os.fsync(ledger.fileno())
            records.append(record)
            if item['arm']=='initial-high':initial[item['family']]=record
            print(f' DONE complete={completed} correct={record["endToEndCorrect"]}',flush=True)
    finally:
        (output/'result.json').write_text(json.dumps(summary(records,plan),indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser()
    modes=parser.add_subparsers(dest='mode',required=True)
    prepare_args=modes.add_parser('prepare');prepare_args.add_argument('output',type=Path)
    probe_args=modes.add_parser('probe');probe_args.add_argument('output',type=Path)
    validate_args=modes.add_parser('validate');validate_args.add_argument('preview',type=Path);validate_args.add_argument('--approved-sha256',required=True)
    live_args=modes.add_parser('live');live_args.add_argument('preview',type=Path);live_args.add_argument('output',type=Path);live_args.add_argument('--approved-sha256',required=True)
    args=parser.parse_args()
    if args.mode=='prepare':prepare(args.output.resolve())
    elif args.mode=='probe':
        probe(args.output.resolve());print('NATIVE-SOURCE-PROBE-OK modelCalls=0',flush=True)
    elif args.mode=='validate':
        validate(args.preview.resolve(),args.approved_sha256);print('OFFLINE-VALID modelCalls=0',flush=True)
    else:live(args.preview.resolve(),args.output.resolve(),args.approved_sha256)

if __name__=='__main__':main()
