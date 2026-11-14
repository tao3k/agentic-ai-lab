# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Post-pilot structural repair and source-transfer diagnostics, without paid replay."

# One package publishes the study API; internal modules own its work and effects.
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import copy
import hashlib
import json
import time
from pathlib import Path
from ascent import Engine
from .. import complex_movie_study as study
from ..query_contract import output_format, compact_request
from ..model_study import provider, response_outcome
from ..movie_study import provider_key, MAX_OUTPUT_TOKENS
from agentic_ai_lab_runtime.reasoning import rows_equal

from ._repair import singleton_heads, witnesses
from ._validation import validate
from ._recovery import recover
from ._review import review_semantics, compact
from ._command import main

__all__ = [
    "singleton_heads",
    "witnesses",
    "validate",
    "recover",
    "review_semantics",
    "compact",
    "main",
]
