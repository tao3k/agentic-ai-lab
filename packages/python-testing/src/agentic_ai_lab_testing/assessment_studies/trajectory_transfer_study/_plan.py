# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Plan for the trajectory transfer study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
from agentic_ai_lab_testing.assessment_studies._source_files import _study_module_file
import hashlib
from pathlib import Path


def _build_plan(cases, library):
    """Assemble the retained plan structure."""
    return {
        "schema": "ascent.trajectory-transfer-study.v1",
        "cases": cases,
        "model": "deepseek-flash",
        "effort": "high",
        "maxOutputTokens": 131072,
        "maxAttemptsPerStage": 3,
        "primary": "Cumulative actual thinking until BOTH predeclared query obligations are independently verified correct.",
        "intervention": "Second stage receives ONLY completed reach/back facts from stage one, never the second answer.",
        "histories": "Both conditions retain all actual reasoning/messages opaquely.",
        "sourceHashes": _source_hashes(
            {
                p: Path(p)
                for p in [
                    __file__,
                    str(_study_module_file("trajectory_study")),
                    "program/trajectory.ss",
                    "program/evidence-dag.ss",
                ]
            }
        ),
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
    }
