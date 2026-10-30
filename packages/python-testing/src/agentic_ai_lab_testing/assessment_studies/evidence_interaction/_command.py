# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command for the evidence interaction study."""

import argparse
import json
from pathlib import Path
from ._qualification import qualify
from ._snapshot import freeze


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=["qualify", "freeze", "calibrate", "solve", "annotate", "report"],
    )
    parser.add_argument("--run-dir", type=Path, required=True)
    args = parser.parse_args()
    run = args.run_dir.resolve()
    if args.command == "qualify":
        qualify(run)
    elif args.command == "freeze":
        freeze(run)
    else:
        plan = json.loads((run / "plan.json").read_text())
        globals()[args.command](run, plan)
