# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the correction study study."""

import argparse
from pathlib import Path
from ._cases import corpus, holdout_corpus
from ._execution import run


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--library", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--live", action="store_true")
    p.add_argument("--holdout", action="store_true")
    p.add_argument("--case-index", type=int)
    a = p.parse_args()
    cases = holdout_corpus() if a.holdout else corpus()
    if a.case_index is not None:
        cases = [cases[a.case_index]]
    run(a.library.resolve(), a.output.resolve(), a.live, cases)
