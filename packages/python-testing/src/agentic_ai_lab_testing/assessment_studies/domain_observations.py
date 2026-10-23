# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Collect executed domain values, separately from their Scheme checker."""
import ast
import inspect
import sys
import textwrap
from fractions import Fraction


def row_normalization(function, graph):
    function = inspect.unwrap(function)
    lines, offset = inspect.getsourcelines(function)
    tree = ast.parse(textwrap.dedent(''.join(lines)))
    assignments = [n for n in ast.walk(tree) if isinstance(n,ast.AugAssign) and isinstance(n.target,ast.Name) and n.target.id == 'mutual_weights2']
    if len(assignments) != 1: raise ValueError('unique row normalization update required')
    target = offset + assignments[0].lineno - 1; captured = {}
    def trace(frame,event,arg):
        if frame.f_code is function.__code__ and event=='line':
            if frame.f_lineno==target:captured['before']=frame.f_locals['mutual_weights2'].toarray().copy()
            elif 'before' in captured and 'after' not in captured:captured['after']=frame.f_locals['mutual_weights2'].toarray().copy()
        return trace
    previous=sys.gettrace()
    try:
        sys.settrace(trace);value=function(graph,weight='weight')
    finally:sys.settrace(previous)
    if 'after' not in captured:raise ValueError('no executed normalization observation')
    def pair(v):
        q=Fraction(str(float(v)));return [q.numerator,q.denominator]
    rows=[[f'row-{i}',[pair(x) for x in before],[pair(x) for x in after],[1,10**10]]
          for i,(before,after) in enumerate(zip(captured['before'],captured['after']))]
    return {'value':value,'observations':rows}


def group_schedule(function, graph, group):
    function = inspect.unwrap(function)
    lines, offset = inspect.getsourcelines(function)
    tree = ast.parse(textwrap.dedent(''.join(lines)))
    loops = [n for n in ast.walk(tree) if isinstance(n, ast.For) and isinstance(n.target, ast.Name) and n.target.id == 'y']
    if len(loops) != 1: raise ValueError('unique group-update inner traversal required')
    bodies = [n for n in ast.walk(loops[0]) if isinstance(n, ast.Assign)
              and any(isinstance(t, ast.Name) and t.id == 'Dy' for t in n.targets)]
    if len(bodies) != 1: raise ValueError('unique reachable update body required')
    line = offset + bodies[0].lineno - 1
    groups = {}
    def trace(frame, event, arg):
        if frame.f_code is function.__code__ and event == 'line' and frame.f_lineno == line:
            local = frame.f_locals; key = (local['v'], local['x'])
            if key not in groups: groups[key] = [list(local['group']), list(local['Dx']), []]
            groups[key][2].append(local['y'])
        return trace
    previous = sys.gettrace()
    try:
        sys.settrace(trace); value = function(graph, group, normalized=False)
    finally: sys.settrace(previous)
    if not groups: raise ValueError('no executed group-update observations')
    return {'value': value, 'observations': [[f'update-{i}', *row] for i, row in enumerate(groups.values())]}


def series_precision(function, polynomial, order, variable, precision):
    function = inspect.unwrap(function); captured = {}
    index = polynomial.ring.gens.index(variable)
    leading = min(key[index] for key in polynomial)
    def pair(x): return [int(x.numerator), int(x.denominator)]
    def trace(frame, event, arg):
        if frame.f_code is function.__code__ and event == 'return' and frame.f_locals.get('p') is not None:
            captured['internal'] = frame.f_locals['prec']
        return trace
    previous = sys.gettrace()
    try:
        sys.settrace(trace); result = function(polynomial, order, variable, precision)
    finally: sys.settrace(previous)
    if 'internal' not in captured: raise ValueError('no executed precision observation')
    # Root restoration makes the normalized constant term exponent leading/order.
    # The inputs used here have a nonzero normalized constant coefficient.
    shifted = Fraction(*pair(leading)) / order
    included = any(key[index] == shifted for key in result)
    rows = [['leading-term', pair(leading), order, pair(precision),
             pair(captured['internal']), [0, 1], included]]
    # Copy every returned exponent; Scheme decides strict final-boundary admission.
    for i,key in enumerate(result):
        normalized = Fraction(*pair(key[index])) - shifted
        rows.append([f'term-{i}',pair(leading),order,pair(precision),
                     pair(captured['internal']),pair(normalized),True])
    return {'value': str(result), 'observations': rows}
