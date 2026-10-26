#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute actual Quint ITF paths and corrected counterparts through SysML."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
MODEL = HERE / '27-bounded-scheduling.sysml'
MODES = {'none': 0, 'capacity': 1, 'priority': 2, 'close': 3, 'burst': 4}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cases', type=Path, required=True)
    parser.add_argument('--artifacts', type=Path, required=True)
    args = parser.parse_args()
    out = args.artifacts.resolve()
    out.mkdir(parents=True, exist_ok=False)
    cases = json.loads(args.cases.read_text())
    projections = []
    # QNT negative paths are also executed with the correct contract. Native
    # Scheme separately compares every prefix to the actual QNT scalar state.
    for case in cases:
        trace = json.loads(Path(case['trace']).read_text())
        state_key = next(key for key in trace['vars'] if key.endswith('::s'))
        unsafe = any(state[state_key]['bad'] or
                     int(state[state_key]['d']['#bigint']) + (int(state[state_key]['b']['#bigint']) == 1) > 2 or
                     (int(state[state_key]['p']['#bigint']) == 2 and
                      any(int(state[state_key][key]['#bigint']) != 0 for key in ('d', 'c', 'b')))
                     for state in trace['states'])
        for mode in sorted({0, MODES[case['mode']]}):
            operations = [row[0] for row in case['events']]
            if len(operations) > 12:
                raise RuntimeError('Trace longer than declared SysML bound')
            values = operations + [7] * (12 - len(operations)) + [mode]
            subject = 'ContextBoundedScheduling::Scheduling(' + ','.join(map(str, values)) + ')'
            projections.append(dict(subject=subject, unsafe=unsafe and mode != 0,
                                    origin=case['trace'], mode=mode,
                                    expected=case['events'][-1][1] if mode == MODES[case['mode']] else None))
    command = ['sysml', '-strict', '-no-record-cache', str(MODEL), '-engine', 'run', '-json']
    for case in projections:
        command += ['-analysis', case['subject']]
    run = subprocess.run(command, capture_output=True, text=True, timeout=60)
    (out/'sysml.json').write_text(run.stdout)
    (out/'stderr.txt').write_text(run.stderr)
    data = json.loads(run.stdout)
    checks = data.get('checks') or []
    if data.get('errors') or data.get('diagnostics') or len(checks) != len(projections):
        raise RuntimeError('Incomplete SysML execution')
    for case, check in zip(projections, checks):
        expected = 'fails' if case['unsafe'] else 'holds'
        verifications = check.get('verifications') or []
        results = check.get('results') or []
        values = {row['name']: row['value'] for row in check.get('values', [])}
        if (check.get('subject') != case['subject'] or check.get('status') != expected
                or len(results) != 1 or results[0].get('engine') != 'run'
                or results[0].get('claim') != ('violated' if case['unsafe'] else 'holds')
                or any(b.get('reached') for b in results[0].get('bounds', []))
                or values.get('steps') != '12'
                or len(verifications) != 1
                or verifications[0].get('kind') != ('fail' if case['unsafe'] else 'pass')):
            raise RuntimeError('Unexpected SysML path: ' + str(case))
        if case['expected'] is not None:
            fields = ('queuedData', 'queuedControls', 'active', 'consecutiveControls', 'lifecycle')
            if any(values.get(name) != str(value) for name, value in zip(fields, case['expected'])):
                raise RuntimeError('SysML/Quint final state mismatch: ' + str(case))
    count = sum(case['unsafe'] for case in projections)
    if run.returncode != (1 if count else 0):
        raise RuntimeError('Wrong SysML exit')
    (out/'summary.json').write_text(json.dumps(dict(
        executed=len(checks), expected_unsafe=count, unexpected=0,
        model_sha256=sha(MODEL), runner_sha256=sha(Path(__file__)),
        cases_sha256=sha(args.cases), paths=projections), indent=2)+'\n')
    print(f'PASS: {len(checks)} SysML paths, {count} expected counterexamples')


if __name__ == '__main__':
    main()
