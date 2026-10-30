# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"First-round evidence tools, independent truths, and whole-task ledgers."

# One package publishes the study API; internal modules own its work and effects.
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import sys
import contextlib
import copy
import hashlib
import io
import json
import random
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import (
    EvidenceOperation,
    EvidenceInteraction,
    EvidenceConversation,
)
from agentic_ai_lab_runtime.reasoning import Trajectory
from agentic_ai_lab_runtime.reasoning import identity
from ..correction_study import balanced, tagged
from ..trajectory_study import atom, rule, relation, extract
from ..consumption_study import oracle as balanced_oracle
from ..model_study import provider
from ..movie_study import provider_key

from ._cases import tagged_oracle, corpus, gold, public, obligation_acceptance
from ._execution import run
from ._command import main

__all__ = [
    "tagged_oracle",
    "corpus",
    "gold",
    "public",
    "obligation_acceptance",
    "run",
    "main",
]
