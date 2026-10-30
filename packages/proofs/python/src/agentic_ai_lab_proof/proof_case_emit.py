# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Generate language projections from ProofCaseVector v1."""

from __future__ import annotations

import struct
from pathlib import Path

from .proof_case_manifest import ProofCaseSchema


def _upper(name: str) -> str:
    return name.upper()


def _camel(name: str) -> str:
    return "".join(part.capitalize() for part in name.split("_"))


def positive_vector_bytes(schema: ProofCaseSchema) -> bytes:
    vector = bytearray(schema.total_size)
    offsets = {field.name: field.offset for field in schema.fields}
    struct.pack_into("<I", vector, offsets["abi_version"], schema.version)
    struct.pack_into("<I", vector, offsets["case_kind"], schema.case_kinds[0].tag)
    vector[offsets["schema_fingerprint"] : offsets["schema_fingerprint"] + 32] = (
        schema.fingerprint
    )
    for name, value in (
        ("token_digest", 0x11),
        ("policy_revision", 0x22),
        ("effect_digest", 0x33),
        ("semantic_root", 0x44),
        ("execution_root", 0x55),
        ("batch_root", 0x00),
        ("subject_binding", 0x66),
        ("resource_binding", 0x77),
        ("action_binding", 0x88),
        ("previous_evidence_root", 0x99),
    ):
        vector[offsets[name] : offsets[name] + 32] = bytes([value]) * 32
    for name, value in (
        ("nonce", 11),
        ("epoch", 4),
        ("sequence", 19),
        ("required_obligation_mask", schema.required_obligation_mask),
        ("present_obligation_mask", schema.required_obligation_mask),
    ):
        struct.pack_into("<Q", vector, offsets[name], value)
    struct.pack_into("<I", vector, offsets["obligation_count"], len(schema.obligations))
    struct.pack_into(
        "<I", vector, offsets["mediation_outcome"], schema.mediation_outcomes[0].tag
    )
    struct.pack_into(
        "<I", vector, offsets["durability_profile"], schema.durability_profiles[0].tag
    )
    return bytes(vector)


def emit_c(schema: ProofCaseSchema) -> str:
    lines = [
        "// SPDX-FileCopyrightText: 2026 tao3k team and Contributors",
        "//",
        "// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later",
        "",
        "/* Generated from proof-case-vector-v1.toml. Do not edit. */",
        "#ifndef AGENTIC_AI_LAB_PROOF_CASE_VECTOR_V1_H",
        "#define AGENTIC_AI_LAB_PROOF_CASE_VECTOR_V1_H",
        "",
        "#include <stdint.h>",
        "",
        f"#define AGENTIC_AI_LAB_PROOF_CASE_VECTOR_VERSION {schema.version}u",
        f"#define AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE {schema.total_size}u",
        f"#define AGENTIC_AI_LAB_PROOF_CASE_VECTOR_ALIGNMENT {schema.alignment}u",
        f'#define AGENTIC_AI_LAB_PROOF_CASE_SCHEMA_FINGERPRINT "{schema.fingerprint_hex}"',
        "#define AGENTIC_AI_LAB_PROOF_CASE_SCHEMA_FINGERPRINT_BYTES \\",
        "  { "
        + ", ".join(f"0x{value:02x}" for value in schema.fingerprint)
        + " }",
        f"#define AGENTIC_AI_LAB_PROOF_REQUIRED_OBLIGATION_MASK UINT64_C(0x{schema.required_obligation_mask:016x})",
        f'#define AGENTIC_AI_LAB_PROOF_DIGEST_ALGORITHM "{schema.proof_identity.digest_algorithm}"',
        f'#define AGENTIC_AI_LAB_PROOF_VECTOR_DIGEST_DOMAIN "{schema.proof_identity.vector_domain}"',
        f'#define AGENTIC_AI_LAB_PROOF_THEOREM_SET_DIGEST_DOMAIN "{schema.proof_identity.theorem_set_domain}"',
        "",
    ]
    lines.extend(
        f"#define AGENTIC_AI_LAB_PROOF_FIELD_{_upper(field.name)}_OFFSET {field.offset}u"
        for field in schema.fields
    )
    lines.append("")
    for prefix, tags in (
        ("CASE_KIND", schema.case_kinds),
        ("MEDIATION", schema.mediation_outcomes),
        ("DURABILITY", schema.durability_profiles),
    ):
        lines.extend(
            f"#define AGENTIC_AI_LAB_PROOF_{prefix}_{_upper(tag.name)} {tag.tag}u"
            for tag in tags
        )
    lines.append("")
    lines.extend(
        f"#define AGENTIC_AI_LAB_PROOF_OBLIGATION_{_upper(item.name)} UINT64_C(0x{1 << item.bit:016x})"
        for item in schema.obligations
    )
    lines.extend(("", "#endif", ""))
    return "\n".join(lines)


