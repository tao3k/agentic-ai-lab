# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the consumption study study."""

import argparse
from pathlib import Path
from ._execution import run
from ._recovery import legacy_repair


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--library", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--live", action="store_true")
    p.add_argument("--case-index", type=int)
    p.add_argument("--legacy-repair", action="store_true")
    a = p.parse_args()
    if a.legacy_repair:
        legacy_repair(a.library.resolve(), a.output.resolve())
    else:
        run(a.library.resolve(), a.output.resolve(), a.live, a.case_index)
