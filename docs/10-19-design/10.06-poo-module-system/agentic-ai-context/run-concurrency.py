#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Enumerate every linear extension of the declared eight-event protocol.

Python enumerates schedules and checks CLI results. SysML executes the reducer,
current-proof gates, publication CAS and per-prefix invariant monitors.
"""
import argparse
from collections import Counter
import hashlib
import itertools
import json
from pathlib import Path
import subprocess
import sys
import tempfile

EVENTS = {1: 'receive', 2: 'qualify', 3: 'publish-result', 4: 'withdraw-source-premise',
          5: 'revoke-grant', 6: 'request-cancel', 7: 'terminal-receipt-cancel-CAS', 8: 'recover'}
EDGES = ((1, 2), (2, 3), (6, 7), (6, 8))
MODES = {0: 'safe', 1: 'skip-owner-CAS', 2: 'substitute-alternate-proof',
         3: 'restore-historical-allow', 4: 'drop-pending-worker'}
EXPECTED_FLAG = {1: 'terminalViolation', 2: 'staleViolation', 3: 'staleViolation', 4: 'obligationViolation'}
FLAGS = ('terminalViolation', 'staleViolation', 'obligationViolation')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def invocation(order, mode):
    return 'ContextConcurrentEvidence::Interleaving(' + ','.join(map(str, (*order, mode))) + ')'


def legal(order):
    return len(order) == 8 and set(order) == set(EVENTS) and all(order.index(a) < order.index(b) for a, b in EDGES)


def execute(binary, model, jobs, artifact):
    command = [binary, '-strict', '-no-record-cache', str(model), '-engine', 'run', '-json']
    for order, mode in jobs:
        command += ['-analysis', invocation(order, mode)]
    result = subprocess.run(command, text=True, capture_output=True, timeout=50)
    artifact.with_suffix('.json').write_text(result.stdout)
    artifact.with_suffix('.stderr.txt').write_text(result.stderr)
    data = json.loads(result.stdout)
    checks = data.get('checks') or []
    if data.get('diagnostics') or data.get('errors') or len(checks) != len(jobs):
        raise RuntimeError(f'Incomplete/error CLI result: {artifact}')
    any_failed = False
    rows = []
    for (order, mode), check in zip(jobs, checks):
        values = {entry['name']: entry['value'] for entry in check.get('values') or []}
        failed = values.get('verdict') == 'VerdictKind::fail'
        any_failed |= failed
        expected_status = 'fails' if failed else 'holds'
        verification = check.get('verifications') or []
        evidence = check.get('results') or []
        if (check.get('subject') != invocation(order, mode) or check.get('status') != expected_status
            or len(verification) != 1 or verification[0].get('kind') != ('fail' if failed else 'pass')
            or len(evidence) != 1 or evidence[0].get('engine') != 'run'
            or evidence[0].get('claim') != ('violated' if failed else 'holds')
            or any(b.get('reached') for ev in evidence for b in ev.get('bounds', []))):
            raise RuntimeError(f'Missing/wrong executed verdict: {check.get("subject")}')
        if (values.get('traceCode') != ''.join(map(str, order)) or values.get('processed') != '8'
            or values.get('retainedProof') != 'true' or values.get('originalRoot') != '1'
            or values.get('currentJournal') != '2'):
            raise RuntimeError(f'Wrong trace/provenance binding: {check.get("subject")}')
        flags = [name for name in FLAGS if values.get(name) == 'true']
        if failed != bool(flags) or (not failed and values.get('violatingPrefix') != '0'):
            raise RuntimeError(f'Verdict does not match prefix monitors: {check.get("subject")}')
        if any(values.get(name) not in ('true', 'false') for name in FLAGS):
            raise RuntimeError('Missing invariant monitor output')
        if failed and (not evidence[0].get('witness') or not 1 <= int(values.get('violatingPrefix', 0)) <= 8):
            raise RuntimeError('Failed execution lacks witness/violating prefix')
        rows.append({'order': list(order), 'mode': mode, 'failed': failed, 'values': values,
                     'witness': evidence[0].get('witness')})
    code = 1 if any_failed else 0
    if result.returncode != code or data.get('exit') != code or data.get('status') != ('fails' if any_failed else 'holds'):
        raise RuntimeError(f'Unexpected aggregate CLI exit/status: {artifact}')
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sysml', default='sysml')
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--replay', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    model = root / '05-concurrent-evidence-lifecycle.sysml'
    artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix='context-interleavings-', dir='/private/tmp'))
    artifacts.mkdir(parents=True, exist_ok=True)
    version = subprocess.run([args.sysml, '-version'], text=True, capture_output=True, timeout=10, check=True).stdout.strip()
    if args.replay:
        replay = json.loads(args.replay.read_text())
        order, mode = tuple(replay['order']), replay['mode']
        if digest(model) != replay['model_sha256'] or not legal(order) or mode not in MODES:
            raise RuntimeError('Replay model hash or schedule/mode mismatch')
        row = execute(args.sysml, model, [(order, mode)], artifacts / 'replay')[0]
        if row['values'] != replay['values'] or not row['failed']:
            raise RuntimeError('Counterexample did not reproduce exactly')
        print(f'REPRODUCED {MODES[mode]}: {order}; prefix {row["values"]["violatingPrefix"]}; {artifacts}')
        return 0
    orders = [p for p in itertools.permutations(EVENTS) if legal(p)]
    # 8! / (3! * 3): R<Q<P; C precedes both T and H; S/G independent.
    if len(orders) != 2240 or len(set(orders)) != 2240:
        raise RuntimeError('Incomplete/duplicate linear-extension enumeration')
    (artifacts / 'orders.json').write_text(json.dumps(orders) + '\n')
    summary = {'tool': version, 'model_sha256': digest(model), 'runner_sha256': digest(Path(__file__)),
               'events': EVENTS, 'partial_order': EDGES, 'linear_extensions': len(orders),
               'atomicity': 'one reducer event; qualification and publication separate',
               'modes': {}, 'counterexamples': [], 'artifacts': str(artifacts)}
    validation = subprocess.run([args.sysml, '-strict', '-no-record-cache', str(model), '-validate', '-self-check'],
                                text=True, capture_output=True, timeout=30)
    (artifacts / 'validation.txt').write_text(validation.stdout + validation.stderr)
    if validation.returncode:
        raise RuntimeError('Concurrent model validation failed')
    first_bad = {}
    for mode, label in MODES.items():
        counts = Counter()
        for start in range(0, len(orders), 64):
            jobs = [(order, mode) for order in orders[start:start+64]]
            rows = execute(args.sysml, model, jobs, artifacts / f'mode-{mode}-batch-{start//64:03}')
            for row in rows:
                values = row['values']
                counts['executions'] += 1
                counts['failed' if row['failed'] else 'passed'] += 1
                counts['historical-result'] += values.get('acceptedHistorically') == 'true'
                counts['cancel-terminal'] += values.get('outcome') == '2'
                counts['result-terminal'] += values.get('outcome') == '1'
                counts['pending-terminal-CAS-retry'] += values.get('terminals') == '0'
                for flag in FLAGS:
                    counts[flag] += values.get(flag) == 'true'
                if mode == 0 and row['failed']:
                    (artifacts / 'unexpected-safe-counterexample.json').write_text(json.dumps(row, indent=2))
                    raise RuntimeError('Safe reducer has a counterexample')
                if mode and row['failed'] and values.get(EXPECTED_FLAG[mode]) == 'true' and mode not in first_bad:
                    first_bad[mode] = row
            if start % 512 == 0:
                print(f'{label}: {min(start+64,len(orders))}/{len(orders)} executed', flush=True)
        if mode and (mode not in first_bad or not counts[EXPECTED_FLAG[mode]]):
            raise RuntimeError(f'Unsafe control not detected: {label}')
        if mode == 0 and not (counts['result-terminal'] and counts['cancel-terminal'] and counts['historical-result']):
            raise RuntimeError('Safe coverage is vacuous: missing result/cancellation outcomes')
        summary['modes'][label] = dict(counts)
        (artifacts / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    for mode, row in first_bad.items():
        replay = dict(row, model_sha256=digest(model), tool=version)
        prefix = int(row['values']['violatingPrefix'])
        replay['violating_prefix'] = [EVENTS[n] for n in row['order'][:prefix]]
        replay_file = artifacts / f'counterexample-mode-{mode}.json'
        replay_file.write_text(json.dumps(replay, indent=2) + '\n')
        reproduced = execute(args.sysml, model, [(tuple(row['order']), mode)], artifacts / f'reproduced-{mode}')[0]
        safe = execute(args.sysml, model, [(tuple(row['order']), 0)], artifacts / f'safe-counterpart-{mode}')[0]
        if reproduced['values'] != row['values'] or safe['failed']:
            raise RuntimeError('Counterexample replay/safe counterpart mismatch')
        summary['counterexamples'].append({'mode': mode, 'file': str(replay_file), 'reproduced': True,
                                          'safe_counterpart_passed': True,
                                          'command': [sys.executable, str(Path(__file__).resolve()), '--replay', str(replay_file)]})
    (artifacts / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f'COMPLETE: {len(orders)} legal paths x {len(MODES)} modes = {len(orders)*len(MODES)} executions; '
          f'4 counterexamples reproduced with safe counterparts; artifacts: {artifacts}')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(2)
