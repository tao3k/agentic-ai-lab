# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Bind adaptive recovery to unchanged primary scores, plan bytes and checker identity."

import hashlib
import json
from pathlib import Path


def censored_episodes(primary):
    if "pairs" not in primary:
        raise ValueError("primary study must finish before adaptive recovery")
    return [e for e in primary["episodes"] if not e["effort"]["verified"]]


def _prepare_recovery(plan_dir, primary_dir, output):
    """Own the prepare recovery phase without weakening its checks."""
    pp = plan_dir / "plan.json"
    rp = primary_dir / "result.json"
    plan = json.loads(pp.read_text())
    primary = json.loads(rp.read_text())
    failed = censored_episodes(primary)
    if hashlib.sha256(pp.read_bytes()).hexdigest() != primary["planSha256"]:
        raise ValueError("plan identity")
    library = plan_dir / plan["library"]
    if hashlib.sha256(library.read_bytes()).hexdigest() != plan["librarySha256"]:
        raise ValueError("engine identity")
    output.mkdir(parents=True, exist_ok=False)
    protocol = {
        "schema": "ascent.compound-inference-recovery-plan.v1",
        "adaptive": True,
        "primaryScoresChanged": False,
        "primarySha256": hashlib.sha256(rp.read_bytes()).hexdigest(),
        "originalPlanSha256": primary["planSha256"],
        "maxAdditionalTurnsPerEpisode": 2,
        "maxOutputTokens": 131072,
        "maxProviderCalls": len(failed) * 2,
        "episodes": [
            {"case": e["case"], "repetition": e["repetition"], "arm": e["arm"]}
            for e in failed
        ],
        "producerSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "policy": "Continue every censored episode with the same facts, schema, action set and binary verifier, increasing the output ceiling. No gold feedback, no replacing original outcomes, and every original failed token stays charged.",
    }
    (output / "plan.json").write_text(json.dumps(protocol, indent=2) + "\n")
    (output / "paid-claim.json").open("x").close()
    return plan, failed, protocol