def emit_python(schema: ProofCaseSchema) -> str:
    lines = [
        '"""Generated from proof-case-vector-v1.toml. Do not edit."""',
        "",
        f"ABI_VERSION = {schema.version}",
        f"VECTOR_SIZE = {schema.total_size}",
        f"VECTOR_ALIGNMENT = {schema.alignment}",
        f'SCHEMA_FINGERPRINT_HEX = "{schema.fingerprint_hex}"',
        f"REQUIRED_OBLIGATION_MASK = 0x{schema.required_obligation_mask:016x}",
        f'PROOF_DIGEST_ALGORITHM = "{schema.proof_identity.digest_algorithm}"',
        f'VECTOR_DIGEST_DOMAIN = "{schema.proof_identity.vector_domain}"',
        f'THEOREM_SET_DIGEST_DOMAIN = "{schema.proof_identity.theorem_set_domain}"',
        "AUTHORIZED_EFFECT_THEOREM_NAMES = (",
        *(f'    "{name}",' for name in schema.proof_identity.theorems),
        ")",
        "",
        "FIELD_OFFSETS = {",
    ]
    lines.extend(f'    "{field.name}": {field.offset},' for field in schema.fields)
    lines.extend(("}", "", "CASE_KINDS = {"))
    lines.extend(f'    "{tag.name}": {tag.tag},' for tag in schema.case_kinds)
    lines.extend(("}", "", "MEDIATION_OUTCOMES = {"))
    lines.extend(
        f'    "{tag.name}": {tag.tag},' for tag in schema.mediation_outcomes
    )
    lines.extend(("}", "", "DURABILITY_PROFILES = {"))
    lines.extend(
        f'    "{tag.name}": {tag.tag},' for tag in schema.durability_profiles
    )
    lines.extend(("}", "", "OBLIGATION_BITS = {"))
    lines.extend(
        f'    "{item.name}": {item.bit},' for item in schema.obligations
    )
    lines.extend(("}", ""))
    return "\n".join(lines)


def emit_lean(schema: ProofCaseSchema) -> str:
    positive = positive_vector_bytes(schema)
    lines = [
        "-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors",
        "--",
        "-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later",
        "",
        "/- Generated from proof-case-vector-v1.toml. Do not edit. -/",
        "namespace AgenticAILabProof.Generated.ProofCaseVector",
        "",
        f"def abiVersion : UInt32 := {schema.version}",
        f"def vectorSize : Nat := {schema.total_size}",
        f"def vectorAlignment : Nat := {schema.alignment}",
        f'def schemaFingerprintHex : String := "{schema.fingerprint_hex}"',
        "def schemaFingerprintBytes : List UInt8 := ["
        + ", ".join(f"0x{value:02x}" for value in schema.fingerprint)
        + "]",
        f"def requiredObligationMask : UInt64 := 0x{schema.required_obligation_mask:016x}",
        f'def proofDigestAlgorithm : String := "{schema.proof_identity.digest_algorithm}"',
        f'def vectorDigestDomain : String := "{schema.proof_identity.vector_domain}"',
        f'def theoremSetDigestDomain : String := "{schema.proof_identity.theorem_set_domain}"',
        "def authorizedEffectTheoremNames : List String := [",
        *(f'  "{name}",' for name in schema.proof_identity.theorems),
        "]",
        "def canonicalPositiveVectorBytes : List UInt8 := ["
        + ", ".join(f"0x{value:02x}" for value in positive)
        + "]",
        "",
    ]
    for prefix, tags in (
        ("caseKind", schema.case_kinds),
        ("mediation", schema.mediation_outcomes),
        ("durability", schema.durability_profiles),
    ):
        lines.extend(
            f"def {prefix}{_camel(tag.name)} : UInt32 := {tag.tag}" for tag in tags
        )
    lines.append("")
    lines.extend(
        f"def field{_camel(field.name)}Offset : Nat := {field.offset}"
        for field in schema.fields
    )
    lines.append("")
    lines.extend(
        f"def obligation{_camel(item.name)} : UInt64 := 0x{1 << item.bit:016x}"
        for item in schema.obligations
    )
    lines.extend(("", "end AgenticAILabProof.Generated.ProofCaseVector", ""))
    return "\n".join(lines)


