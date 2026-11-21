# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Models for the assessment formal study."""

from __future__ import annotations

from dataclasses import dataclass, replace
import re
from ..assessment_models import CONFIGURATIONS


@dataclass(frozen=True)
class Configuration:
    model: str
    main: str
    constants: str
    invariants: tuple[str, ...]
    properties: tuple[str, ...] = ()
    specification: str = ""
    constraint: str = ""

    def qualified(self, name: str) -> str:
        return name if self.main == self.model else f"{self.main}_{self.model}_{name}"

    def text(self) -> str:
        start = (
            f"SPECIFICATION {self.specification}\n"
            if self.specification
            else "INIT q_init\nNEXT q_step\n"
        )
        result = start + f"CONSTANTS\n{self.constants}\nCHECK_DEADLOCK FALSE\n"
        if self.invariants:
            result += (
                "INVARIANTS " + " ".join(map(self.qualified, self.invariants)) + "\n"
            )
        if self.properties:
            result += "PROPERTIES " + " ".join(self.properties) + "\n"
        if self.constraint:
            result += f"CONSTRAINT {self.constraint}\n"
        return result

    def changed(self, **constants: object) -> Configuration:
        text = self.constants
        for name, value in constants.items():
            literal = (
                ("TRUE" if value else "FALSE")
                if isinstance(value, bool)
                else str(value)
            )
            text, count = re.subn(
                rf"(?m)^{re.escape(name)} = .*", f"{name} = {literal}", text
            )
            if count != 1:
                raise ValueError(f"missing or duplicate constant {self.model}.{name}")
        return replace(self, constants=text)


@dataclass(frozen=True)
class Obligation:
    name: str
    configuration: Configuration
    expected: int = 0
    property: str = ""


def configuration(model: str, environment: dict[str, str]) -> Configuration:
    common = environment.get("ASCENT_FORMAL_GENERATION_CUTOFF")
    bounds = {
        "cutoff": common or "2",
        "views_cutoff": common or "3",
        "actor_cutoff": environment.get("ASCENT_FORMAL_ACTOR_GENERATION_CUTOFF", "2"),
        "round_cutoff": environment.get("ASCENT_FORMAL_ROUND_CUTOFF", "4"),
        "session_cutoff": environment.get(
            "ASCENT_FORMAL_SESSION_GENERATION_CUTOFF", "4"
        ),
    }
    if any(
        re.fullmatch(r"[0-9]+", value) is None or int(value) < 2
        for value in bounds.values()
    ):
        raise ValueError("invalid finite exploration bound")
    if int(bounds["round_cutoff"]) < 3 or int(bounds["session_cutoff"]) < 3:
        raise ValueError("round and session exploration bounds must be at least three")
    fields = CONFIGURATIONS[model]
    constants = re.sub(r"\$(\w+)", lambda match: bounds[match[1]], fields["constants"])
    return Configuration(
        model,
        fields.get("main", model),
        constants,
        tuple(fields["invariants"].split()),
        tuple(fields.get("properties", "").split()),
        fields.get("specification", ""),
        fields.get("constraint", ""),
    )
