# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Bounded inert Scheme datum transport, ABI 1. Never eval or general read."""
import math
import re


def dumps(value, *, _depth=0):
    if _depth > 64:
        raise ValueError('Scheme datum depth exceeds 64')
    emit = lambda v: dumps(v, _depth=_depth + 1)
    if value is None:
        return 'null'
    if type(value) is bool:
        return '#t' if value else '#f'
    if type(value) in (int, float):
        if type(value) is int and not -(2**127) <= value < 2**127:
            raise ValueError('integer bound')
        if type(value) is float and not math.isfinite(value):
            raise ValueError('nonfinite number')
        return str(value)
    if isinstance(value, str):
        if any(ord(c) < 32 and c not in '\n\r\t' for c in value):
            raise ValueError('control character')
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t') + '"'
    if isinstance(value, (list, tuple)):
        return '(list' + ''.join(' ' + emit(v) for v in value) + ')'
    if isinstance(value, dict):
        if not all(isinstance(k, str) for k in value):
            raise ValueError('object keys must be strings')
        return '(object' + ''.join(' (' + emit(k) + ' ' + emit(value[k]) + ')' for k in sorted(value)) + ')'
    raise ValueError('unsupported Scheme wire value')


def loads(data, *, max_bytes=16777216):
    if isinstance(data, bytes):
        if len(data) > max_bytes: raise ValueError('Scheme byte bound')
        data = data.decode('utf-8')
    if not isinstance(data, str) or len(data.encode('utf-8')) > max_bytes:
        raise ValueError('Scheme byte bound')
    i = 0
    nodes = 0
    def space():
        nonlocal i
        while i < len(data) and data[i] in ' \n\r\t': i += 1
    def expect(c):
        nonlocal i
        space()
        if i >= len(data) or data[i] != c: raise ValueError('invalid Scheme datum')
        i += 1
    def parse(depth):
        nonlocal i, nodes
        nodes += 1
        if depth > 64 or nodes > 262144: raise ValueError('Scheme structural bound')
        space()
        if i >= len(data): raise ValueError('truncated Scheme datum')
        if data[i] == '"':
            i += 1
            chars = []
            while i < len(data):
                c = data[i]; i += 1
                if c == '"': return ''.join(chars)
                if c == '\\':
                    if i >= len(data): raise ValueError('truncated escape')
                    c = data[i]; i += 1
                    escapes = {'n':'\n','r':'\r','t':'\t','"':'"','\\':'\\'}
                    if c not in escapes: raise ValueError('unsupported escape')
                    c = escapes[c]
                elif ord(c) < 32: raise ValueError('unescaped control')
                chars.append(c)
            raise ValueError('unterminated string')
        if data[i] == '(':
            i += 1
            start = i
            while i < len(data) and data[i] not in ' ()\n\r\t': i += 1
            kind = data[start:i]
            if kind not in ('object', 'list'): raise ValueError('unknown Scheme constructor')
            result = {} if kind == 'object' else []
            while True:
                space()
                if i >= len(data): raise ValueError('unterminated list')
                if data[i] == ')': i += 1; return result
                if kind == 'list': result.append(parse(depth + 1))
                else:
                    expect('(')
                    key = parse(depth + 1)
                    if not isinstance(key, str) or key in result: raise ValueError('invalid or duplicate field')
                    result[key] = parse(depth + 1)
                    expect(')')
        start = i
        while i < len(data) and data[i] not in ' ()\n\r\t': i += 1
        atom = data[start:i]
        if atom == '#t': return True
        if atom == '#f': return False
        if atom == 'null': return None
        if len(atom) > 64 or not re.fullmatch(r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?', atom):
            raise ValueError('unsupported Scheme atom')
        value = float(atom) if any(c in atom for c in '.eE') else int(atom)
        if isinstance(value, float) and not math.isfinite(value): raise ValueError('nonfinite number')
        if isinstance(value, int) and not -(2**127) <= value < 2**127: raise ValueError('integer bound')
        return value
    value = parse(0)
    space()
    if i != len(data): raise ValueError('trailing Scheme datum')
    return value
