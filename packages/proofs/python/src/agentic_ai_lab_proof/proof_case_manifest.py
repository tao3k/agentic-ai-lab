# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Typed loader and validator for the canonical proof-case vector manifest."""

from __future__ import annotations

import hashlib
import json
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class Field:
    name: str
    offset: int
    width: int
    kind: str


@dataclass(frozen=True)
class Tag:
    name: str
    tag: int


@dataclass(frozen=True)
class ObligationBit:
    name: str
    bit: int


@dataclass(frozen=True)
class ProofIdentity:
    digest_algorithm: str
    vector_domain: str
    theorem_set_domain: str
    theorems: tuple[str, ...]


@dataclass(frozen=True)
class ProofCaseSchema:
    schema: str
    version: int
    endianness: str
    alignment: int
    total_size: int
    fields: tuple[Field, ...]
    case_kinds: tuple[Tag, ...]
    mediation_outcomes: tuple[Tag, ...]
    durability_profiles: tuple[Tag, ...]
    obligations: tuple[ObligationBit, ...]
    proof_identity: ProofIdentity
    canonical_payload: bytes

    @property
    def fingerprint(self) -> bytes:
        return hashlib.sha256(self.canonical_payload).digest()

    @property
    def fingerprint_hex(self) -> str:
        return self.fingerprint.hex()

    @property
    def required_obligation_mask(self) -> int:
        return sum(1 << obligation.bit for obligation in self.obligations)


def _unique(values: list[int] | list[str], label: str) -> None:
    if len(values) != len(set(values)):
        raise ValueError(f"duplicate {label}")


def _tags(raw: dict[str, Any], key: str) -> tuple[Tag, ...]:
    values = tuple(Tag(str(item["name"]), int(item["tag"])) for item in raw[key])
    _unique([value.name for value in values], f"{key} name")
    _unique([value.tag for value in values], f"{key} tag")
    if any(value.tag <= 0 for value in values):
        raise ValueError(f"{key} tags must be positive")
    return values


def load_proof_case_schema(path: Path) -> ProofCaseSchema:
    raw = tomllib.loads(path.read_text(encoding="utf-8"))
    schema_identity = {
        key: value for key, value in raw.items() if key != "proof_identity"
    }
    canonical_payload = json.dumps(
        schema_identity, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("ascii")
    fields = tuple(
        Field(
            str(item["name"]),
            int(item["offset"]),
            int(item["width"]),
            str(item["kind"]),
        )
        for item in raw["fields"]
    )
    _unique([field.name for field in fields], "field name")
    if any(field.kind not in {"u32", "u64", "bytes"} for field in fields):
        raise ValueError("unsupported field kind")
    if any(
        (field.kind == "u32" and field.width != 4)
        or (field.kind == "u64" and field.width != 8)
        for field in fields
    ):
        raise ValueError("integer field width does not match its kind")
    if any(field.width <= 0 or field.offset < 0 for field in fields):
        raise ValueError("field width and offset must be positive")
    if list(fields) != sorted(fields, key=lambda field: field.offset):
        raise ValueError("fields must be ordered by offset")
    for previous, current in zip(fields, fields[1:], strict=False):
        if previous.offset + previous.width > current.offset:
            raise ValueError(f"field overlap: {previous.name} and {current.name}")

    total_size = int(raw["total_size"])
    if not fields or fields[-1].offset + fields[-1].width != total_size:
        raise ValueError("total_size does not match the field layout")
    alignment = int(raw["alignment"])
    if alignment <= 0 or total_size % alignment != 0:
        raise ValueError("total_size must honor alignment")
    if raw["endianness"] != "little":
        raise ValueError("proof-case vector v1 requires little endian")

    obligations = tuple(
        ObligationBit(str(item["name"]), int(item["bit"]))
        for item in raw["obligations"]
    )
    _unique([value.name for value in obligations], "obligation name")
    _unique([value.bit for value in obligations], "obligation bit")
    if any(value.bit < 0 or value.bit >= 64 for value in obligations):
        raise ValueError("obligation bits must fit uint64")

    identity_raw = raw["proof_identity"]
    proof_identity = ProofIdentity(
        digest_algorithm=str(identity_raw["digest_algorithm"]),
        vector_domain=str(identity_raw["vector_domain"]),
        theorem_set_domain=str(identity_raw["theorem_set_domain"]),
        theorems=tuple(str(value) for value in identity_raw["theorems"]),
    )
    if proof_identity.digest_algorithm != "sha256":
        raise ValueError("proof identity v1 requires sha256")
    if not proof_identity.vector_domain or not proof_identity.theorem_set_domain:
        raise ValueError("proof identity domains must not be empty")
    if proof_identity.vector_domain == proof_identity.theorem_set_domain:
        raise ValueError("proof identity domains must be distinct")
    _unique(list(proof_identity.theorems), "proof theorem")
    if proof_identity.theorems != tuple(value.name for value in obligations):
        raise ValueError("proof theorem set must match canonical obligations")

    return ProofCaseSchema(
        schema=str(raw["schema"]),
        version=int(raw["version"]),
        endianness=str(raw["endianness"]),
        alignment=alignment,
        total_size=total_size,
        fields=fields,
        case_kinds=_tags(raw, "case_kinds"),
        mediation_outcomes=_tags(raw, "mediation_outcomes"),
        durability_profiles=_tags(raw, "durability_profiles"),
        obligations=obligations,
        proof_identity=proof_identity,
        canonical_payload=canonical_payload,
    )
