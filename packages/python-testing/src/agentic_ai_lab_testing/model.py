# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Stable metadata for module, module-part, and cross-module cases."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

NAME = re.compile(r"[a-z][a-z0-9._/-]*\Z")
MODULE_NAME = re.compile(r"[A-Za-z][A-Za-z0-9._-]*\Z")


@dataclass(frozen=True)
class ModulePart:
    module: str
    part: str

    def __post_init__(self) -> None:
        if not MODULE_NAME.fullmatch(self.module):
            raise ValueError("module must be a repository module name")
        if not NAME.fullmatch(self.part):
            raise ValueError("part must be a lower-case path")


@dataclass(frozen=True)
class CaseSpec:
    identity: str
    targets: tuple[ModulePart, ...]
    mode: str = "unit"

    def __post_init__(self) -> None:
        if not NAME.fullmatch(self.identity) or "/" in self.identity:
            raise ValueError("case identity must be a lower-case name")
        if not self.targets or len(set(self.targets)) != len(self.targets):
            raise ValueError("case needs distinct module parts")
        if self.mode not in ("unit", "native", "live"):
            raise ValueError("case mode must be unit, native, or live")

    @property
    def composition(self) -> str:
        return "cross" if len({target.module for target in self.targets}) > 1 else "single"


@dataclass(frozen=True)
class CaseContext:
    repository_root: Path
    module_roots: Mapping[str, Path]

    def module_root(self, module: str) -> Path | None:
        return self.module_roots.get(module)


@dataclass(frozen=True)
class CaseEvidence:
    """Small JSON-compatible observations returned by a completed case."""

    details: Mapping[str, object]
