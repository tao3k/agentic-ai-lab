# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Movie-study byte preparation and offline dispatch; Scheme owns all semantics.\n\nSmall mechanism pilot only; complex capability evaluation is a separate study.\nScheme owns gold construction and grading; Python records provider byte IO.\n"

# One package publishes the study API; internal modules own its work and effects.
from ._config import ROOT, SCHEME_ENTRY, PRODUCERS, MAX_INPUT_BYTES, MAX_OUTPUT_TOKENS
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import shlex
import re
import shutil
from agentic_ai_lab_runtime.reasoning import rows_equal

from ._sources import digest, identities
from ._provider import provider_fatal, provider_key
from ._native import scheme, ffi_grade
from ._request import request_for, continuation_plan
from ._snapshot import prepare, validate, offline
from ._execution import live
from ._continuation import continue_ffi
from ._reflection import reflect
from ._budget import budget_control
from ._command import main

__all__ = [
    "ROOT",
    "SCHEME_ENTRY",
    "PRODUCERS",
    "MAX_INPUT_BYTES",
    "MAX_OUTPUT_TOKENS",
    "digest",
    "identities",
    "provider_fatal",
    "provider_key",
    "scheme",
    "ffi_grade",
    "request_for",
    "continuation_plan",
    "prepare",
    "validate",
    "offline",
    "live",
    "continue_ffi",
    "reflect",
    "budget_control",
    "main",
]
