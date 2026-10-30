#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute background clock contract positives and named unsafe controls."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess
import tempfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--replay', type=Path)
    args = parser.parse_args()
    model = Path(__file__).with_name('13-background-clock.sysml')
    version = subprocess.run(['sysml', '-version'], capture_output=True, text=True, check=True).stdout.strip()
    artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix='context-clock-sysml-', dir='/private/tmp'))
    artifacts.mkdir(parents=True, exist_ok=True)
    jobs = list(itertools.product((False, True), (False, True), range(5)))
    if args.replay:
        saved = json.loads(args.replay.read_text())
        if saved['model_sha256'] != sha(model):
            raise RuntimeError('Saved authority model is stale')
        k, t, m = saved['inputs']
        jobs = [(k, t, m), (k, t, 0)]
    subjects = [f'ContextBackgroundClock::Deadline({str(k).lower()},{str(t).lower()},{m})' for k, t, m in jobs]
    command = ['sysml', '-strict', '-no-record-cache', str(model), '-engine', 'run', '-json']
    for subject in subjects:
        command += ['-analysis', subject]
    result = subprocess.run(command, capture_output=True, text=True, timeout=45)
    (artifacts / 'sysml.json').write_text(result.stdout)
    (artifacts / 'stderr.txt').write_text(result.stderr)
    data = json.loads(result.stdout)
    checks = data.get('checks') or []
    if data.get('errors') or data.get('diagnostics') or len(checks) != len(jobs):
        raise RuntimeError('Incomplete authority execution')
    failures = 0
    for inputs, subject, check in zip(jobs, subjects, checks):
        k, t, m = inputs
        failed = (m == 1 and not k) or (m == 2 and k) or m in (3, 4)
        values = {row['name']: row['value'] for row in check.get('values') or []}
        evidence, verifications = check.get('results') or [], check.get('verifications') or []
        if (check.get('subject') != subject or check.get('status') != ('fails' if failed else 'holds')
                or values.get('processed') != '4' or values.get('evidenceRetained') != 'true'
                or len(verifications) != 1 or verifications[0].get('kind') != ('fail' if failed else 'pass')
                or len(evidence) != 1 or evidence[0].get('engine') != 'run'
                or evidence[0].get('claim') != ('violated' if failed else 'holds')
                or any(b.get('reached') for ev in evidence for b in ev.get('bounds', []))):
            raise RuntimeError(f'Wrong actual SysML authority verdict: {inputs}')
        if failed:
            failures += 1
            (artifacts / f'counterexample-{k}-{t}-{m}.json').write_text(json.dumps({
                'model_sha256': sha(model), 'tool': version, 'inputs': inputs, 'actual': check}, indent=2) + '\n')
    if result.returncode != (1 if failures else 0):
        raise RuntimeError('CLI exit disagrees with executed verdicts')
    summary = {'executed': len(jobs), 'expected_unsafe_failures': failures, 'safe_failures': 0,
               'model_sha256': sha(model), 'tool': version, 'bounded_contract_fixture': True,
               'native_concurrency_proof': False, 'real_clock_execution': False}
    (artifacts / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f'PASS: {len(jobs)} executed, {failures} expected unsafe; {artifacts}')


if __name__ == '__main__':
    main()
