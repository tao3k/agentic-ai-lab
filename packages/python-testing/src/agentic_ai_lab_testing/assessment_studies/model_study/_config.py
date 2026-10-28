# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the model study study."""

import os
from pathlib import Path
import sys

ROOT = Path(os.environ.get("ASCENT_REPOSITORY", Path.cwd())).resolve()

BINARY = ROOT / ".cache/ascent/compiled-library/dsl-closure"

HARNESS = [
    sys.executable,
    "-m",
    "agentic_ai_lab_testing.assessment_studies.supervision",
    "--",
    "timeout",
    "120s",
]

RUNTIME = [str(BINARY), "-:max-heap=1G,debug=q"]

PRICE_URL = "https://api-docs.deepseek.com/quick_start/pricing/"

MAX_INPUT_BYTES = 655360

MAX_OUTPUT_TOKENS = 8192

MAX_CALLS = 60

BUDGET_USD = 13

FRAME_TOKEN_PADDING = 1024

PROVIDER_IDLE_SECONDS = 45
