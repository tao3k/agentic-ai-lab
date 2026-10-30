# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Compare identical Scheme receipts over a worker and the native byte ABI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import select
import statistics
import subprocess
import sys
import time
from .semantic_cases import corpus


def read_line(worker, *, progress=False):
    assert worker.stdout is not None
    if not select.select([worker.stdout], [], [], 5)[0]:
        raise RuntimeError('worker emitted no real progress for five seconds')
    line = worker.stdout.readline()
    if not line:
        raise RuntimeError('worker exited without response')
    if progress:
        sys.stdout.write(line.decode()); sys.stdout.flush()
    return line.decode().strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--library', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntime
    env = os.environ.copy(); env.pop('DEEPSEEK_API_KEY', None)
    started = time.perf_counter()
    worker = subprocess.Popen(['just', 'semantic-worker'], stdin=subprocess.PIPE,
                              stdout=subprocess.PIPE, bufsize=0, env=env)
    try:
        while read_line(worker, progress=True) != 'READY':
            pass
        worker_cold = time.perf_counter() - started
        started = time.perf_counter()
        runtime = SemanticRuntime(args.library, expected_digest=hashlib.sha256(args.library.read_bytes()).hexdigest())
        native_cold = time.perf_counter() - started
        timings = {'worker': [], 'native': []}
        try:
            for iteration in range(5):
                for case_index, case in enumerate(corpus()):
                    request = json.dumps(case['request'], separators=(',', ':')).encode() + b'\n'
                    assert worker.stdin is not None
                    def worker_call():
                        started = time.perf_counter(); worker.stdin.write(request); worker.stdin.flush()
                        answer = json.loads(read_line(worker))
                        timings['worker'].append(time.perf_counter() - started)
                        return answer
                    def native_call():
                        started = time.perf_counter(); answer = runtime.call('temporal.solve', case['request'])
                        timings['native'].append(time.perf_counter() - started)
                        return answer
                    if (iteration + case_index) % 2:
                        result = native_call(); baseline = worker_call()
                    else:
                        baseline = worker_call(); result = native_call()
                    assert baseline == result, case['id']
                    sys.stdout.write(f'MATCH {iteration} {case["id"]}\n'); sys.stdout.flush()
        finally:
            runtime.close()
        worker.stdin.close()
        worker.stdin = None
        assert read_line(worker, progress=True) == 'OK'
        assert worker.wait(timeout=5) == 0
        report = {'schema': 'agentic-ai-lab.semantic-transport-comparison.v1',
                  'matchedReceipts': 60, 'callOrder': 'alternating-paired', 'workerColdSeconds': worker_cold,
                  'nativeColdSeconds': native_cold,
                  'nativeArtifactSha256': hashlib.sha256(args.library.read_bytes()).hexdigest()}
        for arm, values in timings.items():
            report[arm] = {'p50Seconds': statistics.median(values),
                           'p95Seconds': sorted(values)[56], 'samples': len(values)}
        report['warmSpeedup'] = report['worker']['p50Seconds'] / report['native']['p50Seconds']
        args.output.write_text(json.dumps(report, indent=2) + '\n')
        sys.stdout.write(json.dumps(report) + '\n')
    finally:
        if worker.stdin:
            worker.stdin.close()
        try:
            worker.wait(timeout=5)
        except subprocess.TimeoutExpired:
            worker.kill(); worker.wait()


if __name__ == '__main__':
    main()
