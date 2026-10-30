# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Independent three-arm study isolating retained component reuse from execution."

# One package publishes the study API; internal modules own its work and effects.
from ._config import (
    ARMS,
    SHARED_CANDIDATE,
    SHARED_QUESTION,
    SHARED_TOOL,
    SHARED_RUBRIC,
    SHARED_LABEL_TOOL,
    BRANCH_QUESTION,
    BRANCH_SUBMIT,
    BRANCH_READ,
    SEMANTIC_LINE_CATEGORIES,
    SEMANTIC_BLOCK_TAGS,
)
from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse, concurrent.futures, contextlib, copy, hashlib, json, multiprocessing, os, shutil, time
from pathlib import Path
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ResponseHistory
from agentic_ai_lab_runtime.reasoning import EvidenceChain, normalize_contract
from .. import evidence_chain_workload as workload
from .. import inference_reuse_study as s
from ..inference_effort import until_verified, paired_reduction
from ..model_study import provider, response_outcome
from ..movie_study import provider_key

from ._shared_check import shared_check, shared_committed_check
from ._protocol import loose_json, tools, grade_answer
from ._episode import _ENGINE, episode
from ._study import prepare, live
from ._shared_cases import (
    shared_tasks,
    shared_source,
    shared_truth,
    shared_atoms,
    shared_packet,
)
from ._shared_qualification import shared_qualify
from ._shared_snapshot import shared_freeze
from ._shared_execution import shared_action, shared_live
from ._shared_validation import shared_validate_label
from ._shared_labels import shared_label
from ._shared_report import shared_report
from ._branch_contracts import (
    branch_grade,
    branch_candidates,
    branch_observe,
    branch_payload,
    branch_partial_output,
    branch_submission_context,
)
from ._branch_cases import branch_tasks, branch_literal_episodes
from ._branch_qualification import (
    branch_qualify,
    branch_input_reservation,
    branch_entry_reservation,
    branch_qualification_request,
    branch_import_output_qualification,
    branch_output_qualify,
)
from ._branch_labels import branch_label
from ._branch_semantics import (
    branch_semantic_validate,
    branch_semantic_partition,
    branch_semantic_summary,
    branch_semantic_blocks,
    branch_semantic_block_admit,
)
from ._branch_semantic_labels import branch_semantic_label
from ._branch_snapshot import branch_freeze
from ._branch_execution import branch_live
from ._branch_report import branch_report

__all__ = [
    "ARMS",
    "SHARED_CANDIDATE",
    "SHARED_QUESTION",
    "SHARED_TOOL",
    "SHARED_RUBRIC",
    "SHARED_LABEL_TOOL",
    "BRANCH_QUESTION",
    "BRANCH_SUBMIT",
    "BRANCH_READ",
    "SEMANTIC_LINE_CATEGORIES",
    "SEMANTIC_BLOCK_TAGS",
    "loose_json",
    "tools",
    "grade_answer",
    "episode",
    "prepare",
    "live",
    "shared_tasks",
    "shared_source",
    "shared_truth",
    "shared_atoms",
    "shared_packet",
    "shared_qualify",
    "shared_freeze",
    "shared_check",
    "shared_committed_check",
    "shared_action",
    "shared_live",
    "shared_validate_label",
    "shared_label",
    "shared_report",
    "branch_grade",
    "branch_candidates",
    "branch_observe",
    "branch_payload",
    "branch_partial_output",
    "branch_submission_context",
    "branch_tasks",
    "branch_literal_episodes",
    "branch_qualify",
    "branch_input_reservation",
    "branch_entry_reservation",
    "branch_qualification_request",
    "branch_import_output_qualification",
    "branch_output_qualify",
    "branch_label",
    "branch_semantic_validate",
    "branch_semantic_partition",
    "branch_semantic_summary",
    "branch_semantic_blocks",
    "branch_semantic_block_admit",
    "branch_semantic_label",
    "branch_freeze",
    "branch_live",
    "branch_report",
]
