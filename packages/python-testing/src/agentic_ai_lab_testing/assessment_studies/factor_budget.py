# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Paid bounded pilot: Python owns byte IO/cost; frozen Scheme owns semantics."""
import argparse, hashlib, json, os, selectors, subprocess, time, shutil
from datetime import datetime, timezone
from pathlib import Path
from .model_study import provider, response_outcome
from .movie_study import provider_key
from agentic_ai_lab_runtime.reasoning import ResponseHistory
ROOT = Path.cwd().resolve()
BASE = ROOT / '.cache/ascent/factor-budget'
SNAP = BASE / 'snapshot'

def sha(b):
    return hashlib.sha256(b).hexdigest()

def save(p, x):
    p.write_text(json.dumps(x, ensure_ascii=False, indent=2) + '\n')

class SchemeEngine:

    def __init__(self):
        env = os.environ.copy()
        env['GERBIL_PATH'] = str(SNAP / '.gerbil')
        env['GERBIL_LOADPATH'] = str(SNAP / '.gerbil/lib')
        env['LIBRARY_PATH'] = subprocess.check_output(['brew', '--prefix', 'openssl@3'], text=True).strip() + '/lib'
        for k in ('CC', 'CFLAGS', 'CPPFLAGS', 'LDFLAGS', 'CPATH', 'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH', 'NIX_CFLAGS_COMPILE', 'NIX_LDFLAGS', 'DEVELOPER_DIR', 'SDKROOT'):
            env.pop(k, None)
        self.err = (BASE / 'native-stderr.log').open('a')
        self.p = subprocess.Popen([str(SNAP / '.gerbil/bin/factor-budget'), '-:max-heap=1G,debug=q'], cwd=SNAP, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.err, text=True, bufsize=1)

    def call(self, **kw):
        began = time.monotonic()
        self.p.stdin.write(json.dumps(kw) + '\n')
        self.p.stdin.flush()
        s = selectors.DefaultSelector()
        s.register(self.p.stdout, selectors.EVENT_READ)
        if not s.select(20):
            self.close()
            raise TimeoutError('native reply deadline')
        s.close()
        line = self.p.stdout.readline()
        if not line:
            raise RuntimeError('native exited; see native-stderr.log')
        r = json.loads(line)
        if 'error' in r:
            raise RuntimeError(r['error'])
        return (r, time.monotonic() - began)

    def close(self):
        if self.p.poll() is None:
            self.p.terminate()
            try:
                self.p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.p.kill()
                self.p.wait(timeout=5)
        self.err.close()
import random, copy

def canonical(x):
    return json.dumps(x, sort_keys=True, separators=(',', ':'), ensure_ascii=False)

def input_reserve(request):
    return len(canonical(request).encode()) + 4096 + 128 * len(request['input'])

def charge_usage(usage):
    if not isinstance(usage, dict) or not all((type(usage.get(k)) is int and usage[k] >= 0 for k in ('input_tokens', 'output_tokens'))):
        raise ValueError('missing_usage_budget_unknown')
    total = usage['input_tokens'] + usage['output_tokens']
    if 'total_tokens' in usage and usage['total_tokens'] != total:
        raise ValueError('inconsistent_total_usage')
    for field, detail, limit in [('output_tokens_details', 'reasoning_tokens', 'output_tokens'), ('input_tokens_details', 'cached_tokens', 'input_tokens')]:
        value = usage.get(field, {}).get(detail) if isinstance(usage.get(field, {}), dict) else None
        if value is not None and (type(value) is not int or not 0 <= value <= usage[limit]):
            raise ValueError('inconsistent_usage_breakdown')
    return total

def task(seed, n, label):
    rng = random.Random(seed)
    labels = list(range(n))
    rng.shuffle(labels)
    edges = [[labels[i], labels[j]] for i in range(n) for j in range(i + 1, n) if rng.random() < 0.18]
    data = {'id': label, 'n': n, 'edges': edges, 'durations': [rng.randint(1, 12) for _ in labels], 'weights': [[rng.randint(1, 20) for _ in range(n)], [rng.randint(1, 20) for _ in labels]]}
    data['transitionPenalties'] = [[0 if i==j else rng.randint(0,250) for j in range(n)] for i in range(n)]
    return data
