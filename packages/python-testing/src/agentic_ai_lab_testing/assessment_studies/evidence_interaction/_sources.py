# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Sources for the evidence interaction study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_label

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes

from agentic_ai_lab_testing.assessment_studies._source_files import _study_module_file

import json
from pathlib import Path
from ._artifacts import sha
from ._config import KERNEL, ROOT, RUNTIME


def binding():
    paths = [
        _study_module_file("evidence_interaction"),
        ROOT / "t/research/evidence-search.ss",
        _study_module_file("model_study"),
        _study_module_file("movie_study"),
        ROOT / "candidate/evidence-store.ss",
        KERNEL / ".gerbil/bin/crosspath-search",
        RUNTIME / "bin/evidence-search",
    ]
    for folder in [
        RUNTIME / "lib",
        ROOT / ".cache/ascent/evidence-store/lib",
        KERNEL / ".gerbil/lib",
    ]:
        paths += [
            p for p in folder.rglob("*") if p.is_file() and not p.name.endswith(".lock")
        ]
    paths += list((ROOT / "candidate").glob("*.ss"))
    paths += list((ROOT / "program").glob("*.ss"))
    paths += [
        Path(p) for p in json.loads((RUNTIME / "poo-source-order.json").read_text())
    ]
    return _source_hashes(
        {
            str(_source_label(p, ROOT)) if p.is_relative_to(ROOT) else str(p): p
            for p in sorted(set(paths))
        }
    )


def verify(run, plan):
    if (
        sha((run / "plan.json").read_bytes())
        != (run / "plan.sha256").read_text().strip()
    ):
        raise ValueError("plan drift")
    if sha((run / "qualification.json").read_bytes()) != plan["qualificationSha256"]:
        raise ValueError("qualification drift")
    for name, digest in plan["binding"].items():
        if sha((ROOT / name).read_bytes()) != digest:
            raise ValueError("producer drift: " + name)
