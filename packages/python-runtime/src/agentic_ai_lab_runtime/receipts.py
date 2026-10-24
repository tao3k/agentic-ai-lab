# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Typed helpers for Agentic AI Lab receipts, including local domain descriptions.

Parsing a receipt does not establish its producer or native execution authority.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class RuntimeReceipt:
    version: str
    fields: dict[str, str]

    @property
    def kind(self) -> str:
        return self.require("kind")

    @property
    def plan_digest(self) -> str | None:
        return self.fields.get("plan-digest")

    def require(self, key: str) -> str:
        try:
            return self.fields[key]
        except KeyError as exc:
            raise ValueError(f"missing runtime receipt field: {key}") from exc

    def integer(self, key: str) -> int:
        value = self.require(key)
        try:
            return int(value, 10)
        except ValueError as exc:
            raise ValueError(
                f"runtime receipt field is not an integer: {key}={value}"
            ) from exc


def parse_runtime_receipt(receipt: bytes) -> RuntimeReceipt:
    if not isinstance(receipt, bytes):
        raise TypeError("runtime receipts must be bytes")

    try:
        text = receipt.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError("runtime receipt is not valid UTF-8") from exc

    lines = [line for line in text.splitlines() if line]
    if not lines or lines[0] != "agentic-ai-lab-receipt.v1":
        raise ValueError("runtime receipt has unsupported version")

    fields: dict[str, str] = {}
    for line in lines[1:]:
        key, separator, value = line.partition("=")
        if separator != "=" or not key:
            raise ValueError(f"runtime receipt has invalid field line: {line}")
        fields[key] = value

    return RuntimeReceipt(version=lines[0], fields=fields)
