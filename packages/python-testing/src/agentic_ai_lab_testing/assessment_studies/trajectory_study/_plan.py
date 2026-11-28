# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Plan for the trajectory study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
import hashlib
from pathlib import Path


def _build_plan(cases, library):
    """Assemble the retained plan structure."""
    return {
        "schema": "ascent.trajectory-study.v1",
        "cases": cases,
        "arms": ["reflection-only", "native-evidence"],
        "maxAttempts": 3,
        "maxOutputTokens": 131072,
        "model": "deepseek-flash",
        "effort": "high",
        "primary": "Actual cumulative provider thinking through first independently verified correct answer, including failures and repairs.",
        "sampling": "Eight independent generated cases; arm order alternates; evidence appears only after an actual error.",
        "providerOutputSchemaEnforced": False,
        "sourceHashes": _source_hashes(
            {
                p: Path(p)
                for p in [
                    "program/evidence-dag.ss",
                    "program/trajectory.ss",
                    "rust/ascent-python/src/api/trajectory.rs",
                    __file__,
                ]
            }
        ),
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
    }
