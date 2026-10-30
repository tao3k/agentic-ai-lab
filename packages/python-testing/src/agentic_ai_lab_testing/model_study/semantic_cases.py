# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Current semantic ABI tasks, independent of historical paid-study plans."""
from copy import deepcopy


def corpus():
    task = {'lens': {'generation': 1, 'clock': 'clock', 'start': 0, 'end': 10,
                     'asOf': 10, 'cut': 'cut', 'members': ['a', 'b', 'c'],
                     'horizon': 8, 'closed': True},
            'source': {'identity': 'source', 'generation': 1, 'clock': 'clock',
                       'events': [['a', 1, 1], ['b', 2, 2], ['c', 3, 3]],
                       'parents': [['a', 'b'], ['b', 'c']]}, 'root': 'a'}
    cases = []
    for name in ['chain', 'branch', 'withdrawal', 'open-cut', 'late-ingestion',
                 'interval', 'zero-horizon', 'one-horizon', 'clock-mismatch',
                 'generation-mismatch', 'window-end', 'unknown-time']:
        item = deepcopy(task)
        if name == 'branch':
            item['source']['parents'] = [['a', 'b'], ['a', 'c']]
        elif name == 'withdrawal':
            item['source']['parents'] = []
        elif name == 'open-cut':
            item['lens']['closed'] = False
        elif name == 'late-ingestion':
            item['lens']['asOf'] = 1
        elif name == 'interval':
            item['source']['events'][1][1] = ['between', 0, 20]
        elif name == 'zero-horizon':
            item['lens']['horizon'] = 0
        elif name == 'one-horizon':
            item['lens']['horizon'] = 1
        elif name == 'clock-mismatch':
            item['source']['clock'] = 'other-clock'
        elif name == 'generation-mismatch':
            item['source']['generation'] = 2
        elif name == 'window-end':
            item['lens']['end'] = 3
        elif name == 'unknown-time':
            item['source']['events'][1][1] = 'unknown'
        rename = {'a': 'x', 'b': 'y', 'c': 'z'}
        item['root'] = rename[item['root']]
        item['lens']['members'] = [rename[n] for n in item['lens']['members']]
        item['lens']['generation'] += 80
        item['source']['generation'] += 80
        item['source']['identity'] = 'deterministic-source-' + name
        item['lens']['cut'] = 'deterministic-cut-' + name
        for field in ('start', 'end', 'asOf'):
            item['lens'][field] += 79
        for event in item['source']['events']:
            event[0] = rename[event[0]]
            if isinstance(event[1], int):
                event[1] += 79
            elif isinstance(event[1], list):
                event[1][1:] = [bound + 79 for bound in event[1][1:]]
            event[2] += 79
        item['source']['parents'] = [[rename[x] for x in edge] for edge in item['source']['parents']]
        cases.append({'id': name, 'request': item})
    return cases
