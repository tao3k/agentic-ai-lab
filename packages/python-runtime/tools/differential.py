# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Generate current installed-Python/native fixtures; run in a separate process."""
import argparse
import hashlib
from agentic_ai_lab_runtime.scheme_wire import dumps
from pathlib import Path
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--library', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(root / 'packages/python-runtime/tests/unit'))
from test_temporal_family import family_task
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntime

cases = []
with SemanticRuntime(args.library, expected_digest=hashlib.sha256(args.library.read_bytes()).hexdigest()) as runtime:
    for vocabulary in ['release', 'medication']:
        for mode in ['necessary', 'overlap', 'incomplete', 'budget', 'unknown']:
            task = family_task(vocabulary)
            if mode == 'overlap': task['model']['mode'] = 'overlapping-mechanisms'
            if mode == 'incomplete': task['model']['complete'] = False
            if mode == 'budget': task['query']['limit'] = 1
            if mode == 'unknown': task['model']['observations'][0]['modality'] = 'declared'
            result = runtime.classify_temporal_family(task)
            cases.append(dict(name=vocabulary+'-'+mode, operation='temporal.family.classify', payload=task, expected=result))
            print('PYTHON-NATIVE-COMPLETED', vocabulary, mode, 'classify', flush=True)
            payload = {'task': task, 'candidate': result}
            cases.append(dict(name=vocabulary+'-'+mode+'-observe', operation='temporal.family.observe', payload=payload,
                              expected=runtime.call('temporal.family.observe', payload)))
            print('PYTHON-NATIVE-COMPLETED', vocabulary, mode, 'observe', flush=True)
    lens = {'lens': {'generation': 1, 'clock': 'c', 'start': 0, 'end': 5,
                    'asOf': 5, 'cut': 'cut', 'members': ['a', 'b'], 'horizon': 8, 'closed': True},
            'source': {'identity': 'source', 'generation': 1, 'clock': 'c',
                       'events': [['a', 1, 1], ['b', 2, 2]], 'parents': [['a', 'b']]}, 'root': 'a'}
    result = runtime.call('temporal.solve', lens)
    cases.append(dict(name='lens-solve', operation='temporal.solve', payload=lens, expected=result))
args.output.write_text(dumps(cases) + '\n')
print(f'PYTHON-NATIVE-ORACLE {len(cases)} results', flush=True)
