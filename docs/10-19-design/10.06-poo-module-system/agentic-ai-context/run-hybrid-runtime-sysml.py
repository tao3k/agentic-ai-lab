#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute actual hybrid QNT paths and corrected counterparts in SysML."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
MODEL = HERE/'28-hybrid-runtime.sysml'
MODES = {'none': 0, 'receipt': 1, 'credit': 2, 'join': 3, 'terminal': 4}
FIELDS = ('workPhase', 'nativeCredit', 'ownerJoined', 'queuedData', 'queuedControls',
          'activeHandler', 'queuePhase', 'sourceVersion', 'policyVersion',
          'ownerEpoch', 'activeAttempt', 'terminalCount')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def integer(value):
    return int(value['#bigint'])


def project(trace, state):
    def item(suffix):
        return state[next(name for name in trace['vars'] if name.endswith(suffix))]
    auth, queue = item('::auth::s'), item('::queue::s')
    terminal = next(integer(count) for key, count in auth['terminals']['#map'] if integer(key) == 0)
    values = [integer(item('::work')), integer(item('::credit')), item('::joined'),
              *[integer(queue[key]) for key in ('d', 'c', 'b', 'p')],
              *[integer(auth[key]) for key in ('source', 'policy', 'owner', 'active')], terminal]
    unsafe = (any(auth[key] for key in ('badOwner', 'badUse', 'badRevival')) or terminal > 1
              or queue['bad'] or (values[0] == 1 and values[1] != 1)
              or (values[2] and (values[0] == 1 or integer(queue['p']) != 2)))
    return values, unsafe, integer(item('::event'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quint', type=Path, required=True)
    parser.add_argument('--artifacts', type=Path, required=True)
    args = parser.parse_args()
    out = args.artifacts.resolve()
    out.mkdir(parents=True, exist_ok=False)
    receipt = json.loads((args.quint/'summary.json').read_text())
    cases = []
    for family in receipt['replays']:
        mode = MODES[family['mode']]
        for name, digest in family['traces'].items():
            path = args.quint/('replay-'+family['mode'])/name
            if sha(path) != digest:
                raise RuntimeError('Stale QNT replay input')
            trace = json.loads(path.read_text())
            rows = [project(trace, state) for state in trace['states']]
            moves = [row[2] for row in rows[1:]]
            if len(moves) > 16:
                raise RuntimeError('Replay exceeds declared SysML bound')
            for actual in sorted({mode, 0}):
                inputs = moves + [20]*(16-len(moves)) + [actual]
                subject = 'ContextHybridRuntime::Handoff('+','.join(map(str, inputs))+')'
                cases.append(dict(subject=subject, trace=str(path), mode=actual,
                                  unsafe=any(row[1] for row in rows) and actual != 0,
                                  expected=rows[-1][0] if actual == mode else None))
    command = ['sysml', '-strict', '-no-record-cache', str(MODEL), '-engine', 'run', '-json']
    for case in cases:
        command += ['-analysis', case['subject']]
    result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    (out/'sysml.json').write_text(result.stdout)
    (out/'stderr.txt').write_text(result.stderr)
    data = json.loads(result.stdout)
    checks = data.get('checks') or []
    if data.get('errors') or data.get('diagnostics') or len(checks) != len(cases):
        raise RuntimeError('Incomplete SysML execution')
    for case, check in zip(cases, checks):
        runs = check.get('results') or []
        verdicts = check.get('verifications') or []
        values = {row['name']: row['value'] for row in check.get('values', [])}
        if (check.get('subject') != case['subject']
                or check.get('status') != ('fails' if case['unsafe'] else 'holds')
                or len(runs) != 1 or runs[0].get('engine') != 'run'
                or runs[0].get('claim') != ('violated' if case['unsafe'] else 'holds')
                or any(bound.get('reached') for bound in runs[0].get('bounds', []))
                or len(verdicts) != 1 or verdicts[0].get('kind') != ('fail' if case['unsafe'] else 'pass')
                or values.get('steps') != '16'):
            raise RuntimeError('Unexpected SysML verdict: '+str(case))
        if case['expected'] is not None:
            def scalar(value):
                return str(value).lower() if isinstance(value, bool) else str(value)
            if any(values.get(key) != scalar(value) for key, value in zip(FIELDS, case['expected'])):
                raise RuntimeError('SysML/QNT scalar mismatch: '+str(case))
    negative = sum(case['unsafe'] for case in cases)
    if result.returncode != (1 if negative else 0):
        raise RuntimeError('Wrong SysML exit status')
    (out/'summary.json').write_text(json.dumps(dict(
        model_sha256=sha(MODEL), runner_sha256=sha(Path(__file__)),
        quint_summary_sha256=sha(args.quint/'summary.json'),
        executed=len(cases), expected_unsafe=negative, unexpected=0, paths=cases,
        unbounded_refinement_proved=False), indent=2)+'\n')
    print(f'PASS: {len(cases)} hybrid SysML executions, {negative} expected counterexamples')


if __name__ == '__main__':
    main()
