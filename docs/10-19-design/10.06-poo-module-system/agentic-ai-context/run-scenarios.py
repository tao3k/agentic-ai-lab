#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Execute SysML verification verdicts and literal outcome expectations.

The Python runner orchestrates sysml and checks its results; all domain state
transitions and verdict predicates execute in SysML. Raw outputs stay in /tmp.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sysml', default='sysml')
    parser.add_argument('--artifacts', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix='context-sysml-', dir='/private/tmp'))
    artifacts.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((root / '04-scenario-expectations.json').read_text())
    names = [case['case'] for case in manifest['cases']]
    modeled = re.findall(r'^    verification (\w+) :', (root / '04-executable-scenarios.sysml').read_text(), re.M)
    if len(names) != len(set(names)) or set(modeled) != set(names):
        raise RuntimeError('Manifest must enumerate every modeled verification usage exactly once')
    version = subprocess.run([args.sysml, '-version'], text=True, capture_output=True, timeout=15, check=True)
    (artifacts / 'tool-version.txt').write_text(version.stdout + version.stderr)
    prefix = [args.sysml, '-strict', '-no-record-cache', str(root)]
    validation = subprocess.run(prefix + ['-validate', '-self-check'], text=True, capture_output=True, timeout=30)
    (artifacts / 'validation.txt').write_text(validation.stdout + validation.stderr)
    if validation.returncode:
        raise RuntimeError(f'Model validation failed; see {artifacts}')
    summary = {'tool': version.stdout.strip(), 'artifacts': str(artifacts), 'runs': [], 'failures': []}
    for case in manifest['cases']:
        for schedule in manifest['schedules']:
            qname = manifest['package'] + '::' + case['case']
            command = prefix + ['-engine', 'run', '-schedule', schedule, '-analysis', qname, '-json']
            result = subprocess.run(command, text=True, capture_output=True, timeout=20)
            stem = case['case'] + '-' + schedule
            (artifacts / (stem + '.json')).write_text(result.stdout)
            (artifacts / (stem + '.stderr.txt')).write_text(result.stderr)
            errors = []
            try:
                data = json.loads(result.stdout)
                expected = case['expected_verdict']
                expected_status = 'holds' if expected == 'pass' else 'fails'
                expected_code = 0 if expected == 'pass' else 1
                checks = data.get('checks') or []
                if result.returncode != expected_code or data.get('exit') != expected_code or data.get('status') != expected_status:
                    errors.append('unexpected exit/status')
                if data.get('diagnostics') or data.get('errors'):
                    errors.append('diagnostics/errors present')
                if len(checks) != 1:
                    errors.append('missing or multiple verification results')
                check = checks[0] if len(checks) == 1 else {}
                if check.get('subject') != qname or check.get('status') != expected_status:
                    errors.append('wrong check subject/status')
                verifications = check.get('verifications') or []
                if len(verifications) != 1 or verifications[0].get('kind') != expected or verifications[0].get('case') != qname:
                    errors.append('missing/wrong explicit verification verdict')
                values = {v['name']: v['value'] for v in check.get('values') or []}
                expected_values = dict(case['expected_outputs'], verdict='VerdictKind::' + expected)
                if values != expected_values:
                    errors.append(f'outcome mismatch: {values!r} != {expected_values!r}')
                evidence = check.get('results') or []
                if len(evidence) != 1 or evidence[0].get('engine') != 'run' or evidence[0].get('claim') != ('holds' if expected == 'pass' else 'violated'):
                    errors.append('verification did not execute through the run engine')
                if any(bound.get('reached') for ev in evidence for bound in ev.get('bounds', [])):
                    errors.append('execution bound reached')
                if expected == 'fail' and not evidence[0].get('witness'):
                    errors.append('counterexample lacks execution witness')
            except (ValueError, KeyError, IndexError, TypeError) as error:
                errors.append(f'invalid CLI result: {error}')
                values = {}
            row = {'case': case['case'], 'schedule': schedule, 'expected': case['expected_verdict'], 'exit': result.returncode, 'values': values, 'matched': not errors}
            summary['runs'].append(row)
            if errors:
                summary['failures'].append(dict(row, errors=errors))
            label = 'COUNTEREXAMPLE' if case['expected_verdict'] == 'fail' else 'SCENARIO'
            print(f'{"OK" if not errors else "FAIL"} {label} {stem}', flush=True)
    (artifacts / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f'{len(summary["runs"])} executions; {len(summary["failures"])} mismatches; artifacts: {artifacts}')
    return bool(summary['failures'])


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(2)
