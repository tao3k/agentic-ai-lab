# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Paid bounded pilot: Python owns byte IO/cost; frozen Scheme owns semantics."

# One package publishes the study API; internal modules own its work and effects.
from ._config import ROOT, BASE, SNAP, TOOLS, INSTRUCTIONS
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse, hashlib, json, os, selectors, subprocess, time, shutil
from datetime import datetime, timezone
from pathlib import Path
from ..model_study import provider, response_outcome
from ..movie_study import provider_key
from agentic_ai_lab_runtime.reasoning import ResponseHistory
import random, copy

from ._tasks import CASES, CALIBRATION, input_reserve, task, packet, question
from ._artifacts import sha, save, canonical
from ._transport import SchemeEngine
from ._snapshot import qualify, freeze, verify
from ._phase import charge_usage, run_phase
from ._execution import run

__all__ = [
    "ROOT",
    "BASE",
    "SNAP",
    "CASES",
    "CALIBRATION",
    "TOOLS",
    "INSTRUCTIONS",
    "sha",
    "save",
    "canonical",
    "SchemeEngine",
    "input_reserve",
    "task",
    "packet",
    "question",
    "qualify",
    "freeze",
    "verify",
    "charge_usage",
    "run_phase",
    "run",
]
