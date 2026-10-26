#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Qualify the live-owner clock corpus using an already verified durable build.

Rebuilding between gates would change the native binary commitment. This entry
point verifies the durable receipt, reuses those exact objects, then invokes the
ordinary clock evidence parser and receipt checker. It never relabels old logs.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('durable_gate', HERE / 'run-native-durable.py')
durable = importlib.util.module_from_spec(spec)
spec.loader.exec_module(durable)
clock = durable.clock
ROOT = durable.ROOT


def verify(path):
    receipt = clock.verify(path)
    reuse = receipt['build_reuse']
    source = Path(reuse['durable_receipt'])
    if durable.sha(source) != reuse['sha256'] or durable.sha(Path(__file__)) != reuse['runner_sha256']:
        raise RuntimeError('Reused durable build or clock runner commitment changed')
    durable.verify_receipt(source)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--durable-receipt', type=Path)
    parser.add_argument('--artifacts', type=Path)
    parser.add_argument('--check-receipt', type=Path)
    args = parser.parse_args()
    if args.check_receipt:
        verify(args.check_receipt)
        print('CURRENT CLOCK + DURABLE RECEIPTS:', args.check_receipt)
        return
    if args.durable_receipt is None or args.artifacts is None:
        parser.error('--durable-receipt and --artifacts are required for execution')
    durable.verify_receipt(args.durable_receipt)
    args.artifacts.mkdir(parents=True, exist_ok=False)
    before = {p: durable.sha(ROOT / p) for p in clock.INPUTS}
    binary_cut = clock.binaries()
    ascent = clock.base.ascent_revision(ROOT)
    orgize = clock.base.orgize_revision(ROOT)
    env = os.environ.copy()
    for name in tuple(env):
        if name.startswith('AGENTIC_CONTEXT_'):
            env.pop(name)
    env.update(GERBIL_PATH=str(ROOT / '.gerbil'),
               GERBIL_LOADPATH=f'{ROOT}/.gerbil/lib:{ROOT}:{ROOT}/dev/.gerbil/lib')
    shutil.copyfile(args.durable_receipt.parent / 'build.log', args.artifacts / 'build.log')
    with (args.artifacts / 'native.log').open('w') as output:
        result = subprocess.run(['just', 'test-context-clock'], cwd=ROOT, env=env,
                                stdout=output, stderr=subprocess.STDOUT, timeout=915)
    durable.verify_receipt(args.durable_receipt)
    if before != {p: durable.sha(ROOT / p) for p in clock.INPUTS} or binary_cut != clock.binaries():
        raise RuntimeError('Clock source/binary cut changed')
    actual = clock.inspect(args.artifacts / 'native.log', result.returncode, clock.ALL)
    (args.artifacts / 'paths.json').write_text(json.dumps(actual['paths'], indent=2) + '\n')
    receipt = dict(schema='context.native-background-clock.v1', mode='all', orders=clock.ALL,
                   native_exit=result.returncode, source_sha256=before, ascent_head=ascent,
                   orgize_head=orgize, binaries=binary_cut, execution=actual,
                   artifacts={p: durable.sha(args.artifacts / p)
                              for p in ('build.log', 'native.log', 'paths.json')},
                   scope=dict(os_monotonic_timer=True, owner_reactor=True,
                              no_query_push=True, delayed_duplicate_queue_orders=True,
                              all_machine_interleavings=False,
                              persistent_crash_recovery=False,
                              provider_kv_cache_benchmark=False),
                   build_reuse=dict(durable_receipt=str(args.durable_receipt),
                                    sha256=durable.sha(args.durable_receipt),
                                    runner_sha256=durable.sha(Path(__file__))))
    path = args.artifacts / 'clock-receipt.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    verify(path)
    print(f'PASS: current native clock regression and {len(clock.ALL)} owner paths; {path}')


if __name__ == '__main__':
    main()
