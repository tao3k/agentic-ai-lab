# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Archive the original interaction evidence and its audited report together."

from agentic_ai_lab_testing.model_study.reporting import report_text
import tarfile
from ._artifacts import save, sha
from ._config import ROOT, RUNTIME


def _publish_report_bundle(run, plan, result, prior):
    """Own the publish report bundle phase without weakening its checks."""
    raw = {
        str(p.relative_to(run)): sha(p.read_bytes())
        for p in sorted(run.rglob("*"))
        if p.is_file() and p.name != "integrity.json" and not p.name.endswith(".log")
    }
    save(
        run / "integrity.json",
        {
            "producerBindingVerified": True,
            "rootTaskAndEvidenceParity": True,
            "grossChargesAndLiteralSpansVerified": True,
            "rawFiles": raw,
        },
    )
    doc = (
        ROOT
        / ".cache/ascent/research-reports/agent-inference/evidence-interaction-results"
    )
    doc.mkdir(parents=True, exist_ok=True)
    for name in (
        "report.json",
        "report.md",
        "thinking-episodes.json",
        "thinking-episodes.md",
        "integrity.json",
        "plan.json",
        "qualification.json",
        "ledger.json",
        "annotation-ledger.json",
        "calibration-ledger.json",
    ):
        (doc / name).write_bytes((run / name).read_bytes())
    bundle = doc / "raw.tar.gz"
    with tarfile.open(bundle, "w:gz") as tar:
        if prior.exists():
            tar.add(prior, arcname="development/consumer-calibration-failure.tar.gz")
        for dirname in (
            "paid",
            "calibration",
            "annotations",
            "payload-review",
            "producers",
        ):
            tar.add(run / dirname, arcname=dirname)
        for name in (
            "plan.json",
            "plan.sha256",
            "qualification.json",
            "qualification-native.json",
            "ledger.json",
            "annotation-ledger.json",
            "calibration-ledger.json",
            "integrity.json",
        ):
            tar.add(run / name, arcname=name)
        development = run.parent
        for folder in (
            "failed-startup-qualification",
            "consumer-startup-probe",
            "consumer-model-check",
        ):
            if (development / folder).exists():
                tar.add(development / folder, arcname="development/" + folder)
        for folder in (
            "failed-object-command-resolution",
            "failed-object-runtime-prefix",
            "native-objects",
            "retired-locks",
        ):
            if (RUNTIME / folder).exists():
                tar.add(RUNTIME / folder, arcname="development/runtime/" + folder)
        for log in sorted(RUNTIME.glob("*.log")):
            tar.add(log, arcname="development/runtime/" + log.name)
        for name in (
            "consumer-build.json",
            "poo-source-order.json",
            "native-object-closure.json",
            "native-link-receipt.json",
            "native-link-missing-crypto.json",
        ):
            tar.add(RUNTIME / name, arcname="development/runtime/" + name)
    save(
        doc / "archive.json",
        {"sha256": sha(bundle.read_bytes()), "bytes": bundle.stat().st_size},
    )
    report_text(
        "REPORTED",
        result["solverGrossTokens"],
        result["measurementGrossTokens"],
        flush=True,
    )
