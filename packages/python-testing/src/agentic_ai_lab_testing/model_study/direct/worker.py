# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""One native lifetime for frozen trusted tasks; model outputs remain data."""
import json
import subprocess
import sys
from .tasks import DIRECT_FAMILIES, task_program


def worker_source(root):
    core = root/'t/model-study/direct-understanding/prediction-core.ss'
    source = f'(import :std/encoding/json :gerbil-ascent/program/scheme-language "{core}")\n'
    source += '(displayln "MODULE-OK :gerbil-ascent/program/scheme-language") (force-output)\n'
    source += '(def computations (make-hash-table))\n'
    for family in DIRECT_FAMILIES:
        for variant in ('initial', 'transfer'):
            source += f'(hash-put! computations "{family}-{variant}" (lambda ()\n'
            source += task_program(root, family, variant)+'\nresult))\n'
    return source+(root/'t/model-study/direct-understanding/worker-loop.ss').read_text()


class NativeStudyWorker:
    def __init__(self, root, script, log):
        self.log = log.open('w')
        self.process = subprocess.Popen(['just', 'model-understanding-compute', str(script)],
            cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, bufsize=1)
        self.ready = False
        try:
            self._read(lambda line: line.startswith('HARNESS-OK worker-ready'))
            self.ready = True
        except BaseException:
            self.close(); raise

    def _read(self, accept):
        failure = None
        for line in self.process.stdout:
            self.log.write(line); self.log.flush()
            sys.stdout.write(line); sys.stdout.flush()
            if any(line.startswith(marker) for marker in ('ERROR CASE', 'ERROR CHECK', 'ERROR HARNESS', '*** ERROR')):
                failure = line.strip()
                self.process.stdin.close()
            if failure is None and accept(line):
                return line
        raise RuntimeError(f'native study worker ended without a receipt: {failure}')

    def compute(self, case, candidate=None):
        self.process.stdin.write(json.dumps({'case': case, 'candidate': str(candidate) if candidate else None})+'\n')
        self.process.stdin.flush()
        result = json.loads(self._read(lambda line: line.startswith('{')))
        if result['case'] != case:
            raise RuntimeError('native task receipt identity mismatch')
        return result

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            try:
                if self.ready:
                    self._read(lambda line: line.strip() == 'OK')
                returncode = self.process.wait(timeout=5)
                if self.ready and returncode:
                    raise RuntimeError('native study worker closed unsuccessfully')
            except subprocess.TimeoutExpired:
                self.process.kill(); self.process.wait()
                raise RuntimeError('native study worker failed to close')
        self.process.stdout.close(); self.log.close()
