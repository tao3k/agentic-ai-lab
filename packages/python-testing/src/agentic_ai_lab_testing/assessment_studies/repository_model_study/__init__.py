# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Real repository repair pilot with source-bound Scheme evidence and matched arms."

# One package publishes the study API; internal modules own its work and effects.
from ._config import ROOT, CORPUS, ARMS, ENGINE, CASES
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse
import ast
import concurrent.futures
import contextlib
import copy
import hashlib
import json
import multiprocessing
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from agentic_ai_lab_runtime.reasoning import EvidenceChain
from agentic_ai_lab_runtime.reasoning import DomainEvidence
from agentic_ai_lab_runtime.reasoning import identity
from ..evidence_chain_study import loose_json
from ..inference_effort import until_verified, paired_reduction
from ..inference_reuse_study import price
from ..model_study import provider, response_outcome
from ..movie_study import provider_key
from ..repository_corpus import tree_identity, test_receipt, qualify, provenance

from ._corpus import (
    copy_snapshot,
    prepare,
    symbol_table,
    evidence_program,
    grading_scope,
)
from ._runner import observed_runner
from ._workspace import Workspace
from ._tools import tool_definitions
from ._episode import episode
from ._execution import live

__all__ = [
    "ROOT",
    "CORPUS",
    "ARMS",
    "ENGINE",
    "CASES",
    "copy_snapshot",
    "prepare",
    "symbol_table",
    "evidence_program",
    "grading_scope",
    "observed_runner",
    "Workspace",
    "tool_definitions",
    "episode",
    "live",
]
