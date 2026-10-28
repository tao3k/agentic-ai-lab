# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the complex movie validation study."""

import argparse
from pathlib import Path
from ._recovery import recover
from ._review import compact, review_semantics
from ._validation import validate


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--recover", action="store_true")
    p.add_argument("--review-semantics", action="store_true")
    p.add_argument("--compact", action="store_true")
    for name in ("preview", "results", "library", "output"):
        p.add_argument(name, type=Path)
    a = p.parse_args()
    fn = (
        compact
        if a.compact
        else review_semantics
        if a.review_semantics
        else recover
        if a.recover
        else validate
    )
    fn(
        a.preview.resolve(),
        a.results.resolve(),
        a.library.resolve(),
        a.output.resolve(),
    )
