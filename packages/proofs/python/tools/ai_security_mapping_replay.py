#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Digest-bound replay for an AI security framework mapping bundle.

This is an internal proof verifier, not a public Agentic AI Lab module API.  It
recomputes bundle metrics from claims and checks the versioned receipt without
treating digest integrity as issuer authentication or transparency inclusion.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


BUNDLE_SCHEMA_ID = "ai-security-framework-mapping-bundle"
BUNDLE_SCHEMA_VERSION = "1"
RECEIPT_SCHEMA_ID = "ai-security-proof-regression-receipt"
RECEIPT_SCHEMA_VERSION = "1"
REPLAY_SCHEMA_ID = "ai-security-artifact-replay"
REPLAY_SCHEMA_VERSION = "1"

ADMITTED_STATUSES = frozenset({"exact", "refinement", "projection"})
ESCALATED_STATUSES = frozenset({"partial", "conflicting", "unknown"})
KNOWN_STATUSES = ADMITTED_STATUSES | ESCALATED_STATUSES


class ReplayValidationError(ValueError):
    """The exact artifact bundle cannot be admitted for replay."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ReplayValidationError(message)


def load_json_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ReplayValidationError(f"{path}: invalid JSON: {error}") from error
    require(isinstance(value, dict), f"{path}: top-level value must be an object")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as source:
            for block in iter(lambda: source.read(65536), b""):
                digest.update(block)
    except OSError as error:
        raise ReplayValidationError(f"{path}: cannot hash artifact: {error}") from error
    return digest.hexdigest()


def require_schema(
    value: dict[str, Any],
    *,
    schema_id: str,
    schema_version: str,
    label: str,
) -> None:
    require(value.get("schemaId") == schema_id, f"{label}: wrong schemaId")
    require(
        value.get("schemaVersion") == schema_version,
        f"{label}: wrong schemaVersion",
    )


def require_nonempty_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and bool(value), f"{label}: expected string")
    return value


def require_nonnegative_int(value: Any, label: str) -> int:
    require(
        isinstance(value, int) and not isinstance(value, bool) and value >= 0,
        f"{label}: expected nonnegative integer",
    )
    return value


def replay_mapping_bundle(
    bundle_path: Path,
    receipt_path: Path,
) -> dict[str, Any]:
    bundle = load_json_object(bundle_path)
    receipt = load_json_object(receipt_path)

    require_schema(
        bundle,
        schema_id=BUNDLE_SCHEMA_ID,
        schema_version=BUNDLE_SCHEMA_VERSION,
        label="bundle",
    )
    require_schema(
        receipt,
        schema_id=RECEIPT_SCHEMA_ID,
        schema_version=RECEIPT_SCHEMA_VERSION,
        label="receipt",
    )

    bundle_id = require_nonempty_string(bundle.get("bundleId"), "bundle.bundleId")
    receipt_id = require_nonempty_string(
        receipt.get("receiptId"),
        "receipt.receiptId",
    )
    owner = require_nonempty_string(bundle.get("owner"), "bundle.owner")
    require(receipt.get("owner") == owner, "receipt owner does not match bundle")

    receipt_bundle = receipt.get("bundle")
    require(isinstance(receipt_bundle, dict), "receipt.bundle must be an object")
    require(
        receipt_bundle.get("bundleId") == bundle_id,
        "receipt bundleId does not match bundle",
    )

    bundle_sha256 = sha256_file(bundle_path)
    require(
        receipt_bundle.get("sha256") == bundle_sha256,
        "receipt digest does not match exact bundle bytes",
    )

    sources = bundle.get("sources")
    require(isinstance(sources, list) and bool(sources), "bundle.sources is empty")
    for index, source in enumerate(sources):
        require(isinstance(source, dict), f"sources[{index}] must be an object")
        require_nonempty_string(source.get("frameworkId"), f"sources[{index}].frameworkId")
        require_nonempty_string(
            source.get("coordinateKind"),
            f"sources[{index}].coordinateKind",
        )
        require_nonempty_string(source.get("url"), f"sources[{index}].url")
        require_nonempty_string(
            source.get("sourceStatus"),
            f"sources[{index}].sourceStatus",
        )

    claims = bundle.get("claims")
    require(isinstance(claims, list) and bool(claims), "bundle.claims is empty")

    claim_ids: set[str] = set()
    admitted_count = 0
    escalated_count = 0
    csa_final_mapping_seen = False

    for index, claim in enumerate(claims):
        require(isinstance(claim, dict), f"claims[{index}] must be an object")
        claim_id = require_nonempty_string(
            claim.get("claimId"),
            f"claims[{index}].claimId",
        )
        require(claim_id not in claim_ids, f"duplicate claimId: {claim_id}")
        claim_ids.add(claim_id)

        require_nonempty_string(
            claim.get("sourceCoordinate"),
            f"claims[{index}].sourceCoordinate",
        )
        require_nonempty_string(
            claim.get("targetGuaranteeFamily"),
            f"claims[{index}].targetGuaranteeFamily",
        )
        status = require_nonempty_string(
            claim.get("mappingStatus"),
            f"claims[{index}].mappingStatus",
        )
        require(status in KNOWN_STATUSES, f"{claim_id}: unknown mapping status")

        authority_before = require_nonnegative_int(
            claim.get("authorityBefore"),
            f"{claim_id}.authorityBefore",
        )
        authority_after = require_nonnegative_int(
            claim.get("authorityAfter"),
            f"{claim_id}.authorityAfter",
        )
        require(
            authority_after <= authority_before,
            f"{claim_id}: mapping amplifies authority",
        )

        if status in ADMITTED_STATUSES:
            admitted_count += 1
        else:
            escalated_count += 1
            require_nonempty_string(
                claim.get("escalationReason"),
                f"{claim_id}.escalationReason",
            )

        if claim_id == "csa-final-ten-layer-detail":
            csa_final_mapping_seen = True
            require(status == "unknown", "CSA final layer detail must fail closed")
            require(authority_after == 0, "unknown CSA mapping must grant no authority")

    require(csa_final_mapping_seen, "CSA final layer fail-closed claim is missing")

    claim_count = len(claims)
    expected_metrics = bundle.get("expectedMetrics")
    require(
        isinstance(expected_metrics, dict),
        "bundle.expectedMetrics must be an object",
    )
    require(expected_metrics.get("claimCount") == claim_count, "wrong claimCount")
    require(
        expected_metrics.get("proofCoverageCount") == admitted_count,
        "wrong proofCoverageCount",
    )
    require(
        expected_metrics.get("unknownEscalationCount") == escalated_count,
        "wrong unknownEscalationCount",
    )

    receipt_metrics = receipt.get("metrics")
    require(isinstance(receipt_metrics, dict), "receipt.metrics must be an object")
    require(receipt_metrics.get("claimCount") == claim_count, "receipt claimCount mismatch")

    proof_coverage = receipt_metrics.get("proofCoverage")
    require(
        isinstance(proof_coverage, dict)
        and proof_coverage.get("count") == admitted_count,
        "receipt proof coverage mismatch",
    )
    escalation = receipt_metrics.get("unknownEscalation")
    require(
        isinstance(escalation, dict)
        and escalation.get("count") == escalated_count,
        "receipt escalation count mismatch",
    )

    return {
        "schemaId": REPLAY_SCHEMA_ID,
        "schemaVersion": REPLAY_SCHEMA_VERSION,
        "result": "passed",
        "receiptId": receipt_id,
        "bundleId": bundle_id,
        "bundleSha256": bundle_sha256,
        "owner": owner,
        "metrics": {
            "claimCount": claim_count,
            "proofCoverageCount": admitted_count,
            "unknownEscalationCount": escalated_count,
        },
        "assurance": {
            "digestIntegrity": "verified",
            "schemaAndSemanticReplay": "verified",
            "issuerAuthentication": "not-provided",
            "transparencyInclusion": "not-provided",
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Replay one digest-bound AI security mapping bundle",
    )
    parser.add_argument("--bundle", required=True, type=Path)
    parser.add_argument("--receipt", required=True, type=Path)
    return parser


def main() -> int:
    arguments = build_parser().parse_args()
    try:
        replay = replay_mapping_bundle(arguments.bundle, arguments.receipt)
    except ReplayValidationError as error:
        print(
            json.dumps(
                {
                    "schemaId": REPLAY_SCHEMA_ID,
                    "schemaVersion": REPLAY_SCHEMA_VERSION,
                    "result": "failed",
                    "error": str(error),
                },
                sort_keys=True,
            )
        )
        return 1

    print(json.dumps(replay, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
