# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Serialize actual Scheme checker results for Lean/Quint correspondence."""
import argparse
from fractions import Fraction
from itertools import product
import json
from pathlib import Path
from ascent import Engine


def generate(engine, destination):
    destination.mkdir(parents=True, exist_ok=True)
    grids = {
        'graph': ('graph-update', list(product(range(2), range(2), range(5), range(5), range(5)))),
        'precision': ('series-precision', list(product(range(-2, 3), (-2, -1, 1, 2), range(4), range(-2, 3), (-1, 0, 1), (0, 1)))),
    }
    counts = {}
    for name, (kind, values) in grids.items():
        output = []
        for start in range(0, len(values), 256):
            batch = values[start:start+256]; observations = []
            for index, v in enumerate(batch):
                if name == 'graph': row = [str(start+index), *v]
                else:
                    m,n,p,e,delta,included = v
                    # Generate a candidate input; Lean/Quint independently determine verdicts.
                    candidate = Fraction(p)-Fraction(m,n)+delta
                    row = [str(start+index), [m,1], n, [p,1],
                           [candidate.numerator,candidate.denominator], [e,1], bool(included)]
                observations.append(row)
            checked = engine.request({'operation':'domain-check','kind':kind,'observations':observations})
            output.extend([list(v)+[int(flag) for _,flag in c['claims']]
                           for v,c in zip(batch,checked['checks'])])
        (destination/f'scheme-{name}.json').write_text(json.dumps(output)+'\n')
        counts[name] = len(output)
    return counts


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('library',type=Path);parser.add_argument('destination',type=Path)
    args=parser.parse_args()
    with Engine(args.library) as engine:print('DOMAIN-CONFORMANCE',generate(engine,args.destination),flush=True)
