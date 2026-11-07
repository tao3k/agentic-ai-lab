# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Scheme task material and independent evaluation-only truth."""
import hashlib
import re

DIRECT_FAMILIES = ('join', 'closure', 'negation', 'capture', 'diagnostic', 'withdrawal')
DIRECT_MODULES = ('program/scheme-language.ss', 'program/scheme-checked.ss',
                  'program/scheme-admission.ss')
DIRECT_DATA_ALPHABET = re.compile(r"[()'\s0-9A-Za-z_?+\-]+\Z")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sexp(value):
    if isinstance(value, list):
        return '(' + ' '.join(sexp(item) for item in value) + ')'
    return str(value)


def finite_rows(family, edges):
    """Independent evaluation oracle, never part of model input."""
    if family == 'join':
        return sorted({(a, d) for a, b in edges for c, d in edges if b == c})
    reachable = set(edges)
    while True:
        expanded = reachable | {(a, d) for a, b in reachable for c, d in edges if b == c}
        if expanded == reachable:
            return sorted(reachable)
        reachable = expanded


def task_data(variant):
    offset = 11 if variant == 'initial' else 41
    edges = ([(offset, offset+1), (offset+1, offset+2), (offset, offset+3)]
             if variant == 'initial' else
             [(offset, offset+1), (offset+1, offset+2), (offset+2, offset), (offset+2, offset+3)])
    return edges, [edges[1]], [edges[-1]], f'gate{offset}', f'other{offset}'


def expected_value(family, variant):
    edges, blocked, replacement, first, _ = task_data(variant)
    if family in ('join', 'closure'):
        return [list(row) for row in finite_rows(family, edges)]
    allowed = lambda omitted: [list(row) for row in sorted(set(edges)-set(omitted))]
    if family == 'negation':
        return allowed(blocked)
    if family == 'withdrawal':
        return [allowed(blocked), allowed(replacement)]
    if family == 'capture':
        return [1, [[first]]]
    return ['invalid-head', ['rule', 0, 'head', 0]] if variant == 'initial' else [
        'invalid-body', ['rule', 0, 'body', 1]]


def task_program(root, family, variant):
    edges, blocked, replacement, first, second = task_data(variant)
    declarations = ''.join(f"(def {name} '{sexp(value)})\n" for name, value in (
        ('edge-data', [list(row) for row in edges]), ('blocked-data', [list(row) for row in blocked]),
        ('replacement-data', [list(row) for row in replacement]),
        ('first-label', first), ('second-label', second)))
    template = (root / 't/model-study/direct-understanding' / f'{family}.ss').read_text()
    if family == 'diagnostic' and variant == 'transfer':
        template = template.replace('(rule (path ?x ?z) (edge ?x ?y))',
            '(rule (path ?x ?y) (edge ?x ?y) (missing ?y ?x))')
    return declarations + '''(def (canonical rows)
  (list-sort (lambda (left right)
    (if (= (car left) (car right)) (< (cadr left) (cadr right))
      (< (car left) (car right)))) rows))
''' + template

