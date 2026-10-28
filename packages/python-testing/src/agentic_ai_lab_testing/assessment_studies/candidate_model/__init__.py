# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Small candidate-feedback consumer; uses existing Library and provider IO."

# One package publishes the study API; internal modules own its work and effects.
from ._config import ROOT, RUNTIME, PREPARED, CANONICAL, TASKS, TOOL
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import inspect
import ast
import hashlib
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import time
import tarfile
from agentic_ai_lab_testing.assessment_studies.model_study import provider
from agentic_ai_lab_testing.assessment_studies.movie_study import provider_key

from ._artifacts import save, digest, shutil_copy
from ._transport import environment, Consumer, AtomicJudge, EpisodeConsumer
from ._tasks import task, request, study_annotations, branch_request, branch_action
from ._judge import reachable, ready, search_task, judge_selection, optimum
from ._snapshot import freeze, verify
from ._reuse_snapshot import reuse_freeze, reuse_verify
from ._execution import call_model, solve
from ._reuse_execution import reuse_solve
from ._annotations import reuse_annotate
from ._reporting import reuse_report

__all__ = [
    "ROOT",
    "RUNTIME",
    "PREPARED",
    "CANONICAL",
    "TASKS",
    "TOOL",
    "save",
    "digest",
    "shutil_copy",
    "environment",
    "Consumer",
    "AtomicJudge",
    "EpisodeConsumer",
    "task",
    "request",
    "study_annotations",
    "reachable",
    "ready",
    "search_task",
    "judge_selection",
    "optimum",
    "branch_request",
    "branch_action",
    "freeze",
    "verify",
    "reuse_freeze",
    "reuse_verify",
    "call_model",
    "solve",
    "reuse_solve",
    "reuse_annotate",
    "reuse_report",
]
