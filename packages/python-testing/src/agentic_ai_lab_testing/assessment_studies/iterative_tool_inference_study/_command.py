# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the iterative tool inference study study."""

import argparse
from pathlib import Path
from ._execution import live
from ._plan import prepare


def main():
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=("prepare", "live"))
    p.add_argument("directory", type=Path)
    p.add_argument("target", type=Path)
    a = p.parse_args()
    if a.mode == "prepare":
        prepare(a.directory.resolve(), a.target.resolve())
    else:
        live(a.directory.resolve(), a.target.resolve())
