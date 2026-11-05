# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Frozen multi-hop movie experiment; Scheme owns every relational operation."

# One package publishes the study API; internal modules own its work and effects.
from ._config import ROOT, FIXTURE, TYPES
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import importlib.util
import copy
import hashlib
import json
from pathlib import Path
import shutil
import time
from ascent import Engine
from ..movie_study import provider_key, MAX_OUTPUT_TOKENS
from ..model_study import provider, response_outcome
from ..query_contract import output_format, compact_request
from agentic_ai_lab_runtime.reasoning import rows_equal

from ._contracts import (
    encoded,
    identity,
    var,
    const,
    atom,
    rule,
    declaration,
    program,
    view_contract,
)
from ._workload import execute, materialize, gold, source_for, case_program, cases
from ._request import request
from ._snapshot import prepare
from ._execution import live
from ._qualification import qualify
from ._command import main

__all__ = [
    "ROOT",
    "FIXTURE",
    "TYPES",
    "encoded",
    "identity",
    "var",
    "const",
    "atom",
    "rule",
    "declaration",
    "program",
    "view_contract",
    "execute",
    "materialize",
    "gold",
    "source_for",
    "case_program",
    "cases",
    "request",
    "prepare",
    "live",
    "qualify",
    "main",
]
