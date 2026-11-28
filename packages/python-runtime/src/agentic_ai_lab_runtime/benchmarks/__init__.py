# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Lazy benchmark module exports for CLI-safe execution."""

from __future__ import annotations

from importlib import import_module
from types import ModuleType

__all__ = ["composition", "langgraph_alignment", "scheme_load_aot"]


def __getattr__(name: str) -> ModuleType:
    if name not in __all__:
        raise AttributeError(name)
    return import_module(f"{__name__}.{name}")
