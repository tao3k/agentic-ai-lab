#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Qualify an explicit gerbil-scheme-rust source/image downstream boundary."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CONSUMER = ROOT/'t/qualification/context-hybrid-rust'
REVISION = 'f2c8ccfaaaa88eededad2dfef45eac1760fb4408'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native(command, log, env, timeout, expected=0):
    started = time.monotonic()
    with subprocess.Popen(command, env=env, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, start_new_session=True) as run:
        try:
            output, _ = run.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            # This is failure cleanup of only this owned process group; it is
            # never admitted as a successful native exit or wider deadline.
            os.killpg(run.pid, signal.SIGTERM)
            try:
                output, _ = run.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(run.pid, signal.SIGKILL)
                output, _ = run.communicate()
            log.write_bytes(output)
            log.with_suffix('.process.json').write_text(json.dumps(dict(
                command=list(map(str, command)), exit=run.returncode,
                elapsed_seconds=time.monotonic()-started, timed_out=True,
                log_sha256=sha(log)), indent=2)+'\n')
            raise RuntimeError('Deadline failed; retained '+str(log))
    log.write_bytes(output)
    receipt = dict(command=list(map(str, command)), exit=run.returncode,
                   elapsed_seconds=time.monotonic()-started, log_sha256=sha(log))
    log.with_suffix('.process.json').write_text(json.dumps(receipt, indent=2)+'\n')
    if run.returncode != expected:
        raise RuntimeError('Unexpected exit; retained '+str(log))
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--image', type=Path, required=True)
    parser.add_argument('--artifacts', type=Path, required=True)
    parser.add_argument('--target-dir', type=Path, help='Explicit Cargo artifact cache; never used as runtime timing')
    args = parser.parse_args()
    out = args.artifacts.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = args.source.resolve()
    revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if revision != REVISION:
        raise RuntimeError('Consumer dependency revision differs from admitted local source')
    # Current local source bytes are recorded even when the checkout is dirty.
    # An old image is admitted only as a boundary fixture, never as proof that
    # this current source produced it or contains the production Context code.
    local = {str(p.relative_to(ROOT)): sha(p) for p in CONSUMER.rglob('*') if p.is_file()}
    upstream = {}
    for folder in ('crates/gerbil-scheme', 'crates/gerbil-scheme-sys', 'build-support', 'ffi'):
        for p in (source/folder).rglob('*'):
            if p.is_file() and p.suffix in ('.rs', '.c', '.h', '.toml'):
                upstream[str(p.relative_to(source))] = sha(p)
    image = out/'owner-image.dylib'
    shutil.copy2(args.image, image)
    symbols = subprocess.check_output(['/usr/bin/nm', '-gU', str(image)], text=True)
    for name in ('gerbil_scheme_instance_abi', 'gerbil_owner_native_call'):
        if '_'+name not in symbols:
            raise RuntimeError('Missing native fixture export: '+name)
    (out/'symbols.txt').write_text(symbols)
    consumer = out/'consumer'
    shutil.copytree(CONSUMER/'src', consumer/'src')
    manifest = (CONSUMER/'Cargo.toml').read_text()
    dependency = f'git = "https://github.com/tao3k/gerbil-scheme-rust", rev = "{REVISION}",'
    manifest = manifest.replace(dependency, 'path = '+json.dumps(str(source/'crates/gerbil-scheme'))+',')
    (consumer/'Cargo.toml').write_text(manifest)
    env = os.environ.copy()
    for name in ('SDKROOT', 'DEVELOPER_DIR', 'CPATH', 'LIBRARY_PATH', 'C_INCLUDE_PATH',
                 'CPLUS_INCLUDE_PATH', 'MACOSX_DEPLOYMENT_TARGET'):
        env.pop(name, None)
    env.update(COMPILER_PATH='/usr/bin', CC='/usr/bin/clang', CXX='/usr/bin/clang++',
               CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER='/usr/bin/clang',
               CARGO_TARGET_DIR=str((args.target_dir or out/'target').resolve()))
    cargo = ['cargo', '--offline', '--manifest-path', str(consumer/'Cargo.toml')]
    build = native(['cargo', 'build', *cargo[1:]], out/'build.log', env, 180)
    binary = Path(env['CARGO_TARGET_DIR'])/'debug/context-hybrid-runtime-probe'
    executable_sha = sha(binary)
    command = ['timeout', '--foreground', '--signal=TERM', '--kill-after=5s', '150s', str(binary), str(image)]
    runs = []
    for name in ('native', 'replay'):
        runs.append(native(command, out/(name+'.log'), env, 155))
        text = (out/(name+'.log')).read_text()
        if ('RUST-SCHEME owners=2 timeout=observation credit=retained independent=completed roots=0 joined=2\nOK\n' not in text
                or 'panicked' in text or '*** ERROR' in text):
            raise RuntimeError('Incomplete Rust/Scheme native boundary')
    negative = consumer/'src/bin/root-escape.rs'
    negative.parent.mkdir()
    shutil.copy2(CONSUMER/'root-escape.rs', negative)
    control = native(['cargo', 'check', *cargo[1:], '--bin', 'root-escape'], out/'root-escape.log', env, 120, 101)
    text = (out/'root-escape.log').read_text()
    if not all(marker in text for marker in ('E0277', 'NativeRoot', 'Send', 'cannot be sent between threads')):
        raise RuntimeError('Compile failure was not the expected owner-local-root refusal')
    if any(sha(ROOT/p) != digest for p, digest in local.items()):
        raise RuntimeError('Consumer source drift')
    if any(sha(source/p) != digest for p, digest in upstream.items()):
        raise RuntimeError('Upstream source drift')
    if sha(binary) != executable_sha or sha(image) != sha(args.image):
        raise RuntimeError('Image/binary drift')
    (out/'summary.json').write_text(json.dumps(dict(
        schema='context.hybrid.rust-boundary.v1', upstream_revision=revision,
        consumer_source_sha256=local, upstream_source_sha256=upstream,
        image_sha256=sha(image), executable_sha256=executable_sha,
        runner_sha256=sha(Path(__file__)), build=build, native_runs=runs, root_escape_control=control,
        scope=dict(transport_boundary_only=True, production_context_export=False,
                   image_current_source_provenance=False, heap_limit_not_exposed_by_upstream_instance_api=True,
                   scheme_context_heap_fence_verified_separately='2G/150s', native_watchdog_seconds=150,
                   throughput_claim=False)), indent=2)+'\n')
    print('PASS: Tokio/fixed-owner native boundary, whole replay and owner-root compile-fail control')


if __name__ == '__main__':
    main()
