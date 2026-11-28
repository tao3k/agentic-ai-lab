# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Shared-prefix, whole-task correction controls on fresh recursive programs."

# One package publishes the study API; internal modules own its work and effects.
from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse, contextlib, copy, hashlib, io, json, random
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from agentic_ai_lab_runtime.reasoning import EvidenceChain, evidence_graph
from agentic_ai_lab_runtime.reasoning import identity
from agentic_ai_lab_runtime.reasoning import Trajectory
from ..trajectory_study import relation, atom, rule, extract
from ..model_study import provider
from ..movie_study import provider_key

from ._tagged import tagged
from ._balanced import _build_rules, balanced
from ._cases import corpus, holdout_corpus
from ._plan import _build_plan
from ._execution import run
from ._command import main
from ._case_record import make_case

__all__ = ["tagged", "balanced", "corpus", "holdout_corpus", "run", "main", "make_case"]
