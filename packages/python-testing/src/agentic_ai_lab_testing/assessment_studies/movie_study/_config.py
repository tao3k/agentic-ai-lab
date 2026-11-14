# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the movie study study."""

from agentic_ai_lab_testing.assessment_studies._source_files import _study_module_file

import os
from pathlib import Path

ROOT = Path(os.environ.get("ASCENT_REPOSITORY", Path.cwd())).resolve()

SCHEME_ENTRY = "t/qualification/ascent-movie-cast-test.ss"

PRODUCERS = [
    SCHEME_ENTRY,
    "applications/movie-cast-query.ss",
    "t/qualification/fixtures/movie-cast/source.json",
    str(_study_module_file("movie_study")),
    str(_study_module_file("model_study")),
]

MAX_INPUT_BYTES = 32768

MAX_OUTPUT_TOKENS = int(os.environ.get("ASCENT_MODEL_MAX_OUTPUT_TOKENS", "65536"))

if MAX_OUTPUT_TOKENS <= 0:
    raise ValueError("ASCENT_MODEL_MAX_OUTPUT_TOKENS must be positive")
