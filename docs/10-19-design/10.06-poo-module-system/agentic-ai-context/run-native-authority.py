#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Actual native grant/policy/deadline publication, three-consumer replay gate."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('push_gate', HERE / 'run-native-push.py')
push = importlib.util.module_from_spec(spec)
spec.loader.exec_module(push)
base = push.base
ROOT = HERE.parents[3]
INPUTS = tuple(dict.fromkeys((*push.INPUTS,
    'modules/ai-agentic-context/use-host.ss',
    'modules/temporal-causality/runtime/change-feed.ss',
    'modules/temporal-causality/truth-maintenance/support/policy.ss',
    str(Path(__file__).resolve().relative_to(ROOT)))))
KINDS = ('grant', 'policy', 'expiry')


def dependency_artifacts():
    paths = sorted(p for owner in ('gerbil-ascent', 'orgize')
                   for p in (ROOT / '.gerbil/lib' / owner).rglob('*')
                   if p.is_file() and (p.suffix in ('.o1', '.ssi') or p.name.endswith('.ssxi.ss')))
    if not paths or not any('gerbil-ascent/' in str(p) for p in paths) or not any('orgize/' in str(p) for p in paths):
        raise RuntimeError('Missing native dependency artifacts')
    return {str(p.relative_to(ROOT)): base.sha(p) for p in paths}


