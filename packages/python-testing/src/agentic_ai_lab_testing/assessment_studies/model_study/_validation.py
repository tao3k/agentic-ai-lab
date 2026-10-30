# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Validation for the model study study."""

import json
import subprocess
from ._config import MAX_INPUT_BYTES, MAX_OUTPUT_TOKENS, PROVIDER_IDLE_SECONDS, ROOT
from ._sources import digest, module_path, producer_hashes


def validate(preview, approved):
    encoded = (preview / "plan.json").read_bytes()
    if digest(encoded) != approved:
        raise ValueError("approval digest does not match frozen plan")
    plan = json.loads(encoded)
    if (
        plan["maxCalls"] != 60
        or plan["retries"] != 0
        or plan["budgetCeilingUsd"] != 13
        or plan["maxInputBytes"] != MAX_INPUT_BYTES
        or plan["maxOutputTokens"] != MAX_OUTPUT_TOKENS
        or plan["producerHashes"] != producer_hashes()
        or plan["requestReadTimeoutSeconds"] != PROVIDER_IDLE_SECONDS
        or plan["requestWallDeadlineSeconds"] is not None
    ):
        raise ValueError("frozen producer/budget contract changed")
    subprocess.run(
        ["gxi", str(ROOT / "t/harness/artifact-admission.ss"), "check"],
        cwd=ROOT,
        check=True,
    )
    if plan["sourceBinding"] != json.loads(
        (ROOT / ".cache/ascent/compiled-library/dsl-closure.json").read_text()
    ):
        raise ValueError("native artifact changed after preparation")
    for name, sha in plan["modules"].items():
        if digest(module_path(name).read_bytes()) != sha:
            raise ValueError("module bytes changed after preparation")
    for case in plan["cases"]:
        for path, sha in [
            (preview / f"{case['id']}.input.ss", case["inputSha256"]),
            (preview / f"{case['id']}.task.ss", case["taskSha256"]),
            (preview / "private" / f"{case['id']}.sexp", case["expectedSha256"]),
        ]:
            if digest(path.read_bytes()) != sha:
                raise ValueError("frozen case bytes changed")
    if len(plan["order"]) != 60 or len(plan["cases"]) != 24:
        raise ValueError("frozen inventory changed")
    return plan
