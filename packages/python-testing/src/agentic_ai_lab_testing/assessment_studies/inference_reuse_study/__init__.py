# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Frozen intent compilation versus retained Scheme execution; no gold in prompts."

# One package publishes the study API; internal modules own its work and effects.
from ._config import SCHEMA, STRUCTURES
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import copy
import hashlib
import json
import shutil
import time
from pathlib import Path
from ascent import Engine
from ..complex_movie_study import atom, rule, var, declaration, identity, ROOT
from ..query_contract import output_format
from ..movie_study import provider_key, MAX_OUTPUT_TOKENS
from ..model_study import provider, response_outcome

from ._workload import workload, updated, expected, oracle_contract, program
from ._request import request, price, completed_contract
from ._snapshot import prepare
from ._execution import live
from ._command import main

__all__ = [
    "SCHEMA",
    "STRUCTURES",
    "workload",
    "updated",
    "expected",
    "oracle_contract",
    "program",
    "request",
    "price",
    "completed_contract",
    "prepare",
    "live",
    "main",
]
