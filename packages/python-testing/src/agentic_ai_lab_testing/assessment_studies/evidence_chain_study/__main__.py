# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run the declared evidence chain study command."""

import argparse
from pathlib import Path
from . import (
    ARMS,
    BRANCH_QUESTION,
    BRANCH_READ,
    BRANCH_SUBMIT,
    SEMANTIC_BLOCK_TAGS,
    SEMANTIC_LINE_CATEGORIES,
    SHARED_CANDIDATE,
    SHARED_LABEL_TOOL,
    SHARED_QUESTION,
    SHARED_RUBRIC,
    SHARED_TOOL,
    _ENGINE,
    branch_candidates,
    branch_entry_reservation,
    branch_freeze,
    branch_grade,
    branch_import_output_qualification,
    branch_input_reservation,
    branch_label,
    branch_literal_episodes,
    branch_live,
    branch_observe,
    branch_output_qualify,
    branch_partial_output,
    branch_payload,
    branch_qualification_request,
    branch_qualify,
    branch_report,
    branch_semantic_block_admit,
    branch_semantic_blocks,
    branch_semantic_label,
    branch_semantic_partition,
    branch_semantic_summary,
    branch_semantic_validate,
    branch_submission_context,
    branch_tasks,
    episode,
    grade_answer,
    live,
    loose_json,
    prepare,
    shared_action,
    shared_atoms,
    shared_check,
    shared_committed_check,
    shared_freeze,
    shared_label,
    shared_live,
    shared_packet,
    shared_qualify,
    shared_report,
    shared_source,
    shared_tasks,
    shared_truth,
    shared_validate_label,
    tools,
)

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument(
        "mode",
        choices=[
            "prepare",
            "live",
            "shared-freeze",
            "shared-live",
            "shared-check",
            "shared-committed-check",
            "shared-label",
            "shared-report",
            "branch-freeze",
            "branch-output-qualify",
            "branch-import-output-qualification",
            "branch-live",
            "branch-semantic-label",
            "branch-report",
        ],
    )
    p.add_argument("source", type=Path)
    p.add_argument("output", type=Path)
    a = p.parse_args()
    if a.mode.startswith(("shared-", "branch-")):
        globals()[a.mode.replace("-", "_")](a.source, a.output)
    else:
        prepare(a.source, a.output) if a.mode == "prepare" else live(a.source, a.output)
