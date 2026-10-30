# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Run the declared factor budget command."""

import argparse, json
from . import BASE, freeze, qualify, run

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["qualify", "freeze", "calibrate", "run"])
    a = parser.parse_args()
    if a.command == "qualify":
        qualify()
    elif a.command == "freeze":
        freeze()
    else:
        run(
            json.loads((BASE / "frozen-plan.json").read_text()),
            a.command == "calibrate",
        )
