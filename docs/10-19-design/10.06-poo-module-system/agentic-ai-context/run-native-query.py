#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Native GQL/Org/ASCENT Context qualification, negative controls and replay.

Every Scheme process uses the project Just heap fence. Cases run serially.
Raw evidence and checkpoints stay outside Git. Receipts bind the actual source
and object cut; they never promote a partial or drifted run to qualification.
"""
import argparse
import hashlib
import importlib.util
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
spec = importlib.util.spec_from_file_location('clock_gate', HERE / 'run-native-clock.py')
clock = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clock)
MODULES = (
    'modules/ai-agentic-context/query-provider',
    'modules/ai-agentic-context/org-contract/elements',
    'modules/ai-agentic-context/session-host',
    'modules/ai-agentic-context/funs-session',
    'modules/ai-agentic-context/funs-anchors',
    'modules/ai-agentic-context/funs-projection',
    'modules/ai-agentic-context/funs-scope',
    'modules/ai-agentic-context/use-host',
    'modules/session/funs-identity', 'modules/session/funs', 'modules/session/interface',
    'modules/session/funs-attempt', 'modules/session/objects-attempt',
    'modules/query/objects', 'modules/query/types', 'modules/query/funs',
    'modules/query/gql', 'modules/query/contracts', 'modules/query/scheme-select',
    'modules/query/results/funs', 'modules/query/results/objects',
    'modules/query/semantic/orgize-source-interface',
    'modules/temporal-causality/evaluator/positive-proof',
    'modules/temporal-causality/evaluator/proof-host',
    'modules/temporal-causality/runtime/change-feed',
    'modules/temporal-causality/runtime/durable-journal',
    'modules/temporal-causality/truth-maintenance/support/funs',
    'modules/temporal-causality/truth-maintenance/support/objects',
    'modules/temporal-causality/truth-maintenance/support/policy-host',
    'modules/temporal-causality/revisions/funs',
    'modules/temporal-causality/revisions/objects',
    'modules/temporal-causality/time/objects',
    't/context-query-provider-test', 't/temporal-evaluator-test',
)
ORIGINALS = {
    'rules': 't/qualification/temporal-library-basic/rule-correspondence-v1/typed-rules.ss',
    'facts': 't/qualification/temporal-library-basic/derivation-authority-v1/typed-derivations.ss',
}
INPUTS = tuple(dict.fromkeys([
    *(m + '.ss' for m in MODULES), *ORIGINALS.values(),
    'gerbil.pkg', '.gerbil/pkg/github.com/tao3k/orgize/gerbil.pkg', 'build-spec.ss', 'dev/just/build.just', 'dev/just/runtime-tests.just',
    't/harness/context-query-driver.ss', 'build.ss',
    *[str(p.relative_to(ROOT)) for p in sorted((ROOT / 'modules/ai-agentic-context/org-contract/templates').glob('*.org'))],
    str(Path(__file__).resolve().relative_to(ROOT)),
]))
ORDERS = [p for p in itertools.permutations(range(1, 6)) if p.index(4) < p.index(5)]
BAD = re.compile(r'ERROR CASE|ERROR CHECK|ERROR HARNESS|ERROR MODULE|Heap overflow|Stack overflow|\*\*\* ERROR')
MARKERS = ('MODULE-OK t/context-query-provider-test.ss', 'HARNESS-OK context-query-provider', 'OK')
PATH = re.compile(r'^QUERY-PATH kind=(replace|withdraw) order=\(([1-5 ]+)\) arrival=\(([1-5 ]+)\) completed-a=(#t|#f) completed-b=(#t|#f) terminals-a=1 terminals-b=([01]) old-current=#f c-completed=#t push=#t$')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    return {p: sha(ROOT / p) for p in INPUTS}


def parser_revision():
    checkout = ROOT / '.gerbil/pkg/github.com/tao3k/gerbil-parser'
    head = subprocess.run(['git', '-C', str(checkout), 'rev-parse', 'HEAD'],
                          capture_output=True, text=True, check=True).stdout.strip()
    parent = ROOT / '.gerbil/pkg/github.com/tao3k/orgize/gerbil.pkg'
    declared = re.search(r'gerbil-parser@([0-9a-f]{40})', parent.read_text())
    if not declared or declared.group(1) != head:
        raise RuntimeError('Installed parser does not match the Orgize dependency pin')
    return head


def binaries():
    result = {}
    # Include numbered native objects, not only .o1: Gambit may select a higher
    # suffix. Hashing the actual candidate set prevents hidden artifact drift.
    for owner in ('gerbil-ascent', 'orgize', 'gerbil-parser', 'clan', 'yuanxu'):
        for p in (ROOT / '.gerbil/lib' / owner).rglob('*'):
            if p.is_file() and (re.search(r'\.o[0-9]+$', p.name)
                                or p.suffix == '.ssi' or p.name.endswith('.ssxi.ss')):
                result[str(p.relative_to(ROOT))] = sha(p)
    for module in MODULES:
        stem = ROOT / '.gerbil/lib/agentic-ai-lab' / module
        files = [p for p in stem.parent.glob(stem.name + '*')
                 if p.is_file() and (re.search(r'\.o[0-9]+$', p.name)
                                     or p.suffix == '.ssi' or p.name.endswith('.ssxi.ss'))]
        if not any(re.search(r'\.o[0-9]+$', p.name) for p in files):
            raise RuntimeError('Missing native artifact: ' + module)
        result.update({str(p.relative_to(ROOT)): sha(p) for p in files})
    return result


def execute(out, mode, order, env):
    log = out / (mode + '.log')
    with log.open('w') as stream:
        result = subprocess.run(['just', 'test-context-query', mode, order], cwd=ROOT, env=env,
                                stdout=stream, stderr=subprocess.STDOUT, timeout=915)
    text = log.read_text()
    if result.returncode or BAD.search(text) or not all(m in text.splitlines() for m in MARKERS):
        raise RuntimeError('Native Query scenario failed: ' + str(log))
    return log, text


def extract(out, text, expected_orders):
    paths, checkpoints, journals = [], [], []
    for line in text.splitlines():
        if line.startswith('QUERY-PATH '):
            match = PATH.fullmatch(line)
            if not match:
                raise RuntimeError('Malformed native path')
            kind, order, arrival, a, b, terminal_b = match.groups()
            order, arrival = tuple(map(int, order.split())), tuple(map(int, arrival.split()))
            if order not in ORDERS or arrival not in ORDERS:
                raise RuntimeError('Illegal producer/owner order')
            expected_a = order.index(2) < min(order.index(1), order.index(4))
            expected_b = order.index(3) < order.index(1)
            if (a == '#t') != expected_a or (b == '#t') != expected_b or int(terminal_b) != expected_b:
                raise RuntimeError('Wrong actual terminal publication boundary')
            paths.append(dict(kind=kind, order=order, arrival=arrival, completed_a=expected_a, completed_b=expected_b))
        elif line.startswith('QUERY-CHECKPOINT '):
            path = out / f'checkpoint-{len(checkpoints):03d}.ss'
            path.write_text(line.removeprefix('QUERY-CHECKPOINT ') + '\n')
            checkpoints.append(dict(path=path.name, sha256=sha(path)))
        elif line.startswith('QUERY-JOURNAL '):
            path = out / f'journal-{len(journals):03d}.ss'
            path.write_text(line.removeprefix('QUERY-JOURNAL ') + '\n')
            journals.append(dict(path=path.name, sha256=sha(path)))
        elif line.startswith('QUERY-EVIDENCE original='):
            (out / 'original-query.ss').write_text(line.removeprefix('QUERY-EVIDENCE original=') + '\n')
    expected = [(kind, p) for kind in ('replace', 'withdraw') for p in expected_orders]
    # Each kind ends with an additional actual-arrival execution, not a scripted order.
    cursor = 0
    for kind in ('replace', 'withdraw'):
        actual = paths[cursor:cursor + len(expected_orders)]
        if [(p['kind'], p['order']) for p in actual] != [(kind, p) for p in expected_orders]:
            raise RuntimeError('Incomplete native linearization corpus')
        cursor += len(expected_orders)
        if paths[cursor]['kind'] != kind or paths[cursor]['order'] != paths[cursor]['arrival']:
            raise RuntimeError('Missing actual mailbox-arrival path')
        cursor += 1
    if cursor != len(paths) or len(checkpoints) != len(paths) or len(journals) != len(paths):
        raise RuntimeError('Missing original checkpoint or journal evidence')
    if text.splitlines().count('QUERY-FRESH same-session=#t old-parent-stays-invalid=#t native-result-published=#t') != len(paths):
        raise RuntimeError('Fresh native Attempt / captured-parent controls missing')
    return paths, checkpoints, journals


def verify(path):
    receipt = json.loads(path.read_text())
    if receipt.get('schema') != 'context.native-query-provider.v1':
        raise RuntimeError('Unknown Query receipt schema')
    expected_count = 122 if receipt['mode'] == 'all' else 4
    if (len(receipt['paths']) != expected_count
            or len(receipt['checkpoints']) != expected_count
            or len(receipt['source_journals']) != expected_count):
        raise RuntimeError('Incomplete stored native corpus')
    text = (path.parent / 'all.log').read_text()
    if BAD.search(text) or not all(m in text.splitlines() for m in MARKERS):
        raise RuntimeError('Stored native harness evidence failed')
    traces = [PATH.fullmatch(line) for line in text.splitlines() if line.startswith('QUERY-PATH ')]
    if len(traces) != expected_count or not all(traces):
        raise RuntimeError('Stored native paths missing')
    for row, trace in zip(receipt['paths'], traces):
        kind, order, arrival, a, b, terminal_b = trace.groups()
        actual_order = list(map(int, order.split()))
        actual_arrival = list(map(int, arrival.split()))
        if (row['kind'] != kind or row['order'] != actual_order or row['arrival'] != actual_arrival
                or row['completed_a'] != (a == '#t') or row['completed_b'] != (b == '#t')
                or row['completed_a'] != (actual_order.index(2) < min(actual_order.index(1), actual_order.index(4)))
                or row['completed_b'] != (actual_order.index(3) < actual_order.index(1))):
            raise RuntimeError('Stored native verdict differs from execution')
    counter = (path.parent / 'counter.log').read_text()
    replay = (path.parent / 'restore.log').read_text()
    if ('QUERY-COUNTEREXAMPLE no-subscription' not in counter
            or 'QUERY-COUNTEREXAMPLE unbound-source actual-stale-result-published=#t' not in counter
            or 'native-proof-replayed=#t old-current=#f fresh-current=#t parent-fenced=#t' not in replay):
        raise RuntimeError('Stored negative/replay evidence missing')
    if receipt['source_sha256'] != sources() or receipt['binaries'] != binaries():
        raise RuntimeError('Native Query source/object cut is stale')
    if receipt['ascent_head'] != clock.base.ascent_revision(ROOT) or receipt['orgize_head'] != clock.base.orgize_revision(ROOT) or receipt['parser_head'] != parser_revision():
        raise RuntimeError('Native dependency pins changed')
    for name, digest in receipt['artifacts'].items():
        if sha(path.parent / name) != digest:
            raise RuntimeError('Native Query artifact commitment changed: ' + name)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--check-receipt', type=Path)
    parser.add_argument('--reuse-build', type=Path)
    parser.add_argument('--order', help='One recorded native owner linearization, comma separated')
    args = parser.parse_args()
    if args.check_receipt:
        r = verify(args.check_receipt)
        print('CURRENT QUERY RECEIPT:', len(r['paths']), 'native paths;', args.check_receipt)
        return
    out = args.artifacts or Path(tempfile.mkdtemp(prefix='context-query-native-', dir='/private/tmp'))
    out.mkdir(parents=True, exist_ok=args.artifacts is None)
    selected = [tuple(map(int, args.order.split(',')))] if args.order else ORDERS
    if not all(p in ORDERS for p in selected):
        raise RuntimeError('Invalid replay order')
    before = sources()
    pins = (clock.base.ascent_revision(ROOT), clock.base.orgize_revision(ROOT), parser_revision())
    env = os.environ.copy()
    env.update(GERBIL_PATH=str(ROOT / '.gerbil'),
               GERBIL_LOADPATH=f'{ROOT}/.gerbil/lib:{ROOT}:{ROOT}/dev/.gerbil/lib')
    if args.reuse_build:
        verify(args.reuse_build)
        (out / 'build.log').write_bytes((args.reuse_build.parent / 'build.log').read_bytes())
    else:
        with (out / 'build.log').open('w') as stream:
            subprocess.run(['just', 'build-test', 't/context-query-provider-test.ss'], cwd=ROOT, env=env,
                           stdout=stream, stderr=subprocess.STDOUT, timeout=600, check=True)
    cut = binaries()
    (out / 'start-cut.json').write_text(json.dumps(dict(source_sha256=before, binaries=cut), indent=2) + '\n')
    (out / 'originals').mkdir()
    for key, source in ORIGINALS.items():
        shutil.copyfile(ROOT / source, out / 'originals' / (key + '.ss'))
    env['AGENTIC_AI_LAB_MRR_RULE_ORACLE'] = str(out / 'originals/rules.ss')
    env['AGENTIC_AI_LAB_MRR_DERIVATION_ORACLE'] = str(out / 'originals/facts.ss')
    order_text = '(' + ' '.join(map(str, selected[0])) + ')' if args.order else 'all'
    log, text = execute(out, 'all', order_text, env)
    paths, checkpoints, journals = extract(out, text, selected)
    counter, counter_text = execute(out, 'counter', 'all', env)
    if ('QUERY-COUNTEREXAMPLE no-subscription' not in counter_text
            or 'QUERY-COUNTEREXAMPLE unbound-source actual-stale-result-published=#t' not in counter_text):
        raise RuntimeError('Missing actual native counterexamples')
    # Recover an original stored Context in a fresh Scheme process. Its raw
    # Org, proof DAG, support/journal and old parent versions are the inputs.
    eligible = [i for i, p in enumerate(paths)
                if p['kind'] == 'withdraw' and p['completed_a'] and p['completed_b']]
    replay_index = eligible[0] if eligible else next(i for i, p in enumerate(paths) if p['kind'] == 'withdraw')
    replay, replay_text = execute(out, 'restore', str(out / checkpoints[replay_index]['path']), env)
    if 'native-proof-replayed=#t old-current=#f fresh-current=#t parent-fenced=#t' not in replay_text:
        raise RuntimeError('Original native checkpoint replay evidence missing')
    if (before != sources() or cut != binaries()
            or pins != (clock.base.ascent_revision(ROOT), clock.base.orgize_revision(ROOT), parser_revision())):
        raise RuntimeError('Runtime cut changed; partial native logs remain unqualified')
    files = ['build.log', 'start-cut.json', log.name, counter.name, replay.name, 'original-query.ss',
             'originals/rules.ss', 'originals/facts.ss',
             *[p['path'] for p in checkpoints], *[p['path'] for p in journals]]
    receipt = dict(schema='context.native-query-provider.v1', mode='replay' if args.order else 'all',
                   source_sha256=before, binaries=cut, paths=paths, checkpoints=checkpoints,
                   source_journals=journals, checkpoint_replay_index=replay_index,
                   ascent_head=clock.base.ascent_revision(ROOT), orgize_head=clock.base.orgize_revision(ROOT), parser_head=parser_revision(),
                   artifacts={p: sha(out / p) for p in files},
                   scope=dict(single_node_gql=True, native_ascent_membership=True,
                              original_checkpoint_replay=True, all_os_schedules=False,
                              arbitrary_org_contract_execution=False, external_source_authentication=False,
                              heap_per_process='1G', concurrent_gerbil_processes=1))
    path = out / 'query-receipt.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    verify(path)
    print(f'PASS: {len(paths)} actual native paths, 2 native counterexamples, original checkpoint replay; {path}')


if __name__ == '__main__':
    main()
