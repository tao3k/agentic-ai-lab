# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Paid bounded pilot: Python owns byte IO/cost; frozen Scheme owns semantics."

# One package publishes the study API; internal modules own its work and effects.
from ._config import ROOT, BASE, SNAP, CASES, TOOLS, INSTRUCTIONS
from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
from agentic_ai_lab_testing.assessment_studies._source_files import _study_module_file
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse, hashlib, json, os, selectors, subprocess, time, shutil
from datetime import datetime, timezone
from pathlib import Path
from ..model_study import provider, response_outcome
from ..movie_study import provider_key
from agentic_ai_lab_runtime.reasoning import ResponseHistory

from ._artifacts import sha, save
from ._transport import SchemeEngine
from ._snapshot import _build_plan, freeze
from ._qualification import _qualify_factor_cases, qualification
from ._prompt import question
from ._execution import run

__all__ = [
    "ROOT",
    "BASE",
    "SNAP",
    "CASES",
    "TOOLS",
    "INSTRUCTIONS",
    "sha",
    "save",
    "SchemeEngine",
    "freeze",
    "qualification",
    "question",
    "run",
]
