# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Consumer-test byte IO and records; not a Library orchestration API."

# One package publishes the study API; internal modules own its work and effects.
from ._config import ROOT, RUNTIME, KERNEL, SOLVER_TOOLS, RUBRIC, LABEL_TOOL
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import subprocess
import sys
import tarfile
import time
from datetime import datetime, timezone
from agentic_ai_lab_testing.assessment_studies.model_study import provider
from agentic_ai_lab_testing.assessment_studies.movie_study import provider_key

from ._artifacts import canonical, sha, save, fields
from ._transport import EvidenceEngine
from ._workload import judge_init, same_check, request_for, independent_atom
from ._sources import binding, verify
from ._qualification import qualify
from ._snapshot import freeze
from ._phase import charge, reasoning, phase
from ._execution import calibrate, solve
from ._annotations import anchor, validate_episode, annotate
from ._report import point, report
from ._command import main

__all__ = [
    "ROOT",
    "RUNTIME",
    "KERNEL",
    "SOLVER_TOOLS",
    "RUBRIC",
    "LABEL_TOOL",
    "canonical",
    "sha",
    "save",
    "fields",
    "EvidenceEngine",
    "judge_init",
    "same_check",
    "request_for",
    "independent_atom",
    "binding",
    "verify",
    "qualify",
    "freeze",
    "charge",
    "reasoning",
    "phase",
    "calibrate",
    "solve",
    "anchor",
    "validate_episode",
    "annotate",
    "point",
    "report",
    "main",
]
