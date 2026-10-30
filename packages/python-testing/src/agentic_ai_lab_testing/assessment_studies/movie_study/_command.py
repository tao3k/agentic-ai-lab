# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the movie study study."""

import argparse
from pathlib import Path
from ._budget import budget_control
from ._continuation import continue_ffi
from ._execution import live
from ._reflection import reflect
from ._snapshot import offline, prepare


def main():
    parser = argparse.ArgumentParser()
    modes = parser.add_subparsers(dest="mode", required=True)
    p = modes.add_parser("prepare")
    p.add_argument("output", type=Path)
    p = modes.add_parser("offline")
    p.add_argument("preview", type=Path)
    p.add_argument("output", type=Path)
    p = modes.add_parser("live")
    p.add_argument("preview", type=Path)
    p.add_argument("output", type=Path)
    p = modes.add_parser("continue-ffi")
    for field in ("preview", "output", "frozen_root", "library", "wire"):
        p.add_argument(field, type=Path)
    p = modes.add_parser("reflect")
    for field in ("preview", "pilot", "output", "wire", "library"):
        p.add_argument(field, type=Path)
    p = modes.add_parser("budget-control")
    for field in ("preview", "pilot", "output", "wire", "library"):
        p.add_argument(field, type=Path)
    args = parser.parse_args()
    if args.mode == "prepare":
        prepare(args.output.resolve())
    elif args.mode == "offline":
        offline(args.preview.resolve(), args.output.resolve())
    elif args.mode == "live":
        live(args.preview.resolve(), args.output.resolve())
    elif args.mode == "continue-ffi":
        continue_ffi(
            *(
                getattr(args, field).resolve()
                for field in ("preview", "output", "frozen_root", "library", "wire")
            )
        )
    elif args.mode == "reflect":
        reflect(
            *(
                getattr(args, field).resolve()
                for field in ("preview", "pilot", "output", "wire", "library")
            )
        )
    else:
        budget_control(
            *(
                getattr(args, field).resolve()
                for field in ("preview", "pilot", "output", "wire", "library")
            )
        )
