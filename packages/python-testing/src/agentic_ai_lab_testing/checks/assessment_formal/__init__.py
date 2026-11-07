# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Downstream formal qualification: original obligations, native capacity, exact exits."

from __future__ import annotations

# One package publishes the study API; internal modules own its work and effects.
from ._config import ROOT, SECONDS, GROUPS
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, replace
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import time
import uuid
from ..assessment_models import CONFIGURATIONS, FAULTS, MODEL_ORDER

from ._models import Configuration, Obligation, configuration
from ._obligations import obligations, validate_output
from ._capacity import capacity
from ._runner import Runner
from ._command import renderings_from_batch, main

__all__ = [
    "ROOT",
    "SECONDS",
    "GROUPS",
    "Configuration",
    "Obligation",
    "configuration",
    "obligations",
    "validate_output",
    "capacity",
    "Runner",
    "renderings_from_batch",
    "main",
]
