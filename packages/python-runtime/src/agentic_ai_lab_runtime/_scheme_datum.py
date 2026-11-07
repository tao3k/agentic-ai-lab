# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Scheme datum parser for Python-side runtime projection rows."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

SchemeRows = Mapping[str, Any] | Sequence[tuple[Any, Any] | Sequence[Any]]


def parse_scheme_datum(source: str) -> SchemeRows:
    parser = _SchemeDatumParser(source)
    value = parser.parse()
    if not isinstance(value, tuple):
        raise ValueError("Scheme load projection did not return a row sequence")
    return value


def write_scheme_datum(value: Any) -> str:
    if isinstance(value, bool):
        if value:
            return "#t"
        return "#f"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return f'"{_escape_scheme_string(value)}"'
    if isinstance(value, (tuple, list)):
        return "(" + " ".join(write_scheme_datum(item) for item in value) + ")"
    raise TypeError(f"unsupported Scheme datum value: {type(value).__name__}")


class _SchemeDatumParser:
    def __init__(self, source: str) -> None:
        self._source = source
        self._index = 0

    def parse(self) -> Any:
        value = self._datum()
        self._skip_space()
        if self._index != len(self._source):
            raise ValueError("unexpected trailing data in Scheme load projection")
        return value

    def _datum(self) -> Any:
        self._skip_space()
        ch = self._peek()
        if ch == "(":
            return self._list()
        if ch == '"':
            return self._string()
        if ch == "#" and self._peek_next() == "(":
            self._index += 1
            return self._list()
        return self._atom()

    def _list(self) -> Any:
        self._consume("(")
        items: list[Any] = []
        while True:
            self._skip_space()
            ch = self._peek()
            if ch == ")":
                self._index += 1
                return tuple(items)
            if self._dot_token():
                if not items:
                    raise ValueError("dotted Scheme pair is missing head")
                self._index += 1
                cdr = self._datum()
                self._skip_space()
                self._consume(")")
                result = cdr
                for item in reversed(items):
                    result = (item, result)
                return result
            items.append(self._datum())

    def _string(self) -> str:
        self._consume('"')
        chars: list[str] = []
        while True:
            if self._index >= len(self._source):
                raise ValueError("unterminated Scheme string")
            ch = self._source[self._index]
            self._index += 1
            if ch == '"':
                return "".join(chars)
            if ch != "\\":
                chars.append(ch)
                continue
            if self._index >= len(self._source):
                raise ValueError("unterminated Scheme string escape")
            escaped = self._source[self._index]
            self._index += 1
            chars.append("\n" if escaped == "n" else escaped)

    def _atom(self) -> Any:
        start = self._index
        while self._index < len(self._source):
            ch = self._source[self._index]
            if ch.isspace() or ch in "()":
                break
            self._index += 1
        if self._index == start:
            raise ValueError("expected Scheme datum")
        token = self._source[start : self._index]
        if token == "#t":
            return True
        if token == "#f":
            return False
        if token.lstrip("+-").isdigit():
            return int(token)
        return token

    def _skip_space(self) -> None:
        while self._index < len(self._source) and self._source[self._index].isspace():
            self._index += 1

    def _peek(self) -> str:
        if self._index >= len(self._source):
            raise ValueError("unexpected end of Scheme load projection")
        return self._source[self._index]

    def _peek_next(self) -> str | None:
        next_index = self._index + 1
        if next_index >= len(self._source):
            return None
        return self._source[next_index]

    def _consume(self, expected: str) -> None:
        if self._peek() != expected:
            raise ValueError(f"expected Scheme token: {expected}")
        self._index += 1

    def _dot_token(self) -> bool:
        if self._index >= len(self._source) or self._source[self._index] != ".":
            return False
        next_index = self._index + 1
        return (
            next_index >= len(self._source)
            or self._source[next_index].isspace()
            or self._source[next_index] == ")"
        )


def _escape_scheme_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


__all__ = ["SchemeRows", "parse_scheme_datum", "write_scheme_datum"]
