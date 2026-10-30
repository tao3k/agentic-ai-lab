# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run the declared candidate model command."""

import argparse
from pathlib import Path
from . import (
    AtomicJudge,
    CANONICAL,
    Consumer,
    EpisodeConsumer,
    PREPARED,
    ROOT,
    RUNTIME,
    TASKS,
    TOOL,
    branch_action,
    branch_request,
    call_model,
    digest,
    environment,
    freeze,
    judge_selection,
    optimum,
    reachable,
    ready,
    request,
    reuse_annotate,
    reuse_freeze,
    reuse_report,
    reuse_solve,
    reuse_verify,
    save,
    search_task,
    shutil_copy,
    solve,
    study_annotations,
    task,
    verify,
)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=[
            "freeze",
            "solve",
            "reuse-freeze",
            "reuse-solve",
            "reuse-annotate",
            "reuse-report",
        ],
    )
    parser.add_argument("--run-dir", type=Path, required=True)
    a = parser.parse_args()
    globals()[a.command.replace("-", "_")](a.run_dir.resolve())
