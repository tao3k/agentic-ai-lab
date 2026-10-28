# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the inference reuse study study."""

import argparse
from pathlib import Path
from ._execution import live
from ._snapshot import prepare


def main():
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=("prepare", "live"))
    p.add_argument("directory", type=Path)
    p.add_argument("library", type=Path)
    p.add_argument("output", type=Path, nargs="?")
    a = p.parse_args()
    if a.mode == "prepare":
        prepare(a.directory.resolve(), a.library.resolve())
    elif a.output is None:
        p.error("live requires output")
    else:
        live(a.directory.resolve(), a.library.resolve(), a.output.resolve())
