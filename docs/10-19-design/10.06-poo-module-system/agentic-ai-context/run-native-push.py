#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Native eager propagation qualification; all seven-event paths or exact replay."""
import argparse
from collections import Counter
import importlib.util
import itertools
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

BASE_PATH = Path(__file__).with_name('run-native-replay.py')
spec = importlib.util.spec_from_file_location('native_owner_gate', BASE_PATH)
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
INPUTS = tuple(dict.fromkeys((*base.INPUTS,
    'modules/temporal-causality/truth-maintenance/funs.ss',
    'modules/temporal-causality/truth-maintenance/objects.ss',
    str(BASE_PATH.resolve().relative_to(BASE_PATH.resolve().parents[4])),
    str(Path(__file__).resolve().relative_to(BASE_PATH.resolve().parents[4])))))


def legal(order):
    return sorted(order) == list(range(1, 8)) and all(order.index(a) < order.index(b)
        for a, b in ((1, 2), (2, 3), (5, 6), (5, 7)))


ALL = [order for order in itertools.permutations(range(1, 8)) if legal(order)]
DEFAULT = [ALL[n] for n in (0, 40, 80, 120, 160, 200, 240, 279)]


def inspect(root, log, native_exit, orders):
    count, legacy_observations, legacy_controls, legacy_paths = base.inspect(root, log, native_exit, base.DEFAULT_ORDERS)
    text = re.sub(r'\n@yuanxu-progress \[\"[^\"\n]+\",[0-9]+\]\n', '', log.read_text())
    lines = text.splitlines()
    expected = [
        'NATIVE-PUSH-OBSERVE selective direct=invalidated dependent=invalidated unaffected=completed cached-before-query=#t history-retained=#t replay-idempotent=#t',
        'NATIVE-PUSH-OBSERVE retry preflight-atomic=#t pending-blocks-result=#t cancelled-terminal-preserved=#t unaffected=completed duplicate-delivery=#f',
        'NATIVE-PUSH-OBSERVE enrollment failure-atomic=#t unobserved-input-published=#f',
        'NATIVE-PUSH-OBSERVE enable-retained historical-source-discovered=#t affected-only-dependent=#t unaffected=completed',
        'NATIVE-PUSH-OBSERVE multi-source pending-dependency-blocks=#t own-proof-stays-current=#t cached-delivered=#t history-unusable=#t',
        'NATIVE-PUSH-OBSERVE frozen-parent old-version-invalidated=#t replacement-unaffected=#t dependent-invalidated=#t rebased-dependent=#t old-result-reactivated=#f',
        'NATIVE-PUSH-OBSERVE cross-session paths=6 asymmetric=2 all-unaffected=completed',
        f'NATIVE-PUSH-OBSERVE interleavings paths={len(orders)} duplicate-terminals=0 stale-reactivations=0 unaffected-failures=0',
    ]
    observed = [line for line in lines if line.startswith('NATIVE-PUSH-OBSERVE ')]
    controls = [line for line in lines if line.startswith('NATIVE-PUSH-COUNTEREXAMPLE ')]
    if observed != expected or controls != ['NATIVE-PUSH-COUNTEREXAMPLE no-subscription cached-admitted=#t active-after-withdrawal=#t automatic-invalidation=#f']:
        raise RuntimeError('Missing or wrong actual native push/selectivity/retry/counterexample observations')
    oracle_rows = [line for line in lines if line.startswith('NATIVE-PUSH-ORACLE ')]
    if oracle_rows != ['NATIVE-PUSH-ORACLE withdrawn-a-rows=0 unaffected-c-equal=#t active-facts=1 native-status=complete']:
        raise RuntimeError('Missing independent current-fact ASCENT query oracle')
    evidence_rows = [line for line in lines if line.startswith('NATIVE-PUSH-EVIDENCE ')]
    if len(evidence_rows) != 1:
        raise RuntimeError('Missing native proof/index/journal evidence commitments')
    evidence = dict(field.split('=', 1) for field in evidence_rows[0].split()[1:])
    if set(evidence) != {'event', 'proof-index', 'context-index', 'previous-journal', 'revised-journal', 'ascent-a', 'registered-a', 'registered-c'} or not all(re.fullmatch(r'sha256:[0-9a-f]{64}', value) for value in evidence.values()) or evidence['previous-journal'] == evidence['revised-journal']:
        raise RuntimeError('Wrong native evidence/index/journal bindings')
    cross = []
    for line in lines:
        if not line.startswith('NATIVE-PUSH-CROSS '):
            continue
        match = re.fullmatch(r'NATIVE-PUSH-CROSS order=\(([1-3 ]+)\) a=(completed|reconciled) b=(completed|reconciled) c=completed', line)
        if not match:
            raise RuntimeError('Wrong independent cross-Session commit verdict')
        order, a, b = match.groups()
        order = tuple(int(x) for x in order.split())
        if sorted(order) != [1, 2, 3] or a != ('completed' if order.index(1) < order.index(3) else 'reconciled') or b != ('completed' if order.index(2) < order.index(3) else 'reconciled'):
            raise RuntimeError('Cross-Session commit did not follow its actual source order')
        cross.append({'order': list(order), 'a': a, 'b': b, 'c': 'completed'})
    if [tuple(row['order']) for row in cross] != list(itertools.permutations(range(1, 4))):
        raise RuntimeError('Missing independent cross-Session source/result interleavings')
    paths, begins = [], []
    for line in lines:
        if line.startswith('NATIVE-PUSH-BEGIN '):
            match = re.fullmatch(r'NATIVE-PUSH-BEGIN order=\(([1-7 ]+)\)', line)
            if not match:
                raise RuntimeError('Malformed native path begin')
            begins.append(tuple(int(x) for x in match.group(1).split()))
        if not line.startswith('NATIVE-PUSH-PATH '):
            continue
        match = re.fullmatch(r'NATIVE-PUSH-PATH order=\(([1-7 ]+)\) a=(completed|cancelled|reconciled|pending) b=(completed|cancelled|reconciled|pending) c=completed current-a=#f current-b=#f unaffected=#t', line)
        if not match:
            raise RuntimeError(f'Wrong native push verdict: {line}')
        order, a, b = match.groups()
        paths.append({'order': [int(x) for x in order.split()], 'a': a, 'b': b,
                      'c': 'completed', 'current_a': False, 'current_b': False, 'unaffected_current': True})
    if begins != orders or [tuple(path['order']) for path in paths] != orders:
        raise RuntimeError('Native eager path coverage/order mismatch')
    return {'case_count': count, 'observations': observed, 'counterexample': controls,
            'evidence': evidence, 'current_ascent_oracle': oracle_rows, 'paths': paths, 'cross_session_paths': cross, 'legacy_paths': legacy_paths,
            'legacy_observations': legacy_observations, 'legacy_controls': legacy_controls}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--check-receipt', type=Path)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--exhaustive', action='store_true')
    group.add_argument('--order')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[4]
    if args.check_receipt:
        receipt = json.loads(args.check_receipt.read_text())
        if (receipt['ascent_head'] != base.ascent_revision(root) or receipt['orgize_head'] != base.orgize_revision(root)
                or set(receipt['source_sha256']) != set(INPUTS)
                or any(base.sha(root / name) != value for name, value in receipt['source_sha256'].items())):
            raise RuntimeError('Saved eager native runtime/dependency cut is stale')
        for name in ('log', 'build_log', 'path_file'):
            if base.sha(args.check_receipt.parent / receipt[name]) != receipt[name + '_sha256']:
                raise RuntimeError('Saved eager native artifact commitment mismatch')
        orders = [tuple(path['order']) for path in receipt['execution']['paths']]
        expected = ALL if receipt['mode'] == 'exhaustive' else orders if receipt['mode'] == 'replay' else DEFAULT
        if orders != expected or not all(legal(order) for order in orders) or len(set(orders)) != len(orders):
            raise RuntimeError('Wrong saved eager path corpus')
        actual = inspect(root, args.check_receipt.parent / receipt['log'], receipt['native_exit'], orders)
        if actual != receipt['execution'] or json.loads((args.check_receipt.parent / receipt['path_file']).read_text()) != actual['paths']:
            raise RuntimeError('Saved eager receipt/native execution mismatch')
        print(f'CURRENT PUSH RECEIPT: {actual["case_count"]} Cases, {len(orders)} eager paths; {args.check_receipt}')
        return
    orders = ALL if args.exhaustive else DEFAULT
    if args.order:
        orders = [tuple(int(x) for x in args.order.split(','))]
        if not legal(orders[0]):
            raise RuntimeError('Illegal seven-event eager replay order')
    artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix='context-native-push-', dir='/private/tmp'))
    artifacts.mkdir(parents=True, exist_ok=True)
    before = {name: base.sha(root / name) for name in INPUTS}
    ascent, orgize = base.ascent_revision(root), base.orgize_revision(root)
    env = os.environ.copy()
    for name in ('AGENTIC_CONTEXT_NATIVE_CAS_EXHAUSTIVE', 'AGENTIC_CONTEXT_NATIVE_CAS_ORDER',
                 'AGENTIC_CONTEXT_PUSH_EXHAUSTIVE', 'AGENTIC_CONTEXT_PUSH_ORDER'):
        env.pop(name, None)
    env.update(GERBIL_PATH=str(root / '.gerbil'), GERBIL_LOADPATH=f'{root}:{root}/.gerbil/lib:{root}/dev/.gerbil/lib')
    if args.order:
        env['AGENTIC_CONTEXT_PUSH_ORDER'] = '(' + ' '.join(map(str, orders[0])) + ')'
    build = artifacts / 'build.log'
    with build.open('w') as output:
        subprocess.run(['just', 'build-library'], cwd=root, env=env, stdout=output,
                       stderr=subprocess.STDOUT, timeout=180, check=True)
    log = artifacts / 'native.log'
    command = ['just', 'test-context-push' if args.exhaustive else 'test-context-evidence-native']
    with log.open('w') as output:
        result = subprocess.run(command, cwd=root, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=915 if args.exhaustive else 135)
    if (base.ascent_revision(root) != ascent or base.orgize_revision(root) != orgize
            or any(base.sha(root / name) != value for name, value in before.items())):
        raise RuntimeError('Runtime/dependency cut changed; retain logs without eager qualification')
    actual = inspect(root, log, result.returncode, orders)
    path_file = artifacts / 'push-paths.json'
    path_file.write_text(json.dumps(actual['paths'], indent=2) + '\n')
    receipt = {'schema': 'context.native-eager.v1', 'mode': 'exhaustive' if args.exhaustive else 'replay' if args.order else 'focused',
               'command': command, 'native_exit': result.returncode, 'source_sha256': before,
               'ascent_head': ascent, 'orgize_head': orgize, 'execution': actual,
               'outcomes_a': dict(Counter(path['a'] for path in actual['paths'])),
               'outcomes_b': dict(Counter(path['b'] for path in actual['paths'])),
               'log': log.name, 'log_sha256': base.sha(log), 'build_log': build.name, 'build_log_sha256': base.sha(build),
               'path_file': path_file.name, 'path_file_sha256': base.sha(path_file),
               'scope': {'source_owner_push': True, 'native_reverse_dependency_graph': True,
                         'three_native_consumer_attempts': True, 'cross_session_commit_orders': 6,
                         'exhaustive_all_two_attempt_joint_schedules': False, 'materialized_before_queries': True,
                         'unaffected_native_result': True, 'durable_distributed_atomicity': False,
                         'arbitrary_query_negative_dependency_coverage': False, 'source_authentication': False}}
    path = artifacts / 'push-receipt.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(f'PASS: {actual["case_count"]} Cases, {len(orders)} eager paths, {len(actual["legacy_paths"])} legacy paths; {path}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, KeyError, subprocess.SubprocessError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