CASES = [task(3621, 14, 'hidden-fork-14'), task(9357, 16, 'hidden-diamond-16')]
CALIBRATION = [task(7711, 14, 'calibration-14'), task(8819, 16, 'calibration-16')]
TOOLS = [{'type': 'function', 'name': name, 'description': desc, 'parameters': {'type': 'object', 'properties': props, 'required': list(props), 'additionalProperties': False}} for name, desc, props in [('factor', 'Check source-bound implied precedence. The same evidence packet supports all returned facts.', {'u': {'type': 'integer'}, 'v': {'type': 'integer'}}), ('evaluate', 'Check full schedule; return weighted completion objective, lower is better.', {'order': {'type': 'array', 'items': {'type': 'integer'}}}), ('explore', 'Check partial schedule and list feasible next jobs.', {'prefix': {'type': 'array', 'items': {'type': 'integer'}}}), ('submit', 'Finish with your best full schedule.', {'order': {'type': 'array', 'items': {'type': 'integer'}}})]]
INSTRUCTIONS = 'Minimize sum(weight[j]*completion_time[j]) plus sum(transitionPenalties[order[k]][order[k+1]]) for adjacent job pairs, on one machine without idle time. Transition penalties are additive costs; they do not change completion times. Do not manually sum full schedule or transition costs: evaluate computes them exactly; propose useful candidates and compare returned costs. There is no penalty before the first job. Include each job exactly once; obey direct and implied precedence among jobs in this phase. Source edges involving jobs outside the current phase do not constrain this phase. Evidence contains independently admitted facts and a derivation DAG; reuse it. Resolve useful factors, explore genuinely different feasible branches, evaluate candidates and submit best found. No hidden oracle access. Total budget is 98304 billed tokens including every input and all output/thinking across calls; repeated conversation inputs count again. Conservative input reservation may stop requests early. At most 3 calls, 32 tool actions, 32768 output tokens per call. Evidence validity is limited to its source digest. Your objective is a good best-found schedule, not an internal proof of the global optimum. In your FIRST response, call evaluate on at least one feasible full schedule before prolonged refinement. Do not mentally execute an exhaustive subset DP. After the first candidate, use explore on at least two alternative partial schedules at an uncertain branch, compare genuinely different feasible full schedules, and submit your best result. Prefer tool feedback over repeatedly deriving already supplied precedence facts. The first two responses are for candidate construction and branch exploration. Your THIRD response must submit the best evaluated schedule without additional optimization. The final response uses non-thinking mode; the controller gives you the best validated candidate observed, never the hidden optimum.'

def packet(native, folder):
    folder.mkdir(exist_ok=True)
    raw, seconds = native.call(op='packet')
    cert = raw['certificate']
    payload = canonical(cert).encode()
    h = sha(payload)
    store = folder / 'proof-store'
    store.mkdir(exist_ok=True)
    (store / (h + '.json')).write_bytes(payload)
    closure = next((x[2] for x in cert['finiteClosure'] if x[0] == 'path'))
    evidence = {'sourceDigest': cert['sourceDigest'], 'certificateSha256': h, 'checkedFacts': sorted(closure), 'candidateDigest': cert['candidateDigest'], 'query': cert['query'], 'roots': sorted(cert['roots']), 'derivationNodeColumns': ['id', 'kind', 'relation', 'row', 'ruleOrSourceIndex', 'inputs'], 'derivationNodes': [[z[k] for k in ('id', 'kind', 'relation', 'row', 'ruleOrSourceIndex', 'inputs')] for z in sorted(cert['nodes'], key=lambda z: z['id'])]}
    return (evidence, {'reused': raw['reused'], 'nativeSeconds': seconds, 'proofBytes': len(payload), 'proofSha256': h})

def question(c, phase, evidence):
    n = c['n']
    return canonical({'task': c['id'], 'phase': phase, 'jobs': list(range(n)), 'durations': c['durations'][:n], 'weights': c['weights'][phase], 'sourceEdges': c['edges'], 'transitionPenalties':c['transitionPenalties'], 'evidence': evidence, 'guidance': 'Objective changes between phases. History resets; evidence remains source-bound. Optimize under the common total budget.'})

