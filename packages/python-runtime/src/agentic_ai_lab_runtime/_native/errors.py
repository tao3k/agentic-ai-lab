# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Typed failures for native runtime loading and negotiation."""

from __future__ import annotations


class NativeRuntimeError(RuntimeError):
    """Base error for the private runtime-v0 adapter."""

    def __init__(self, message: str, *, status: int | None = None) -> None:
        super().__init__(message)
        self.status = status


class NativeRuntimeLoadError(NativeRuntimeError):
    """The qualified native library could not be loaded or negotiated."""
