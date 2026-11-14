# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Plan for the correction study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
import hashlib
from pathlib import Path


def _build_plan(cases, library):
    """Assemble the retained plan structure."""
    return {
        "schema": "ascent.correction-study.v1",
        "cases": cases,
        "model": "deepseek-flash",
        "effort": "high",
        "maxOutputTokens": 131072,
        "maxAttemptsPerStage": 3,
        "primary": "Cumulative actual thinking until both query obligations independently pass, including all failed and repair calls.",
        "sharedPrefix": "One actual initial call is retained in both paired task trajectories and charged to BOTH policies; experimental expenditure counts it once.",
        "intervention": "Completed intermediate relations only, after a real failed initial answer or before the second query. No final answer in packets.",
        "sourceHashes": _source_hashes(
            {
                p: Path(p)
                for p in [
                    __file__,
                    "program/trajectory.ss",
                    "rust/ascent/src/derivations.rs",
                    "rust/ascent-python/src/api/trajectory.rs",
                ]
            }
        ),
        "librarySha256": hashlib.sha256(library.read_bytes()).hexdigest(),
        "outputSchemaEnforced": False,
    }
