# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Register cases once, then select by module, part, and composition."""

from __future__ import annotations

from collections.abc import Callable, Iterator
from dataclasses import dataclass
from pathlib import Path

from .model import CaseContext, CaseEvidence, CaseSpec

Check = Callable[[CaseContext], CaseEvidence | None]


@dataclass(frozen=True)
class RegisteredCase:
    spec: CaseSpec
    check: Check


class CaseRegistry:
    def __init__(self) -> None:
        self._cases: dict[str, RegisteredCase] = {}

    def register(self, spec: CaseSpec, check: Check) -> None:
        if spec.identity in self._cases:
            raise ValueError("duplicate case identity: " + spec.identity)
        if not callable(check):
            raise TypeError("case check must be callable")
        self._cases[spec.identity] = RegisteredCase(spec, check)

    def select(self, *, identity: str | None = None,
               module: str | None = None, part: str | None = None,
               composition: str | None = None, mode: str | None = None
               ) -> tuple[RegisteredCase, ...]:
        if composition not in (None, "single", "cross"):
            raise ValueError("composition must be single or cross")
        if mode not in (None, "unit", "native", "live"):
            raise ValueError("unknown case mode")

        def matches(case: RegisteredCase) -> bool:
            spec = case.spec
            if identity and spec.identity != identity:
                return False
            if composition and spec.composition != composition:
                return False
            if mode and spec.mode != mode:
                return False
            return any((module is None or target.module == module)
                       and (part is None or target.part == part)
                       for target in spec.targets)

        return tuple(case for case in self._cases.values() if matches(case))

    def module_coverage(self, repository_root: Path) -> Iterator[tuple[str, tuple[str, ...]]]:
        """Report every public modules/*/interface.ss path, including gaps."""
        for interface in sorted((repository_root / "modules").glob("*/interface.ss")):
            module = interface.parent.name
            cases = tuple(case.spec.identity for case in self.select(module=module))
            yield module, cases
