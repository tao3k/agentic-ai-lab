# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run the declared factor pilot command."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import argparse, json
from . import BASE, freeze, qualification, run

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["qualify", "freeze", "run"])
    args = parser.parse_args()
    if args.command == "qualify":
        qualification()
    elif args.command == "freeze":
        p = freeze()
        report_text("FROZEN", len(p["artifactHashes"]))
    else:
        run(json.loads((BASE / "frozen-plan.json").read_text()))
