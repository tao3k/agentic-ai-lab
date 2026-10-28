# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Matched tool-mediated thinking with complete stateless Responses history."

# One package publishes the study API; internal modules own its work and effects.
from ._episode import _ENGINE
from agentic_ai_lab_testing.assessment_studies._source_files import (
    _source_label,
    _study_module_file,
)
from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import concurrent.futures
import contextlib
import copy
import hashlib
import json
import multiprocessing
import shutil
import time
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceStore
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from .. import iterative_inference_study as loop
from .. import inference_reuse_study as study
from .. import complex_inference_workload as workload
from ..inference_effort import until_verified, paired_reduction
from ..movie_study import provider_key
from ..model_study import provider, response_outcome

from ._tools import tool_definitions
from ._plan import prepare
from ._episode import run_episode
from ._execution import live
from ._command import main

__all__ = ["tool_definitions", "prepare", "run_episode", "live", "main"]
