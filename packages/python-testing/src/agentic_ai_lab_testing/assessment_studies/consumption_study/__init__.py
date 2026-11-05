# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Text consumption versus checked execution on shared initial real responses."

# One package publishes the study API; internal modules own its work and effects.
from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse, contextlib, copy, hashlib, io, json, random, time
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime, ReasoningError
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from ..correction_study import balanced
from ..trajectory_study import atom, rule
from ..model_study import provider
from ..movie_study import provider_key

from ._workload import oracle, corpus
from ._projection import parse, proposed
from ._plan import _build_plan
from ._execution import run
from ._recovery import legacy_repair
from ._command import main

__all__ = ["oracle", "corpus", "parse", "proposed", "run", "legacy_repair", "main"]
