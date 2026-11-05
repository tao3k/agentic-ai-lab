# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Frozen provider byte IO; Scheme owns task construction, truth and scoring."

# One package publishes the study API; internal modules own its work and effects.
from ._config import (
    ROOT,
    BINARY,
    HARNESS,
    RUNTIME,
    PRICE_URL,
    MAX_INPUT_BYTES,
    MAX_OUTPUT_TOKENS,
    MAX_CALLS,
    BUDGET_USD,
    FRAME_TOKEN_PADDING,
    PROVIDER_IDLE_SECONDS,
)
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import http.client
import statistics
import shutil

from ._sources import (
    digest,
    producer_hashes,
    module_path,
    source_environment,
    source_closure,
)
from ._native import native, probe, native_projection, native_score
from ._provider import response_outcome, provider, request_for
from ._snapshot import prepare
from ._validation import validate
from ._report import summary
from ._execution import live
from ._command import main

__all__ = [
    "ROOT",
    "BINARY",
    "HARNESS",
    "RUNTIME",
    "PRICE_URL",
    "MAX_INPUT_BYTES",
    "MAX_OUTPUT_TOKENS",
    "MAX_CALLS",
    "BUDGET_USD",
    "FRAME_TOKEN_PADDING",
    "PROVIDER_IDLE_SECONDS",
    "digest",
    "producer_hashes",
    "module_path",
    "source_environment",
    "source_closure",
    "native",
    "probe",
    "native_projection",
    "native_score",
    "response_outcome",
    "provider",
    "request_for",
    "prepare",
    "validate",
    "summary",
    "live",
    "main",
]
