#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute eager invalidation and failed-delivery contract fixtures in SysML."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess
import tempfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def frozen_parent(binary, model, artifacts, version):
    subjects = ['ContextEagerPropagation::FrozenParent(true)', 'ContextEagerPropagation::FrozenParent(false)']
    command = [binary, '-strict', '-no-record-cache', str(model), '-engine', 'run', '-json']
    for subject in subjects:
        command += ['-analysis', subject]
    result = subprocess.run(command, text=True, capture_output=True, timeout=45)
    (artifacts / 'frozen-parent.json').write_text(result.stdout)
    (artifacts / 'frozen-parent.stderr.txt').write_text(result.stderr)
    data = json.loads(result.stdout)
    checks = data.get('checks') or []
    if result.returncode != 1 or data.get('errors') or data.get('diagnostics') or len(checks) != 2:
        raise RuntimeError('Missing executed frozen-parent comparison')
    for index, check in enumerate(checks):
        failed = index == 0
        values = {row['name']: row['value'] for row in check.get('values') or []}
        verifications, evidence = check.get('verifications') or [], check.get('results') or []
        if (check.get('subject') != subjects[index] or check.get('status') != ('fails' if failed else 'holds')
                or values.get('originalRetained') != 'true' or values.get('replacementAllowed') != 'true'
                or values.get('processed') != '3' or values.get('childInvalidated') != str(not failed).lower()
                or values.get('verdict') != ('VerdictKind::fail' if failed else 'VerdictKind::pass')
                or len(verifications) != 1 or verifications[0].get('kind') != ('fail' if failed else 'pass')
                or len(evidence) != 1 or evidence[0].get('engine') != 'run'
                or evidence[0].get('claim') != ('violated' if failed else 'holds')
                or any(b.get('reached') for e in evidence for b in e.get('bounds', []))):
            raise RuntimeError('Wrong frozen-parent executed verdict')
    witness = {'kind': 'frozen-parent', 'model_sha256': sha(model), 'tool': version,
               'unsafe': checks[0]['values'], 'safe': checks[1]['values']}
    (artifacts / 'counterexample-frozen-parent.json').write_text(json.dumps(witness, indent=2) + '\n')
    return {'executed': 2, 'unsafe_failures': 1, 'safe_failures': 0}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sysml', default='sysml')
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--replay', type=Path)
    args = parser.parse_args()
    model = Path(__file__).with_name('11-eager-propagation.sysml')
    version = subprocess.run([args.sysml, '-version'], text=True, capture_output=True, timeout=10, check=True).stdout.strip()
    artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix='context-push-sysml-', dir='/private/tmp'))
    artifacts.mkdir(parents=True, exist_ok=True)
    jobs = [(complete, fail, mode) for mode in range(5) for complete, fail in itertools.product((False, True), repeat=2)]
    if args.replay:
        saved = json.loads(args.replay.read_text())
        if saved['model_sha256'] != sha(model):
            raise RuntimeError('Saved eager propagation model cut is stale')
        if saved.get('kind') == 'frozen-parent':
            summary = frozen_parent(args.sysml, model, artifacts, version)
            (artifacts / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
            print(f'PASS: exact frozen-parent unsafe/safe replay; {artifacts}')
            return
        complete, fail, mode = saved['inputs']
        jobs = [(complete, fail, mode), (complete, fail, 0)]
    subjects = [f'ContextEagerPropagation::Propagate({str(c).lower()},{str(f).lower()},{m})' for c, f, m in jobs]
    command = [args.sysml, '-strict', '-no-record-cache', str(model), '-engine', 'run', '-json']
    for subject in subjects:
        command += ['-analysis', subject]
    result = subprocess.run(command, text=True, capture_output=True, timeout=45)
    (artifacts / 'sysml.json').write_text(result.stdout)
    (artifacts / 'stderr.txt').write_text(result.stderr)
    data = json.loads(result.stdout)
    checks = data.get('checks') or []
    if data.get('errors') or data.get('diagnostics') or len(checks) != len(jobs):
        raise RuntimeError('Incomplete/error SysML execution')
    counts = {mode: 0 for mode in range(5)}
    witnesses = set()
    for (complete, fail, mode), subject, check in zip(jobs, subjects, checks):
        expected_fail = complete and mode != 0
        values = {row['name']: row['value'] for row in check.get('values') or []}
        verifications = check.get('verifications') or []
        evidence = check.get('results') or []
        if (check.get('subject') != subject or check.get('status') != ('fails' if expected_fail else 'holds')
                or values.get('processed') != '6' or values.get('retained') != 'true'
                or values.get('publishedSource') != str(complete).lower()
                or values.get('verdict') != ('VerdictKind::fail' if expected_fail else 'VerdictKind::pass')
                or len(verifications) != 1 or verifications[0].get('kind') != ('fail' if expected_fail else 'pass')
                or len(evidence) != 1 or evidence[0].get('engine') != 'run'
                or evidence[0].get('claim') != ('violated' if expected_fail else 'holds')
                or any(bound.get('reached') for ev in evidence for bound in ev.get('bounds', []))):
            raise RuntimeError(f'Wrong/missing executed verdict for {subject}')
        counts[mode] += int(expected_fail)
        if expected_fail and mode not in witnesses:
            witnesses.add(mode)
            witness = {'schema': 'context.eager-counterexample.v1', 'inputs': [complete, fail, mode],
                       'model_sha256': sha(model), 'tool': version, 'values': values}
            (artifacts / f'counterexample-{mode}.json').write_text(json.dumps(witness, indent=2) + '\n')
    if result.returncode != int(any(counts.values())):
        raise RuntimeError('CLI exit/verdict mismatch')
    if (not args.replay and counts != {0: 0, 1: 2, 2: 2, 3: 2, 4: 2}) or (args.replay and sum(counts.values()) != 1):
        raise RuntimeError(f'Wrong eager scenario coverage: {counts}')
    extra = frozen_parent(args.sysml, model, artifacts, version) if not args.replay else {'executed': 0}
    summary = {'schema': 'context.eager-execution.v1', 'executed': len(jobs) + extra['executed'], 'frozen_parent': extra, 'expected_failures': counts,
               'model_sha256': sha(model), 'runner_sha256': sha(Path(__file__)), 'tool': version}
    (artifacts / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f'PASS: {len(jobs) + extra["executed"]} eager propagation executions; expected failures {counts}; {artifacts}')


if __name__ == '__main__':
    main()
