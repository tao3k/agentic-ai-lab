# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the complex movie study study."""

import argparse
from pathlib import Path
from ._execution import live
from ._qualification import qualify
from ._snapshot import prepare


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="mode", required=True)
    s = sub.add_parser("prepare")
    s.add_argument("directory", type=Path)
    s.add_argument("library", type=Path)
    s.add_argument(
        "--stratum",
        choices=("shared-actor", "country-qualified"),
        default="shared-actor",
    )
    s.add_argument("--compiler-context", choices=("facts", "intent"), default="facts")
    s = sub.add_parser("live")
    s.add_argument("directory", type=Path)
    s.add_argument("output", type=Path)
    s = sub.add_parser("qualify")
    s.add_argument("corpus", type=Path)
    s.add_argument("library", type=Path)
    s.add_argument("output", type=Path)
    args = p.parse_args()
    if args.mode == "prepare":
        prepare(
            args.directory.resolve(),
            args.library.resolve(),
            args.stratum,
            args.compiler_context,
        )
    elif args.mode == "live":
        live(args.directory.resolve(), args.output.resolve())
    else:
        qualify(args.corpus.resolve(), args.library.resolve(), args.output.resolve())