def inspect(log, exitcode, orders):
    regression = push.inspect(ROOT, log, exitcode, push.DEFAULT)
    text = re.sub(r'\n@yuanxu-progress \[\"[^\"\n]+\",[0-9]+\]\n', '', log.read_text())
    rows = text.splitlines()
    paths, begins, evidence = [], [], []
    for line in rows:
        if line.startswith('NATIVE-AUTHORITY-BEGIN '):
            m = re.fullmatch(r'NATIVE-AUTHORITY-BEGIN kind=(grant|policy|expiry) order=\(([1-7 ]+)\)', line)
            if not m:
                raise RuntimeError('Malformed authority begin')
            begins.append((m[1], tuple(map(int, m[2].split()))))
        elif line.startswith('NATIVE-AUTHORITY-PATH '):
            m = re.fullmatch(r'NATIVE-AUTHORITY-PATH kind=(grant|policy|expiry) order=\(([1-7 ]+)\) a=(completed|cancelled|pending) b=reconciled c=completed current-a=#f current-b=#f unaffected=#t', line)
            if not m:
                raise RuntimeError('Malformed authority actual result')
            kind, order, outcome = m.groups()
            order = tuple(map(int, order.split()))
            expected = 'completed' if order.index(3) < min(order.index(4), order.index(5), order.index(7)) else 'cancelled' if order.index(6) < order.index(7) else 'pending'
            # Completion can also lose to recovery even if cancellation has not
            # happened; the formula above mirrors publication prerequisites.
            if outcome != expected:
                raise RuntimeError(f'Unexpected actual terminal {kind} {order}: {outcome}, expected {expected}')
            paths.append({'kind': kind, 'order': list(order), 'a': outcome, 'b': 'reconciled', 'c': 'completed'})
        elif line.startswith('NATIVE-AUTHORITY-EVIDENCE '):
            m = re.fullmatch(r'NATIVE-AUTHORITY-EVIDENCE kind=(grant|policy|expiry) event=(sha256:[0-9a-f]{64}) context-index=(sha256:[0-9a-f]{64}) original-journal=(sha256:[0-9a-f]{64}) original-proof=(sha256:[0-9a-f]{64})', line)
            if not m:
                raise RuntimeError('Missing original native proof/journal/index commitments')
            evidence.append(dict(zip(('kind', 'event', 'context_index', 'original_journal', 'original_proof'), m.groups())))
    expected = [(kind, tuple(order)) for kind in KINDS for order in orders]
    if begins != expected or [(p['kind'], tuple(p['order'])) for p in paths] != expected or len(evidence) != len(expected):
        raise RuntimeError('Authority path corpus incomplete, duplicated or reordered')
    if [e['kind'] for e in evidence] != [k for k, _ in expected]:
        raise RuntimeError('Authority evidence order mismatch')
    controls = [r for r in rows if r.startswith('NATIVE-AUTHORITY-COUNTEREXAMPLE ')]
    retries = [r for r in rows if r.startswith('NATIVE-AUTHORITY-RETRY ')]
    if controls != [f'NATIVE-AUTHORITY-COUNTEREXAMPLE kind={k} cached-admitted=#t active-after-change=#t final-guard-denies=#t' for k in KINDS]:
        raise RuntimeError('Missing native no-subscription counterexamples')
    if retries != [f'NATIVE-AUTHORITY-RETRY kind={k} preflight-atomic=#t pending-blocks=#t terminal-preserved=#t unaffected=completed' for k in KINDS]:
        raise RuntimeError('Missing failed-delivery/cancellation retries')
    if [r for r in rows if r.startswith('NATIVE-AUTHORITY-OBSERVE ')] != [f'NATIVE-AUTHORITY-OBSERVE paths={len(expected)} duplicate-terminals=0 stale-reactivations=0 unaffected-failures=0']:
        raise RuntimeError('Missing native authority completion verdict')
    return {'regression': regression, 'paths': paths, 'evidence': evidence, 'counterexamples': controls, 'retries': retries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--check-receipt', type=Path)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--exhaustive', action='store_true')
    group.add_argument('--order')
    args = parser.parse_args()
    if args.check_receipt:
        path = args.check_receipt
        receipt = json.loads(path.read_text())
        if (set(receipt['source_sha256']) != set(INPUTS)
                or any(base.sha(ROOT / p) != h for p, h in receipt['source_sha256'].items())
                or receipt['ascent_head'] != base.ascent_revision(ROOT)
                or receipt['orgize_head'] != base.orgize_revision(ROOT)
                or receipt['dependency_artifacts'] != dependency_artifacts()):
            raise RuntimeError('Saved native authority cut is stale')
        for name in ('native.log', 'build.log', 'paths.json'):
            if base.sha(path.parent / name) != receipt['artifacts'][name]:
                raise RuntimeError('Authority artifact commitment mismatch')
        orders = [tuple(x) for x in receipt['orders']]
        expected = push.ALL if receipt['mode'] == 'exhaustive' else orders if receipt['mode'] == 'replay' else push.DEFAULT
        if orders != expected or not all(push.legal(x) for x in orders) or len(set(orders)) != len(orders):
            raise RuntimeError('Invalid authority corpus')
        actual = inspect(path.parent / 'native.log', receipt['native_exit'], orders)
        if actual != receipt['execution'] or json.loads((path.parent / 'paths.json').read_text()) != actual['paths']:
            raise RuntimeError('Authority receipt disagrees with native evidence')
        print(f'CURRENT AUTHORITY RECEIPT: {len(actual["paths"])} native paths; {path}')
        return
    orders = push.ALL if args.exhaustive else push.DEFAULT
    if args.order:
        orders = [tuple(map(int, args.order.split(',')))]
        if not push.legal(orders[0]):
            raise RuntimeError('Illegal authority replay')
    artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix='context-authority-', dir='/private/tmp'))
    artifacts.mkdir(parents=True, exist_ok=True)
    before = {p: base.sha(ROOT / p) for p in INPUTS}
    ascent, orgize = base.ascent_revision(ROOT), base.orgize_revision(ROOT)
    env = os.environ.copy()
    for name in tuple(env):
        if name.startswith('AGENTIC_CONTEXT_'):
            env.pop(name)
    env.update(GERBIL_PATH=str(ROOT / '.gerbil'), GERBIL_LOADPATH=f'{ROOT}:{ROOT}/.gerbil/lib:{ROOT}/dev/.gerbil/lib')
    if args.order:
        env['AGENTIC_CONTEXT_AUTHORITY_ORDER'] = '(' + ' '.join(map(str, orders[0])) + ')'
    with (artifacts / 'build.log').open('w') as output:
        subprocess.run(['just', 'build-library'], cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=600, check=True)
    binaries = dependency_artifacts()
    with (artifacts / 'native.log').open('w') as output:
        result = subprocess.run(['just', 'test-context-authority' if args.exhaustive else 'test-context-authority-focused'], cwd=ROOT,
            env=env, stdout=output, stderr=subprocess.STDOUT, timeout=2715 if args.exhaustive else 915)
    if (base.ascent_revision(ROOT) != ascent or base.orgize_revision(ROOT) != orgize or any(base.sha(ROOT / p) != h for p, h in before.items())
            or dependency_artifacts() != binaries):
        raise RuntimeError('Runtime/dependency changed during execution; unqualified logs retained')
    actual = inspect(artifacts / 'native.log', result.returncode, orders)
    (artifacts / 'paths.json').write_text(json.dumps(actual['paths'], indent=2) + '\n')
    receipt = {'schema': 'context.native-authority.v1', 'mode': 'exhaustive' if args.exhaustive else 'replay' if args.order else 'focused',
        'orders': orders, 'native_exit': result.returncode, 'source_sha256': before, 'ascent_head': ascent, 'orgize_head': orgize,
        'execution': actual, 'dependency_artifacts': binaries, 'artifacts': {p: base.sha(artifacts / p) for p in ('native.log', 'build.log', 'paths.json')},
        'scope': {'owner_local': True, 'materialized_before_queries': True, 'original_evidence_retained': True,
                  'all_seven_event_linear_extensions_per_kind': args.exhaustive, 'all_joint_two_attempt_orders': False,
                  'autonomous_wall_clock_scheduler': False, 'distributed_durability': False}}
    path = artifacts / 'authority-receipt.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(f'PASS: {actual["regression"]["case_count"]} native Cases, {len(actual["paths"])} authority paths; {path}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, KeyError, subprocess.SubprocessError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
