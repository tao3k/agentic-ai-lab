# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""CLI for direct Scheme capability validation without semantic templates."""
import argparse
from pathlib import Path
from .direct.preview import prepare
from .direct.live import live

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--poo-root', type=Path, required=True)
    parser.add_argument('--ascent-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--preview', type=Path)
    parser.add_argument('--approved-plan-sha256')
    args = parser.parse_args()
    if args.preview:
        live(args.poo_root.resolve(), args.preview.resolve(), args.output.resolve(),
             args.approved_plan_sha256, args.ascent_root.resolve())
    else:
        prepare(args.poo_root.resolve(), args.ascent_root.resolve(), args.output.resolve())


if __name__ == '__main__':
    main()
