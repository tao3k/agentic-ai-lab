# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Plan for the consumption study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
import hashlib
from pathlib import Path


def _build_plan(cases, library):
    """Assemble the retained plan structure."""
    return {
        "schema": "ascent.evidence-consumption-study.v1",
        "cases": cases,
        "model": "deepseek-flash",
        "maxOutputTokens": 131072,
        "maxAttemptsPerGoal": 3,
        "primary": "Whole task until all THREE goals pass, including shared initial usage and every failure/repair.",
        "intervention": "Checked executable continuation versus correct intermediate facts with manual result enumeration; this is tool offloading, not a pure reasoning-content treatment.",
        "sourceHashes": _source_hashes(
            {
                p: Path(p)
                for p in [
                    __file__,
                    "program/evidence-dag.ss",
                    "program/trajectory.ss",
                    "rust/ascent/src/derivations.rs",
                    "rust/ascent-python/src/api/trajectory.rs",
                ]
            }
        ),
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
    }