def emit_scheme(schema: ProofCaseSchema) -> str:
    constants = [
        ("agentic-ai-lab-proof-case-abi-version", schema.version),
        ("agentic-ai-lab-proof-case-vector-size", schema.total_size),
        ("agentic-ai-lab-proof-case-vector-alignment", schema.alignment),
        ("agentic-ai-lab-proof-required-obligation-mask", schema.required_obligation_mask),
    ]
    constants.extend(
        (f"agentic-ai-lab-proof-field-{field.name.replace('_', '-')}-offset", field.offset)
        for field in schema.fields
    )
    constants.extend(
        (f"agentic-ai-lab-proof-case-kind-{tag.name.replace('_', '-')}", tag.tag)
        for tag in schema.case_kinds
    )
    constants.extend(
        (f"agentic-ai-lab-proof-mediation-{tag.name.replace('_', '-')}", tag.tag)
        for tag in schema.mediation_outcomes
    )
    constants.extend(
        (f"agentic-ai-lab-proof-durability-{tag.name.replace('_', '-')}", tag.tag)
        for tag in schema.durability_profiles
    )
    names = [name for name, _ in constants]
    names.extend(
        [
            "agentic-ai-lab-proof-case-schema-fingerprint",
            "agentic-ai-lab-proof-vector-digest-domain",
            "agentic-ai-lab-proof-theorem-set-digest-domain",
        ]
    )
    lines = [
        ";;; Generated from proof-case-vector-v1.toml. Do not edit.",
        "(export " + "\n        ".join(names) + ")",
        "",
    ]
    lines.extend(f"(def {name} {value})" for name, value in constants)
    lines.extend(
        [
            f'(def agentic-ai-lab-proof-case-schema-fingerprint "{schema.fingerprint_hex}")',
            f'(def agentic-ai-lab-proof-vector-digest-domain "{schema.proof_identity.vector_domain}")',
            f'(def agentic-ai-lab-proof-theorem-set-digest-domain "{schema.proof_identity.theorem_set_domain}")',
            "",
        ]
    )
    return "\n".join(lines)


def emit_vectors(schema: ProofCaseSchema) -> tuple[str, str]:
    vector = positive_vector_bytes(schema)
    positive = vector.hex() + "\n"
    malformed = vector[:-1].hex() + "\n"
    return positive, malformed


def generated_artifacts(schema: ProofCaseSchema) -> dict[Path, str]:
    positive, malformed = emit_vectors(schema)
    return {
        Path("lean/native/agentic_ai_lab_proof_case_vector_v1.h"): emit_c(schema),
        Path("../../bindings/runtime-c/include/agentic_ai_lab/proof_case_vector_v1.h"): emit_c(
            schema
        ),
        Path("lean/AgenticAILabProof/Generated/ProofCaseVector.lean"): emit_lean(schema),
        Path("../../modules/proof/projections/generated/proof-case-vector-v1.ss"): emit_scheme(schema),
        Path("python/src/agentic_ai_lab_proof/generated/proof_case_vector.py"): emit_python(
            schema
        ),
        Path("vectors/proof_case_vector_v1_positive.hex"): positive,
        Path("vectors/proof_case_vector_v1_malformed_truncated.hex"): malformed,
    }


def write_generated_artifacts(
    proof_root: Path, schema: ProofCaseSchema, *, check: bool
) -> tuple[Path, ...]:
    stale: list[Path] = []
    for relative_path, content in generated_artifacts(schema).items():
        path = proof_root / relative_path
        if not path.exists() or path.read_text(encoding="utf-8") != content:
            stale.append(relative_path)
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
    return tuple(stale)
