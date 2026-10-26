#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Run existing Context/temporal regressions on the qualified Provider build.

No rebuild occurs between the two gates. Both the Query receipt and the native
object commitment are rechecked after the original suite has actually run.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('query_gate', HERE / 'run-native-query.py')
query = importlib.util.module_from_spec(spec)
spec.loader.exec_module(query)


def verify(path):
    receipt = json.loads(path.read_text())
    original = Path(receipt['query_receipt'])
    query.verify(original)
    if (query.sha(original) != receipt['query_receipt_sha256']
            or query.sha(Path(__file__)) != receipt['runner_sha256']
            or query.binaries() != receipt['binaries']
            or any(query.sha(query.ROOT / p) != h for p, h in receipt['source_sha256'].items())
            or query.sha(path.parent / 'native.log') != receipt['log_sha256']):
        raise RuntimeError('Regression source/object/evidence cut changed')
    actual = query.clock.inspect(path.parent / 'native.log', receipt['exit_code'], query.clock.ALL)
    if actual != receipt['execution']:
        raise RuntimeError('Saved regression verdict differs from native execution')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--query-receipt', type=Path)
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--check-receipt', type=Path)
    args = parser.parse_args()
    if args.check_receipt:
        verify(args.check_receipt)
        print('CURRENT QUERY + REGRESSION RECEIPTS:', args.check_receipt)
        return
    if args.query_receipt is None or args.artifacts is None:
        parser.error('--query-receipt and --artifacts are required')
    query.verify(args.query_receipt)
    args.artifacts.mkdir(parents=True, exist_ok=False)
    before = {p: query.sha(query.ROOT / p) for p in query.clock.INPUTS}
    cut = query.binaries()
    env = os.environ.copy()
    for name in tuple(env):
        if name.startswith('AGENTIC_CONTEXT_'):
            env.pop(name)
    env.update(GERBIL_PATH=str(query.ROOT / '.gerbil'),
               GERBIL_LOADPATH=f'{query.ROOT}/.gerbil/lib:{query.ROOT}:{query.ROOT}/dev/.gerbil/lib')
    log = args.artifacts / 'native.log'
    with log.open('w') as stream:
        result = subprocess.run(['just', 'test-context-clock'], cwd=query.ROOT, env=env,
                                stdout=stream, stderr=subprocess.STDOUT, timeout=915)
    query.verify(args.query_receipt)
    if before != {p: query.sha(query.ROOT / p) for p in query.clock.INPUTS} or cut != query.binaries():
        raise RuntimeError('Regression runtime cut changed')
    actual = query.clock.inspect(log, result.returncode, query.clock.ALL)
    receipt = dict(schema='context.query-legacy-regression.v1',
                   query_receipt=str(args.query_receipt), query_receipt_sha256=query.sha(args.query_receipt),
                   runner_sha256=query.sha(Path(__file__)), source_sha256=before, binaries=cut,
                   exit_code=result.returncode, execution=actual, log_sha256=query.sha(log))
    path = args.artifacts / 'regression-receipt.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    verify(path)
    print('PASS: same-build original native regression and 60 live clock paths;', path)


if __name__ == '__main__':
    main()
