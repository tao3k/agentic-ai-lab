#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute native-Provider contract scenarios and retain unsafe replay inputs."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
MODEL = HERE / '15-query-provider.sysml'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected_failure(case):
    """Independent oracle for each unsafe algorithm, not the CLI verdict."""
    family, args = case['family'], case['inputs']
    if family == 'Binding':
        *flags, mode = args
        expected = all(flags)
        actual = True if mode == 1 else all(flags[:-1]) and (flags[-1] or mode == 2)
        return expected != actual
    *order, kind, mode = args
    positions = {op: order.index(op) for op in order}
    if mode in (1, 2, 4, 5, 7):
        return True
    if mode == 3:
        return positions[3] > positions[1] or positions[1] < positions[2] < positions[4]
    if mode == 6:
        return positions[2] < min(positions[1], positions[4])
    return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--replay', type=Path)
    args = parser.parse_args()
    out = args.artifacts or Path(tempfile.mkdtemp(prefix='query-provider-model-', dir='/private/tmp'))
    out.mkdir(parents=True, exist_ok=True)
    if args.replay:
        witness = json.loads(args.replay.read_text())
        if witness['model_sha256'] != sha(MODEL):
            raise RuntimeError('Stale model witness')
        fixed = dict(witness['case'])
        fixed['inputs'] = [*fixed['inputs'][:-1], 0]
        cases = [witness['case'], fixed]
    else:
        cases = [dict(family='Binding', inputs=[*flags, mode])
                 for flags in itertools.product((False, True), repeat=6)
                 for mode in range(3)]
        orders = [p for p in itertools.permutations(range(1, 6)) if p.index(4) < p.index(5)]
        cases += [dict(family='Race', inputs=[*order, kind, mode])
                  for order in orders for kind in (0, 1) for mode in range(8)]
    command = ['sysml', '-strict', '-no-record-cache', str(MODEL), '-engine', 'run', '-json']
    subjects = []
    for case in cases:
        values = ','.join(str(v).lower() for v in case['inputs'])
        subject = f'ContextQueryProvider::{case["family"]}({values})'
        subjects.append(subject)
        command += ['-analysis', subject]
    result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    (out / 'sysml.json').write_text(result.stdout)
    (out / 'stderr.txt').write_text(result.stderr)
    data = json.loads(result.stdout)
    checks = data.get('checks') or []
    if data.get('errors') or data.get('diagnostics') or len(checks) != len(cases):
        raise RuntimeError('Incomplete or invalid executed SysML scenarios')
    failed = 0
    for n, (case, subject, check) in enumerate(zip(cases, subjects, checks)):
        bad = expected_failure(case)
        values = {v['name']: v['value'] for v in check.get('values') or []}
        executions = check.get('results') or []
        verifications = check.get('verifications') or []
        expected_steps = '1' if case['family'] == 'Binding' else '5'
        if (check.get('subject') != subject or check.get('status') != ('fails' if bad else 'holds')
                or values.get('steps') != expected_steps or len(executions) != 1
                or executions[0].get('engine') != 'run'
                or executions[0].get('claim') != ('violated' if bad else 'holds')
                or len(verifications) != 1
                or verifications[0].get('kind') != ('fail' if bad else 'pass')
                or any(b.get('reached') for b in executions[0].get('bounds', []))):
            raise RuntimeError(f'Wrong executed scenario: {case}')
        if bad:
            failed += 1
            (out / f'counterexample-{n:04d}.json').write_text(json.dumps(
                dict(case=case, model_sha256=sha(MODEL), actual=check), indent=2) + '\n')
    if result.returncode != (1 if failed else 0):
        raise RuntimeError('Unexpected SysML CLI exit status')
    (out / 'summary.json').write_text(json.dumps(dict(
        executed=len(cases), expected_unsafe=failed, unexpected=0,
        model_sha256=sha(MODEL), runner_sha256=sha(Path(__file__)), native_proof=False), indent=2) + '\n')
    print(f'PASS: {len(cases)} executed; {failed} expected unsafe; {out}')


if __name__ == '__main__':
    main()
