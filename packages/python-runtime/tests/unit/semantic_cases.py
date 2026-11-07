# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

def temporal_request():
    return {'lens': {'generation': 1, 'clock': 'clock', 'start': 0, 'end': 10,
                     'asOf': 10, 'cut': 'cut', 'members': ['a', 'b', 'c'],
                     'horizon': 8, 'closed': True},
            'source': {'identity': 'source', 'generation': 1, 'clock': 'clock',
                       'events': [['a', 1, 1], ['b', 2, 2], ['c', 3, 3]],
                       'parents': [['a', 'b'], ['b', 'c']]}, 'root': 'a'}


