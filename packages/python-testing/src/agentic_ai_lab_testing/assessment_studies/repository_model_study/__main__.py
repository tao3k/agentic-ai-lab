# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run the declared repository model study command."""

import argparse
from pathlib import Path
from . import live, prepare

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("prepare", "live"))
    parser.add_argument("source", type=Path)
    parser.add_argument("output", nargs="?", type=Path)
    args = parser.parse_args()
    prepare(args.source) if args.mode == "prepare" else live(args.source, args.output)
