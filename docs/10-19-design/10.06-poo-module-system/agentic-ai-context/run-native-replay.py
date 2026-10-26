#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Replay real ASCENT/Scheme owner publication through heap-fenced Just recipes.

Receipts commit to local execution inputs/logs; they are not authentication or
permission. --order replays a saved eight-event native path (e.g. '1,2,4,3,5,6,7,8').
"""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

INPUTS = (
    't/temporal-evaluator-test.ss', 't/harness/temporal-evaluator-runner.ss',
    'dev/just/runtime-tests.just', 'dev/just/build.just',
    't/qualification/testing/specialized.ss', 'gerbil.pkg',
    'modules/temporal-causality/evaluator/positive-proof.ss',
    'modules/temporal-causality/evaluator/derivation.ss',
    'modules/temporal-causality/evaluator/proof-host.ss',
    'modules/temporal-causality/revisions/funs.ss',
    'modules/temporal-causality/truth-maintenance/support/funs.ss',
    'modules/temporal-causality/truth-maintenance/support/policy-host.ss',
    'modules/ai-agentic-context/session-host.ss', 'modules/session/funs-attempt.ss',
    't/qualification/temporal-library-basic/rule-correspondence-v1/typed-rules.ss',
    't/qualification/temporal-library-basic/derivation-authority-v1/typed-derivations.ss',
)
BAD = r'ERROR CASE|ERROR CHECK|ERROR HARNESS|ERROR MODULE|Heap overflow|Stack overflow'
MARKERS = ('MODULE-OK t/temporal-evaluator-test.ss',
           'HARNESS-OK ("t/temporal-evaluator-test.ss")', 'OK')
DEFAULT_ORDERS = [(1, 2, 3, 4, 5, 6, 7, 8), (1, 2, 4, 3, 5, 6, 7, 8),
                  (6, 7, 8, 1, 2, 3, 4, 5), (6, 8, 1, 2, 3, 4, 5, 7),
                  (4, 1, 2, 3, 5, 6, 7, 8), (5, 1, 2, 3, 4, 6, 7, 8),
                  (1, 2, 6, 3, 7, 4, 5, 8), (1, 6, 8, 2, 4, 3, 7, 5)]


def legal(order):
    return sorted(order) == list(range(1, 9)) and all(order.index(a) < order.index(b)
        for a, b in ((1, 2), (2, 3), (6, 7), (6, 8)))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inspect(root, log, exit_code, orders):
    text = log.read_text()
    # Ops writes structured stderr progress into merged stdout, sometimes inside
    # a buffered path row. Remove only its exact framing, retaining raw log hash.
    text = re.sub(r'\n@yuanxu-progress \[\"[^\"\n]+\",[0-9]+\]\n', '', text)
    lines = text.splitlines()
    count = len(re.findall(r'\(yuanxu-test-case(?:/with)?\b', (root / INPUTS[0]).read_text()))
    expected = {
        'NATIVE-CONTEXT-OBSERVE withdrawal': {'before': 'current', 'after': 'unsupported', 'proof-retained': '#t'},
        'NATIVE-CONTEXT-OBSERVE current-result': {'eligible': '#t', 'completion-intent': '#t',
                           'runtime-published': '#f', 'repeated-completion': '#f'},
        'NATIVE-CONTEXT-OBSERVE cancellation': {'pending': '1', 'late-completion': '#f', 'completed-identities': '1',
                         'reconciliation-published': '#f', 'closed-recovery': 'closed'},
        'NATIVE-CAS-OBSERVE result': {'published': '#t', 'terminals': '1', 'duplicate': '#f', 'proof-bound': '#t'},
        'NATIVE-CAS-OBSERVE withdrawal': {'stale-commit': '#f', 'historical-retained': '#t', 'reactivated': '#f'},
        'NATIVE-CAS-OBSERVE cancellation': {'terminal': 'cancelled', 'late-result': '#f', 'duplicate': '#f', 'closed-resume': '#f'},
        'NATIVE-CAS-OBSERVE interleavings': {'paths': str(len(orders)), 'terminal-violations': '0', 'stale-reactivations': '0'},
        'NATIVE-COMPARISON archive': {'history': '#t', 'revision-same': '#t', 'proof-current': '#f', 'native-result': '#f', 'cleanup': 'reconciled'},
        'NATIVE-COMPARISON editable-view': {'forged-observation': '#f', 'revoked-result': '#f', 'cleanup': '#t'},
        'NATIVE-COMPARISON recall': {'borrowed-grant': '#f', 'foreign-receipt': '#f', 'fresh-consumer': '#t', 'sessions-independent': '#t', 'withdrawn-both': '#t'},
        'NATIVE-COMPARISON rebind': {'equal-proof': '#t', 'changed-owner': '#t', 'old-current': '#f', 'old-recommit': '#f', 'fresh-attempt': '#t'},
    }
    observations = [line for line in lines if line.startswith(('NATIVE-CONTEXT-OBSERVE ', 'NATIVE-CAS-OBSERVE ', 'NATIVE-COMPARISON '))]
    if exit_code != 0 or re.search(BAD, text) or not all(marker in lines for marker in MARKERS):
        raise RuntimeError('Native exit/required marker/failure marker gate failed')
    if len(re.findall(r'^CASE-OK ', text, re.M)) != count or len(observations) != len(expected):
        raise RuntimeError('Native Case count or observed scenario coverage mismatch')
    seen = set()
    for line in observations:
        prefix, scenario, *fields = line.split()
        key = prefix + ' ' + scenario
        values = dict(field.split('=', 1) for field in fields)
        if key not in expected or key in seen or any(values.get(k) != v for k, v in expected[key].items()):
            raise RuntimeError(f'Native observation mismatch: {line}')
        if key == 'NATIVE-CONTEXT-OBSERVE withdrawal' and not all(re.fullmatch(r'sha256:[0-9a-f]{64}', values.get(k, '')) for k in ('proof', 'journal')):
            raise RuntimeError('Missing native proof/journal commitments')
        seen.add(key)
    counterexamples = [line for line in lines if line.startswith('NATIVE-CONTEXT-COUNTEREXAMPLE ')]
    if len(counterexamples) != 1:
        raise RuntimeError('Missing native old-snapshot bypass counterexample')
    comparison_controls = [line for line in lines if line.startswith('NATIVE-COMPARISON-COUNTEREXAMPLE ')]
    if comparison_controls != ['NATIVE-COMPARISON-COUNTEREXAMPLE archive-revision-ablation test-local-publication=#t native-publication=#f']:
        raise RuntimeError('Missing or wrong actual test-local weak-contract publication control')
    counterexamples += comparison_controls
    paths = []
    for line in lines:
        if not line.startswith('NATIVE-CAS-PATH '):
            continue
        match = re.fullmatch(r'NATIVE-CAS-PATH order=\(([1-8 ]+)\) outcome=(completed|cancelled|reconciled|pending) revision=(\d+) terminals=([01]) obligations=([01]) current-use=#f', line)
        if not match:
            raise RuntimeError(f'Invalid native path verdict: {line}')
        order, outcome, revision, terminals, obligations = match.groups()
        paths.append({'order': [int(x) for x in order.split()], 'outcome': outcome,
                      'revision': int(revision), 'terminals': int(terminals),
                      'obligations': int(obligations), 'current_use': False})
    if [tuple(path['order']) for path in paths] != orders:
        raise RuntimeError('Executed native paths differ from requested legal order corpus')
    if any(path['terminals'] != int(path['outcome'] != 'pending') for path in paths):
        raise RuntimeError('Native terminal outcome/count mismatch')
    return count, observations, counterexamples, paths


def ascent_revision(root):
    checkout = root / '.gerbil/pkg/github.com/tao3k/gerbil-ascent'
    head = subprocess.run(['git', '-C', str(checkout), 'rev-parse', 'HEAD'], text=True,
                          capture_output=True, timeout=10, check=True).stdout.strip()
    declared = re.search(r'github.com/tao3k/gerbil-ascent@([0-9a-f]{40})', (root / 'gerbil.pkg').read_text())
    if not declared or head != declared.group(1):
        raise RuntimeError('Installed ASCENT checkout does not match declared package pin')
    return head


def orgize_revision(root):
    checkout = root / '.gerbil/pkg/github.com/tao3k/orgize'
    head = subprocess.run(['git', '-C', str(checkout), 'rev-parse', 'HEAD'], text=True,
                          capture_output=True, timeout=10, check=True).stdout.strip()
    declared = re.search(r'github.com/tao3k/orgize@([0-9a-f]{40})', (root / 'gerbil.pkg').read_text())
    if not declared or head != declared.group(1):
        raise RuntimeError('Installed Orgize checkout does not match declared package pin')
    return head


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--check-receipt', type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--exhaustive', action='store_true')
    mode.add_argument('--order', help='comma-separated event IDs from a saved native path')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[4]
    if args.check_receipt:
        receipt = json.loads(args.check_receipt.read_text())
        if receipt.get('orgize_checkout_head') != orgize_revision(root):
            raise RuntimeError('Recorded Orgize checkout cut is stale')
        if receipt.get('ascent_checkout_head') != ascent_revision(root):
            raise RuntimeError('Recorded ASCENT checkout cut is stale')
        if set(receipt['source_sha256']) != set(INPUTS) or any(sha(root / path) != value for path, value in receipt['source_sha256'].items()):
            raise RuntimeError('Recorded native source cut is stale')
        for name in ('log', 'build_log', 'paths'):
            if sha(args.check_receipt.parent / receipt[name]) != receipt[name + '_sha256']:
                raise RuntimeError(f'Recorded native {name} commitment mismatch')
        paths = json.loads((args.check_receipt.parent / receipt['paths']).read_text())
        orders = [tuple(path['order']) for path in paths]
        if not all(legal(order) for order in orders) or len(set(orders)) != len(orders):
            raise RuntimeError('Illegal or repeated native order corpus')
        if receipt['mode'] == 'exhaustive' and orders != [order for order in itertools.permutations(range(1, 9)) if legal(order)]:
            raise RuntimeError('Incomplete exhaustive native order corpus')
        actual = inspect(root, args.check_receipt.parent / receipt['log'], receipt['native_exit'], orders)
        if actual != (receipt['case_count'], receipt['observations'], receipt['counterexample'], paths):
            raise RuntimeError('Receipt and actual native observations differ')
        print(f'CURRENT RECEIPT: {actual[0]} native Cases, {len(paths)} owner paths; {args.check_receipt}')
        return 0
    orders = [order for order in itertools.permutations(range(1, 9)) if legal(order)] if args.exhaustive else DEFAULT_ORDERS
    if args.order:
        orders = [tuple(int(x) for x in args.order.split(','))]
        if not legal(orders[0]):
            raise RuntimeError('Illegal eight-event replay order')
    artifacts = args.artifacts or Path(tempfile.mkdtemp(prefix='context-native-', dir='/private/tmp'))
    artifacts.mkdir(parents=True, exist_ok=True)
    before = {path: sha(root / path) for path in INPUTS}
    ascent_before = ascent_revision(root)
    orgize_before = orgize_revision(root)
    env = os.environ.copy()
    env.update(GERBIL_PATH=str(root / '.gerbil'), GERBIL_LOADPATH=f'{root}:{root}/.gerbil/lib:{root}/dev/.gerbil/lib')
    env.pop('AGENTIC_CONTEXT_NATIVE_CAS_EXHAUSTIVE', None)
    env.pop('AGENTIC_CONTEXT_NATIVE_CAS_ORDER', None)
    if args.order:
        env['AGENTIC_CONTEXT_NATIVE_CAS_ORDER'] = '(' + ' '.join(map(str, orders[0])) + ')'
    build_log = artifacts / 'build.log'
    with build_log.open('w') as output:
        subprocess.run(['just', 'build-library'], cwd=root, env=env,
                       stdout=output, stderr=subprocess.STDOUT, timeout=120, check=True)
    log = artifacts / 'native.log'
    command = ['just', 'test-context-owner-cas' if args.exhaustive else 'test-context-evidence-native']
    with log.open('w') as output:
        result = subprocess.run(command, cwd=root, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=915 if args.exhaustive else 135)
    if ascent_revision(root) != ascent_before or orgize_revision(root) != orgize_before or any(sha(root / path) != value for path, value in before.items()):
        raise RuntimeError('Native sources changed during execution; retain log without qualification')
    count, observations, counterexamples, paths = inspect(root, log, result.returncode, orders)
    paths_file = artifacts / 'native-paths.json'
    paths_file.write_text(json.dumps(paths, indent=2) + '\n')
    receipt = {'schema': 'context.native-evidence-replay.v2', 'command': command,
               'mode': 'exhaustive' if args.exhaustive else 'replay' if args.order else 'focused',
               'native_exit': result.returncode, 'case_count': count, 'log': log.name,
               'validator_sha256': sha(Path(__file__)),
               'log_sha256': sha(log), 'build_log': build_log.name, 'build_log_sha256': sha(build_log),
               'paths': paths_file.name, 'paths_sha256': sha(paths_file), 'source_sha256': before,
               'ascent_checkout_head': ascent_before, 'orgize_checkout_head': orgize_before, 'ascent_matches_declared_pin': True, 'required_markers': MARKERS,
               'failure_markers': [], 'observations': observations, 'counterexample': counterexamples,
               'outcome_counts': dict(Counter(path['outcome'] for path in paths)),
               'scope': {'original_ascent_called': True, 'native_proof_support_journal': True,
                         'scheme_thread_join': True, 'native_terminal_publication': True,
                         'external_provider_admission': False, 'durable_cas': False,
                         'process_crash_recovery': False, 'org_to_fact_authority_refinement': False,
                         'comparative_llm_benchmark': False}}
    path = artifacts / 'native-receipt.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(f'PASS: {count} native Cases, {len(paths)} owner paths, {len(counterexamples)} counterexample observations; receipt: {path}')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, KeyError, subprocess.SubprocessError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
