# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Fresh relational tasks, independent oracle, actual provider call trajectories.\n\nNo server-side output schema. Native evidence is supplied only after an actual\nfailed model attempt; known repeat answers require no additional model call.\n"

# One package publishes the study API; internal modules own its work and effects.
from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import contextlib
import hashlib
import io
import json
import random
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceChain, evidence_graph
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ..movie_study import provider_key
from ..model_study import provider

from ._workload import relation, atom, rule, closure, task
from ._projection import extract
from ._plan import _build_plan
from ._execution import run
from ._command import main

__all__ = ["relation", "atom", "rule", "closure", "task", "extract", "run", "main"]