def qualify():
    native = SchemeEngine()
    checks = []
    try:
        for seed in range(10):
            c = task(seed, 7, 'small')
            ds = c['durations']
            ws = c['weights'][1]
            native.call(op='init', arm='A', edges=c['edges'], identity=c['id'], penalties=c['transitionPenalties'])
            gold, _ = native.call(op='grade', durations=ds, weights=ws, order=[])
            brute, _ = native.call(op='brute', durations=ds, weights=ws)
            assert gold['oracle']['optimum'] == brute['optimum'] and gold['oracle']['feasibleOrders'] == brute['feasibleOrders']
            checks.append({'seed': seed, 'oracle': gold['oracle'], 'exhaustive': brute})
        native.call(op='init', arm='A', edges=[], identity='hand-control')
        hand, _ = native.call(op='grade', durations=[1, 2, 3], weights=[3, 2, 1], order=[0, 1, 2])
        assert hand['optimal'] and hand['oracle']['optimum'] == 15
        native.call(op='init',arm='A',edges=[],identity='transition-hand',penalties=[[0,2,2],[3,0,2],[3,3,0]])
        transition_hand,_=native.call(op='grade',durations=[1,2,3],weights=[3,2,1],order=[0,1,2])
        assert transition_hand['optimal'] and transition_hand['oracle']['optimum']==19
        comparisons = []
        for c in CASES + CALIBRATION:
            packets = []
            answers = []
            for arm in ('A', 'D'):
                native.call(op='init', arm=arm, edges=c['edges'], identity=c['id'], penalties=c['transitionPenalties'])
                a, ar = packet(native, BASE / 'qualification-proofs')
                b, br = packet(native, BASE / 'qualification-proofs')
                assert a == b and ar['reused'] == False and (br['reused'] == (arm == 'D'))
                packets.append(a)
                answers.append([native.call(op='factor', u=u, v=v)[0]['precedes'] for u, v in [(0, c['n'] - 1), (c['n'] - 1, 0), (0, 0), (c['n'] // 2, c['n'] - 2)]])
                for phase in range(2):
                    n = c['n']
                    g, _ = native.call(op='grade', durations=c['durations'][:n], weights=c['weights'][phase], order=[])
                    order = g['oracle']['optimalOrder']
                    v, _ = native.call(op='grade', durations=c['durations'][:n], weights=c['weights'][phase], order=order)
                    assert v['optimal']
                    bad, _ = native.call(op='evaluate', durations=c['durations'][:n], weights=c['weights'][phase], order=order[:-1] + [order[0]])
                    assert not bad['valid']
            assert packets[0] == packets[1] and answers[0] == answers[1]
            for phase in range(2):
                assert question(c, phase, packets[0]) == question(c, phase, packets[1])
            comparisons.append({'task': c['id'], 'packetSha256': sha(canonical(packets[0]).encode()), 'packetBytes': len(canonical(packets[0]).encode()), 'matched': True})
        save(BASE / 'qualification.json', {'passed': True, 'hand': hand,'transitionHand':transition_hand, 'dpVersusBrute': checks, 'matchedPackets': comparisons})
        print('FACTOR-BUDGET-QUALIFICATION-OK', flush=True)
    finally:
        native.close()

def freeze():
    sources = ['t/research/factor-budget.ss', 't/research/factor-budget-oracle.ss', 't/research/factor-budget-build.ss', 'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/factor_budget.py', 'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/model_study.py', 'packages/python-testing/src/agentic_ai_lab_testing/assessment_studies/movie_study.py', 'rust/ascent/src/conversation.rs']
    artifacts = {str(p.relative_to(SNAP)): sha(p.read_bytes()) for p in (SNAP / '.gerbil/lib').rglob('*') if p.is_file() and (not p.name.endswith('.lock'))}
    artifacts['.gerbil/bin/factor-budget'] = sha((SNAP / '.gerbil/bin/factor-budget').read_bytes())
    plan = {'schema': 'ascent.factor-total-budget.v4', 'frozenAtUtc': datetime.now(timezone.utc).isoformat(), 'headAtFreeze': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'cases': CASES, 'calibrationCases': CALIBRATION, 'arms': {'fresh': 'A', 'retained': 'D'}, 'order': [{'case': c['id'], 'arm': a} for i, c in enumerate(CASES) for a in (['fresh', 'retained'] if i == 0 else ['retained', 'fresh'])], 'totalTokenBudget': 98304, 'perCallOutputCap': 32768, 'calls': 3, 'toolActions': 32, 'model': 'deepseek-flash', 'reasoningEffort': 'high', 'instructions': INSTRUCTIONS, 'tools': TOOLS, 'producerHashes': {p: sha((ROOT / p).read_bytes()) for p in sources}, 'artifactHashes': artifacts, 'qualificationSha256': sha((BASE / 'qualification.json').read_bytes()), 'currentCandidateSourceHashes': {str(p.relative_to(SNAP)): sha(p.read_bytes()) for p in (SNAP / 'candidate').glob('*.ss')}, 'inheritedKernelManifestSha256': sha((ROOT / '.cache/ascent/factor-pilot/source-manifest.json').read_bytes()), 'buildScope': 'New native bridge and independent subset-plus-last DP grader; inherited frozen pilot production kernel/dependencies. Candidate source files match current checkout. Not a whole-checkout rebuild.', 'reservation': 'Before each paid call, reserve compact request UTF-8 bytes plus 4096 plus 128 per input item as an empirical conservative input allowance. This is not an exact tokenizer. Provider usage is authoritative. Stop and retain reservation violations or any total-budget overshoot as protocol failures, never successful budget-matched results.', 'hardnessGate': 'Separate disjoint full-size calibration phases; at least one valid non-optimal best-observed calibration candidate under known gross-token budget required; censored refinement and missing submission remain failures before confirmatory run. No task selection using confirmatory outcomes.', 'measurement': 'Repeated tool fact requests, duplicate prefixes/candidates, prefix depth and branching, independently graded objective gaps; reasoning token counts. Hidden semantic thinking repetition is not measured.', 'causalBoundary': 'Same model-visible initial packets and deterministic answers; cache flags/timings remain private. Cache-only state cannot directly cause different token allocation under identical observations. Small stochastic differences are descriptive.', 'finalReasoningEffort':'none','finalizePolicy':'After at most two high-reasoning construction/refinement calls, final non-thinking submit receives the best independently evaluated candidate; no hidden oracle information.', 'qualityEndpoint':'Any-time best verified candidate when no final submission; missing submission and censored optimization remain failures. No candidate is counted as a successful task solely because its grade is valid.', 'calibrationSourcePlan':'calibration/frozen-source-plan.json', 'supersedes': 'calibration/frozen-source-plan.json', 'revisionReason': 'Transition calibration produced valid non-optimal candidates with gaps 206 and 397, but censored refinement before submission. Before any confirmatory outcome, select any-time candidate quality and separate completion/censoring as endpoints. Relax only the hardness admission rule to accept valid non-optimal best-observed candidates with known in-budget usage; do not reclassify any calibration failure as success. Model requests, task definitions, independent grader, artifact bytes, input reservation and inference/finalization policy remain identical to v3. Preserve the original stricter calibration plan and controller separately.', 'failurePolicy': 'No retries; retain raw requests, SSE, usage unknowns, native/tool errors, incomplete responses and all final grades.'}
    save(BASE / 'frozen-plan.json', plan)
    (BASE / 'frozen-plan.sha256').write_text(sha((BASE / 'frozen-plan.json').read_bytes()) + '\n')
    print('FROZEN', len(artifacts), flush=True)

def verify(plan):
    assert sha((BASE / 'frozen-plan.json').read_bytes()) == (BASE / 'frozen-plan.sha256').read_text().strip()
    assert sha((BASE / 'qualification.json').read_bytes()) == plan['qualificationSha256']
    for p, h in plan['currentCandidateSourceHashes'].items():
        assert sha((ROOT / p).read_bytes()) == h, p
    for p, h in plan['producerHashes'].items():
        assert sha((ROOT / p).read_bytes()) == h, p
    for p, h in plan['artifactHashes'].items():
        assert sha((SNAP / p).read_bytes()) == h, p
    for p in ('t/research/factor-budget.ss', 't/research/factor-budget-oracle.ss', 't/research/factor-budget-build.ss'):
        assert sha((SNAP / p).read_bytes()) == plan['producerHashes'][p]

def run_phase(plan, c, phase, arm, native, folder):
    folder.mkdir()
    evidence, build = packet(native, folder)
    expected = next(x['packetSha256'] for x in json.loads((BASE / 'qualification.json').read_text())['matchedPackets'] if x['task'] == c['id'])
    if sha(canonical(evidence).encode()) != expected:
        raise RuntimeError('model-visible packet differs from frozen qualification')
    q = question(c, phase, evidence)
    save(folder / 'evidence.json', evidence)
    history = ResponseHistory(q)
    n = c['n']
    ds = c['durations'][:n]
    ws = c['weights'][phase]
    row = {'case': c['id'], 'phase': phase, 'arm': arm, 'packet': build, 'initialInputSha256': sha(q.encode()), 'calls': [], 'tools': [], 'failure': None, 'totalTokenBudget': plan['totalTokenBudget']}
    used = 0
    best = None
    submitted = None
    seen = set()
    key = provider_key()
    for turn in range(plan['calls']):
        final_turn = turn == plan['calls']-1
        if final_turn:
            history.append_feedback({'instruction':'Call submit now with the best evaluated feasible schedule; no further optimization.', 'bestEvaluatedOrder':best[1] if best else None,'bestEvaluatedObjective':best[0] if best else None})
        request = {'model': plan['model'], 'input': history.input(), 'instructions': plan['instructions'], 'tools': plan['tools'], 'tool_choice': {'type':'function','name':'submit'} if final_turn else 'auto', 'reasoning': {'effort':plan['finalReasoningEffort'] if final_turn else plan['reasoningEffort']}, 'stream': True, 'store': False}
        reserve = input_reserve(request)
        cap = min(plan['perCallOutputCap'], plan['totalTokenBudget'] - used - reserve)
        if cap < 256 or len(row['tools']) >= plan['toolActions']:
            row['failure'] = 'total_budget_reservation_stop'
            break
        request['max_output_tokens'] = cap
        save(folder / f'{turn}.request.json', request)
        _, meta = provider(request, key, folder / f'{turn}.response.json')
        terminal = meta.get('terminal') or {}
        usage = terminal.get('usage')
        call = {'turn': turn, 'usage': usage, 'inputReserve': reserve, 'outputCap': cap, 'seconds': meta['providerSeconds'], 'outcome': response_outcome(meta), 'responseFile': str((folder / f'{turn}.response.json').relative_to(BASE))}
        row['calls'].append(call)
        try:
            charge = charge_usage(usage)
        except ValueError as e:
            row['failure'] = str(e)
            charge = None
        if charge is not None:
            used += charge
            if usage['input_tokens'] > reserve or usage['output_tokens'] > cap or used > plan['totalTokenBudget']:
                row['failure'] = 'budget_protocol_violation'
        save(folder / 'receipt.json', row)
        if row['failure']:
            break
        if meta.get('error') or terminal.get('status') != 'completed':
            row['failure'] = call['outcome']
            break
        try:
            calls = history.append_response(terminal)
        except Exception as e:
            row['failure'] = 'invalid_conversation:' + str(e)
            break
        if not calls:
            row['failure'] = 'no_submit'
            break
        for fc in calls:
            started = time.monotonic()
            name = fc['name']
            log = {'name': name, 'rawArguments': fc['arguments']}
            try:
                args = json.loads(fc['arguments'])
                log['arguments'] = args
                sig = (name, canonical(args))
                log['duplicateWithinPhase'] = sig in seen
                seen.add(sig)
                if len(row['tools']) >= plan['toolActions']:
                    result = {'error': 'tool budget exhausted'}
                elif name == 'factor':
                    raw, ipc = native.call(op='factor', **args)
                    cert = raw.pop('admittedCertificate')
                    log['nativeSeconds'] = ipc
                    log['nativeReceipt'] = raw
                    if cert:
                        payload = canonical(cert).encode()
                        h = sha(payload)
                        (folder / 'proof-store' / f'{h}.json').write_bytes(payload)
                        log['proofStoreSha256'] = h
                        log['proofBytes'] = len(payload)
                    result = {k: raw[k] for k in ('claim', 'precedes', 'sourceDigest')}
                    result['evidenceCertificateSha256'] = evidence['certificateSha256']
                elif name in ('evaluate', 'submit'):
                    result, ipc = native.call(op='evaluate', durations=ds, weights=ws, **args)
                    log['nativeSeconds'] = ipc
                    if result['valid'] and (best is None or result['objective'] < best[0]):
                        best = (result['objective'], args['order'])
                    if name == 'submit':
                        submitted = args['order']
                elif name == 'explore':
                    result, ipc = native.call(op='explore', n=n, **args)
                    log['nativeSeconds'] = ipc
                else:
                    raise ValueError('unknown tool')
            except Exception as e:
                result = {'error': str(e)[:2000]}
                log['failure'] = str(e)[:2000]
            log['result'] = result
            log['seconds'] = time.monotonic() - started
            row['tools'].append(log)
            history.append_result(fc['call_id'], result)
        save(folder / 'receipt.json', row)
        if submitted is not None:
            break
    candidate = submitted if submitted is not None else best[1] if best else []
    row['submitted'] = submitted is not None
    row['candidate'] = candidate
    row['observedTotalTokens'] = used
    row['grade'], row['graderSeconds'] = native.call(op='grade', durations=ds, weights=ws, order=candidate)
    if not row['submitted'] and (not row['failure']):
        row['failure'] = 'call_limit_exhausted'
    save(folder / 'receipt.json', row)
    print('\nPHASE', c['id'], phase, arm, 'tokens', used, 'gap', row['grade']['gap'], 'failure', row['failure'], flush=True)
    return row

def run(plan, calibration=False):
    verify(plan)
    dest = BASE / ('calibration' if calibration else 'paid')
    dest.mkdir(exist_ok=False)
    rows = []
    if calibration:
        order = [{'case': c['id'], 'arm': 'fresh'} for c in plan['calibrationCases']]
        cases = plan['calibrationCases']
    else:
        calibration_rows = json.loads((BASE / 'calibration/records.json').read_text())
        assert len(calibration_rows) == 2 and any((r['grade']['valid'] and (not r['grade']['optimal']) and r['failure'] in (None,'output_budget_exhausted','total_budget_reservation_stop','call_limit_exhausted') and r['observedTotalTokens']<=plan['totalTokenBudget'] and all(charge_usage(c['usage'])>=0 for c in r['calls']) for r in calibration_rows)), 'hardness gate failed'
        order = plan['order']
        cases = plan['cases']
    for item in order:
        c = next((x for x in cases if x['id'] == item['case']))
        native = SchemeEngine()
        try:
            native.call(op='init', arm=plan['arms'][item['arm']], edges=c['edges'], identity=c['id'], penalties=c['transitionPenalties'])
            for phase in [1] if calibration else [0, 1]:
                row = run_phase(plan, c, phase, item['arm'], native, dest / f"{c['id']}-{item['arm']}-{phase}")
                rows.append(row)
                save(dest / 'records.json', rows)
        finally:
            native.close()
    verify(plan)
    save(dest / 'post-run-binding.json', {'passed': True, 'artifacts': len(plan['artifactHashes']), 'frozenPlanSha256': sha((BASE / 'frozen-plan.json').read_bytes())})
    return rows
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['qualify', 'freeze', 'calibrate', 'run'])
    a = parser.parse_args()
    if a.command == 'qualify':
        qualify()
    elif a.command == 'freeze':
        freeze()
    else:
        run(json.loads((BASE / 'frozen-plan.json').read_text()), a.command == 'calibrate')
