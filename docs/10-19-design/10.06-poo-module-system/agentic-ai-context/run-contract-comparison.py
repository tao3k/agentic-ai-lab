#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute 80 SysML contract-omission scenarios. These are not paper replicas."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import subprocess
import tempfile

MODES = {0: 'safe', 1: 'archive-is-current', 2: 'candidate-revision-only',
         3: 'editable-view-is-authority', 4: 'content-transfers-consumer-and-attempt'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sysml', default='sysml')
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--replay', type=Path)
    args = parser.parse_args()
    version = subprocess.run([args.sysml, '-version'], text=True, capture_output=True, timeout=10, check=True).stdout.strip()
    model = Path(__file__).with_name('10-evidence-contract-comparison.sysml')
    artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix='context-contract-comparison-', dir='/private/tmp'))
    artifacts.mkdir(parents=True, exist_ok=True)
    jobs = [(bits, mode) for mode in MODES for bits in itertools.product((False, True), repeat=4)]
    if args.replay:
        replay = json.loads(args.replay.read_text())
        if replay['model_sha256'] != hashlib.sha256(model.read_bytes()).hexdigest():
            raise RuntimeError('Saved comparison model cut is stale')
        jobs = [(tuple(replay['inputs']), replay['mode']), (tuple(replay['inputs']), 0)]
    command = [args.sysml, '-strict', '-no-record-cache', str(model), '-engine', 'run', '-json']
    for bits, mode in jobs:
        command += ['-analysis', 'ContextContractComparison::EvidenceUse(' + ','.join(
            [str(bit).lower() for bit in bits] + [str(mode)]) + ')']
    result = subprocess.run(command, text=True, capture_output=True, timeout=45)
    (artifacts / 'sysml.json').write_text(result.stdout)
    (artifacts / 'sysml.stderr.txt').write_text(result.stderr)
    data = json.loads(result.stdout)
    checks = data.get('checks') or []
    if data.get('errors') or data.get('diagnostics') or len(checks) != len(jobs):
        raise RuntimeError('Missing or invalid executed SysML checks')
    failures = {mode: 0 for mode in MODES}
    witnesses = {}
    for (bits, mode), check in zip(jobs, checks):
        expected_subject = 'ContextContractComparison::EvidenceUse(' + ','.join([str(bit).lower() for bit in bits] + [str(mode)]) + ')'
        values = {row['name']: row['value'] for row in check.get('values') or []}
        accepted = values.get('accepted') == 'true'
        failed = accepted and any(bits)
        verification = check.get('verifications') or []
        evidence = check.get('results') or []
        if (check.get('subject') != expected_subject or values.get('historyRetained') != 'true' or values.get('revisionUnchanged') != 'true'
                or values.get('processed') != '4' or values.get('terminalCount') != str(int(accepted))
                or values.get('verdict') != ('VerdictKind::fail' if failed else 'VerdictKind::pass')
                or check.get('status') != ('fails' if failed else 'holds')
                or len(verification) != 1 or verification[0].get('kind') != ('fail' if failed else 'pass')
                or len(evidence) != 1 or evidence[0].get('engine') != 'run'
                or evidence[0].get('claim') != ('violated' if failed else 'holds')
                or any(bound.get('reached') for ev in evidence for bound in ev.get('bounds', []))):
            raise RuntimeError(f'Missing/wrong execution verdict: {mode}, {bits}')
        if mode == 0 and accepted != (not any(bits)):
            raise RuntimeError('Safe positive/refusal coverage mismatch')
        failures[mode] += int(failed)
        if failed and mode not in witnesses:
            witness = {'schema': 'context.contract-counterexample.v1', 'mode': mode,
                       'ablation': MODES[mode], 'inputs': bits, 'values': values,
                       'model_sha256': hashlib.sha256(model.read_bytes()).hexdigest(),
                       'not_a_paper_implementation': True, 'tool': version}
            witnesses[mode] = witness
            (artifacts / f'counterexample-{mode}.json').write_text(json.dumps(witness, indent=2) + '\n')
    if result.returncode != int(any(failures.values())):
        raise RuntimeError('CLI exit contradicts executed verdicts')
    if not args.replay and failures != {0: 0, 1: 15, 2: 3, 3: 15, 4: 3}:
        raise RuntimeError(f'Unexpected omission counterexample coverage: {failures}')
    if args.replay and (sum(failures.values()) != 1 or failures[0] != 0):
        raise RuntimeError('Saved unsafe path or safe counterpart did not reproduce')
    summary = {'schema': 'context.contract-comparison.v1', 'executed': len(jobs),
               'counterexamples_by_mode': failures, 'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), 'tool': version, 'model_sha256': hashlib.sha256(model.read_bytes()).hexdigest(),
               'not_a_paper_implementation': True, 'tool': version}
    (artifacts / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f'PASS: {len(jobs)} executed scenarios; expected unsafe failures {failures}; {artifacts}')


if __name__ == '__main__':
    main()
