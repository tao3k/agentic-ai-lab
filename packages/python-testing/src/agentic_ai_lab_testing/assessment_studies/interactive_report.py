# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Reconcile immutable local experimental records into the English report."""

from agentic_ai_lab_testing.model_study.reporting import report_text


import json, hashlib, shutil


from pathlib import Path


from agentic_ai_lab_testing.assessment_studies.interactive_study import (
    obligation_acceptance,
    balanced_oracle,
    tagged_oracle,
)


from ._interactive_report_audit import (
    thinking,
    _collect_run,
    _audit_checked_branches,
    _audit_supported_omissions,
)


from ._interactive_report_rendering import (
    _render_interactive_report,
    _publish_interactive_appendices,
)


def main():
    root = Path.cwd()
    cache = root / ".cache/ascent/interactive"
    out = root / ".cache/ascent/research-reports/interactive-evidence-study"
    out.mkdir(parents=True, exist_ok=True)
    folders = sorted(
        p
        for p in cache.iterdir()
        if p.is_dir() and (p / "plan.json").exists() and (p / "records.json").exists()
    )
    results = []
    audit = {}
    allrecords = {}
    protocols = {}
    incorrect = []
    for p in folders:
        _collect_run(p, root, results, allrecords, protocols, audit, incorrect)
    (out / "results.json").write_text(json.dumps(results, indent=2))
    (out / "records.json").write_text(json.dumps(allrecords, indent=2))
    (out / "plans.json").write_text(json.dumps(protocols, indent=2))
    (out / "provider-audit.json").write_text(json.dumps(list(audit.values()), indent=2))
    th = _render_interactive_report(out, root, results, audit, folders, incorrect)
    _publish_interactive_appendices(out, protocols, folders, allrecords, cache)
    report_text(
        json.dumps(
            {
                "runs": len(results),
                "uniquePhysicalResponses": len(audit),
                "physicalThinking": th,
                "localChecks": sum(r["independentLocalChecks"] for r in results),
                "incorrectLocalChecks": sum(r["incorrectLocalChecks"] for r in results),
                "hostAborted": [r["run"] for r in results if not r["completedRun"]],
            }
        )
    )


if __name__ == "__main__":
    main()
