# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Snapshot for the model study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import subprocess
from ._config import (
    BUDGET_USD,
    FRAME_TOKEN_PADDING,
    MAX_CALLS,
    MAX_INPUT_BYTES,
    MAX_OUTPUT_TOKENS,
    PRICE_URL,
    PROVIDER_IDLE_SECONDS,
    ROOT,
)
from ._native import native_score, probe
from ._sources import digest, module_path, producer_hashes


def prepare(output):
    cases, closures = probe(output)
    modules = {}
    families = list(dict.fromkeys(case["family"] for case in cases))
    if len(families) != 12:
        raise ValueError("expected twelve independent families")
    manifest = {
        "schema": "ascent.model-closure-study-plan",
        "version": 1,
        "model": "deepseek-flash",
        "baseUrl": "https://api.deepseek.com",
        "sourceHead": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "maxCalls": MAX_CALLS,
        "retries": 0,
        "maxInputBytes": MAX_INPUT_BYTES,
        "maxOutputTokens": MAX_OUTPUT_TOKENS,
        "budgetCeilingUsd": BUDGET_USD,
        "requestReadTimeoutSeconds": PROVIDER_IDLE_SECONDS,
        "requestWallDeadlineSeconds": None,
        "providerProgressContract": "Actual response/reasoning/text events renew the idle deadline; keepalive lines do not; no absolute cutoff while computation progresses",
        "priceSource": PRICE_URL,
        "peakInputUsdPerMillion": 0.3,
        "peakOutputUsdPerMillion": 1.2,
        "framingTokenPadding": FRAME_TOKEN_PADDING,
        "conservativeMaximumUsd": MAX_CALLS
        * ((MAX_INPUT_BYTES + FRAME_TOKEN_PADDING) * 0.3 + MAX_OUTPUT_TOKENS * 1.2)
        / 1_000_000,
        "inputContract": "actual compiler-derived module sources and exact compiled Scheme expression with missing expected datum; no system instructions, examples, semantic recipe, answer prefill, tools or repair",
        "feedbackContract": "only actual initial output and post-response current native score/truth; no corrective instruction",
        "outputContract": "raw retained; unique inert literal/quoted assertion normalization without oracle; ambiguity, EOF and executable leaves reject",
        "primaryMetric": "completed provider response and correct native-scored normalized datum; all scheduled attempts remain in denominator",
        "sourceBinding": json.loads(
            (ROOT / ".cache/ascent/compiled-library/dsl-closure.json").read_text()
        ),
        "producerHashes": producer_hashes(),
        "modules": modules,
        "cases": [],
        "order": [],
        "families": families,
    }
    private = output / "private"
    private.mkdir()
    for case in cases:
        deps = sorted({module for root in case["imports"] for module in closures[root]})
        owned = [name for name in deps if name.startswith("gerbil-ascent/")]
        lowered = (
            ["yuanxu/types.ssi", "yuanxu/types.scm", "yuanxu/types~0.scm"]
            if "yuanxu/types" in deps
            else []
        )
        assumed = [
            name for name in deps if name not in owned and name != "yuanxu/types"
        ]
        if not owned:
            raise ValueError("compiler source closure has no project modules")
        context = ""
        for name in owned + lowered:
            path = module_path(name)
            if not path.is_file():
                raise ValueError(f"project module has no source: {name}")
            data = path.read_bytes()
            modules[name] = digest(data)
            context += (
                f";;; file: {name + '.ss' if name in owned else name}\n"
                + data.decode()
                + "\n"
            )
        task = "(import :std/test " + " ".join(case["imports"]) + ")\n"
        task += "(define result " + case["expression"] + ")\n(check-equal? result '?)\n"
        payload = context + task
        encoded = payload.encode()
        # Historical transfer adds only the new task, not a duplicated implementation.
        # Actual request serialization and prior output must still pass the frozen byte bound.
        if len(encoded) > MAX_INPUT_BYTES - 65536:
            raise ValueError(
                f"source/task leaves insufficient bounded history space: {case['id']}"
            )
        (output / f"{case['id']}.input.ss").write_bytes(encoded)
        (output / f"{case['id']}.task.ss").write_text(task)
        expected = (case["nativeDatum"] + "\n").encode()
        if case["nativeDatum"] != case["independentDatum"]:
            raise ValueError("native truth did not match independent frozen fixture")
        (private / f"{case['id']}.sexp").write_bytes(expected)
        manifest["cases"].append(
            {
                "id": case["id"],
                "family": case["family"],
                "variant": case["variant"],
                "imports": case["imports"],
                "dependencyModules": owned,
                "compilerLoweredDependencyFiles": lowered,
                "assumedFrameworkModules": assumed,
                "inputBytes": len(encoded),
                "inputSha256": digest(encoded),
                "taskSha256": digest(task.encode()),
                "expectedSha256": digest(expected),
            }
        )
    controls = [
        ("literal", "2", True, True),
        ("quote", "'2", True, True),
        ("assertion", "(check-equal? result 2)", True, True),
        ("quoted-assertion", "(check-equal? result '2)", True, True),
        ("wrong", "3", True, False),
        ("executable", "(check-equal? result (+ 1 1))", False, False),
        ("ambiguous", "2 2", False, False),
        ("reader-label", "#0=(2 . #0#)", False, False),
        ("deep", "(" * 65 + "2" + ")" * 65, False, False),
        ("oversize", "2" * 8193, False, False),
    ]
    observations = []
    for label, datum, readable, correct in controls:
        observed = native_score(
            "higher-input-initial", datum, output / f"control-{label}"
        )
        if observed["readable"] != readable or observed["correct"] != correct:
            raise ValueError(f"native transport control failed: {label}")
        observations.append({"control": label, **observed})
    (output / "transport-controls.json").write_text(
        json.dumps(observations, indent=2) + "\n"
    )
    manifest["nativeTransportControls"] = len(observations)
    for index, family in enumerate(families):
        initial = [
            ("initial-none", "none", "initial"),
            ("initial-high", "high", "initial"),
        ]
        transfer = [
            ("transfer-fresh", "high", "transfer"),
            ("transfer-history", "high", "transfer"),
            ("transfer-feedback", "high", "transfer"),
        ]
        rotation = index % 3
        transfer = transfer[rotation:] + transfer[:rotation]
        if index % 2:
            initial.reverse()
            transfer.reverse()
        for arm, effort, variant in initial + transfer:
            manifest["order"].append(
                {
                    "family": family,
                    "arm": arm,
                    "reasoningEffort": effort,
                    "case": f"{family}-{variant}",
                }
            )
    encoded = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()
    (output / "plan.json").write_bytes(encoded)
    report_text(
        f"PREPARED {digest(encoded)} native=24 modelCalls=0 modules={len(modules)}",
        flush=True,
    )
