# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Bounded inert prediction transport; no evaluation, oracle or answer repair.

Explicit assertions and quoted literals identify predicted data in mixed prose.
Unquoted code fences are only a fallback when no explicit data is supplied.
All explicit predictions must agree after removing their transport wrappers.
"""
import re
from .direct.tasks import DIRECT_DATA_ALPHABET


def _datum(text):
    if len(text.encode()) > 8192 or not DIRECT_DATA_ALPHABET.fullmatch(text):
        return None
    tokens = re.findall(r"[A-Za-z0-9_?+\-]+|[()']", text)
    position = 0
    def read(depth=0):
        nonlocal position
        if depth > 64 or position == len(tokens):
            raise ValueError('bounded datum required')
        token = tokens[position]; position += 1
        if token == "'":
            return ('quote', read(depth+1))
        if token == '(':
            values = []
            while position < len(tokens) and tokens[position] != ')':
                values.append(read(depth+1))
            if position == len(tokens):
                raise ValueError('unclosed datum')
            position += 1
            return tuple(values)
        if token == ')':
            raise ValueError('unexpected closing parenthesis')
        return token
    try:
        value = read()
        if position != len(tokens):
            return None
        return value
    except ValueError:
        return None


def _prediction(text):
    value = _datum(text)
    if value is None:
        return None
    explicit = isinstance(value, tuple) and len(value) == 2 and value[0] == 'quote'
    if isinstance(value, tuple) and len(value) == 3 and value[:2] == ('check-equal?', 'result'):
        value = value[2]
        explicit = isinstance(value, tuple) and len(value) == 2 and value[0] == 'quote'
        if not explicit:
            return None
    if explicit:
        value = value[1]
    def placeholder(node):
        return node == '?' or isinstance(node, tuple) and any(placeholder(x) for x in node)
    return None if placeholder(value) else (value, explicit)


def prediction_from_output(output):
    if len(output.encode()) > 65536:
        return None
    text = output.strip()
    direct = _prediction(text)
    if direct is not None:
        return text
    candidates = []
    for match in re.finditer(r'\(check-equal\?\s+result\s+', text):
        depth = 0
        for index in range(match.start(), len(text)):
            depth += (text[index] == '(') - (text[index] == ')')
            if depth > 64:
                break
            if depth == 0:
                candidates.append(text[match.start():index+1]); break
    candidates += [value.strip() for value in
                   re.findall(r'```(?:scheme|gerbil)?\s*\n(.*?)\n```', text, re.S)]
    parsed = [(candidate, _prediction(candidate)) for candidate in candidates]
    parsed = [(candidate, value) for candidate, value in parsed if value is not None]
    explicit = [(candidate, value) for candidate, value in parsed if value[1]]
    selected = explicit or parsed
    # Never choose by private truth. Different asserted literal data reject,
    # including conflicts between assertion and quote representations.
    if len({value[0] for _, value in selected}) != 1:
        return None
    return selected[0][0]
