# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Scheme evidence in the model's inference loop, measured until verified answer."

# One package publishes the study API; internal modules own its work and effects.
from agentic_ai_lab_testing.assessment_studies._source_files import (
    _source_label,
    _study_module_file,
)
from agentic_ai_lab_testing.assessment_studies._source_files import _source_hashes
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import hashlib
import json
import shutil
import time
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceStore
from .. import inference_reuse_study as study
from .. import complex_inference_workload as complex_workload
from ..inference_effort import until_verified, paired_reduction
from ..query_contract import output_format
from ..model_study import provider, response_outcome
from ..movie_study import provider_key, MAX_OUTPUT_TOKENS

from ._contracts import action_format, evidence_program
from ._plan import _build_plan, prepare
from ._execution import live
from ._command import main

__all__ = ["action_format", "evidence_program", "prepare", "live", "main"]
