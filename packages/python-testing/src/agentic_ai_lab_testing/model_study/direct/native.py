# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Heap-fenced native execution and inert candidate observations."""
import json
import subprocess
import sys
from .tasks import DIRECT_DATA_ALPHABET, digest

def native_run(root, command, log):
    with log.open('w') as output:
        with subprocess.Popen(command, cwd=root, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, bufsize=1) as process:
            for line in process.stdout:
                output.write(line); output.flush()
                sys.stdout.write(line); sys.stdout.flush()
            returncode = process.wait(timeout=5)
    text = log.read_text()
    if (returncode or not all(marker in text for marker in ('MODULE-OK', 'HARNESS-OK', '\nOK\n'))
            or any(marker in text for marker in ('ERROR CASE', 'ERROR CHECK', 'ERROR HARNESS',
                                                'Heap overflow', 'Stack overflow'))):
        raise RuntimeError(f'native qualification failed: {log}')
    return text


def _candidate_bounds(candidate):
    depth = maximum = 0
    for char in candidate:
        depth += (char == '(') - (char == ')')
        maximum = max(maximum, depth)
    invalid = next((index for index, char in enumerate(candidate)
                    if not DIRECT_DATA_ALPHABET.fullmatch(char)), None)
    return {'inputBytes': len(candidate.encode()), 'maximumDepth': maximum,
            'invalidCharacterIndex': invalid}


def score_candidate(root, expected, candidate, destination, program=None, *, normalize=False, worker=None, case=None):
    destination.mkdir(parents=True, exist_ok=False)
    computation = {}
    if program is not None:
        if worker is None:
            text = native_run(root, ['just', 'model-understanding-compute', str(program)],
                              destination/'current-compute.log')
            lines = text.splitlines()
            actual = lines[lines.index('HARNESS-OK direct-compute')-1]+'\n'
        else:
            fresh = worker.compute(case)
            actual = fresh['nativeDatum']
            (destination/'current-compute.log').write_text(json.dumps(fresh, sort_keys=True)+'\n')
        if actual != expected.read_text():
            raise ValueError('current native computation changed; frozen oracle no longer applies')
        current = destination/'current-expected.sexp'; current.write_text(actual)
        expected = current
        computation = {'programSha256': digest(program.read_bytes()),
                       'currentComputeSha256': digest((destination/'current-compute.log').read_bytes())}
    if normalize:
        from ..prediction_transport import prediction_from_output
        raw = candidate
        (destination/'raw-output.txt').write_text(raw)
        candidate = prediction_from_output(raw)
        computation['rawCandidateSha256'] = digest(raw.encode())
        if candidate is None:
            return {'readable': False, 'correct': False, 'transportRejected': True,
                    'transportAmbiguousOrAbsent': True, **computation}
    candidate_path = destination / 'candidate.sexp'
    candidate_path.write_text(candidate)
    bounds = _candidate_bounds(candidate)
    if bounds['inputBytes'] > 8192 or bounds['maximumDepth'] > 64 or bounds['invalidCharacterIndex'] is not None:
        return {'readable': False, 'correct': False, 'transportRejected': True,
                'candidateSha256': digest(candidate.encode()), 'bounds': bounds, **computation}
    if worker is None:
        text = native_run(root, ['just', 'model-understanding-score', str(expected),
                                str(candidate_path)], destination / 'native-score.log')
        result = json.loads(next(line for line in text.splitlines() if line.startswith('{')))
    else:
        result = worker.compute(case, candidate_path)
        (destination/'native-score.log').write_text(json.dumps(result, sort_keys=True)+'\n')
        if result.pop('nativeDatum') != expected.read_text():
            raise ValueError('native task changed during candidate observation')
        result.pop('case')
    return dict(result, candidateSha256=digest(candidate.encode()),
                expectedSha256=digest(expected.read_bytes()), **computation)
