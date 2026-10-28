# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the interactive study study."""

import argparse
from pathlib import Path
from ._execution import run


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--library", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--live", action="store_true")
    p.add_argument("--case-index", type=int, default=0)
    p.add_argument(
        "--arm", choices=["source-only", "fresh", "retained"], default="retained"
    )
    p.add_argument("--resume-prefix", type=Path)
    p.add_argument("--failed-prefix", type=Path)
    p.add_argument("--checkpoint-prefix", type=Path)
    p.add_argument("--seed-offset", type=int, default=0)
    a = p.parse_args()
    run(
        a.library,
        a.output,
        live=a.live,
        index=a.case_index,
        arm=a.arm,
        resume_prefix=a.resume_prefix,
        failed_prefix=a.failed_prefix,
        checkpoint_prefix=a.checkpoint_prefix,
        seed_offset=a.seed_offset,
    )
