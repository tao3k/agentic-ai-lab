# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Persist actual calls, checks and verdicts with their trajectory snapshot."

import json


def _save_ledger(output, calls, checks, verdicts, ledger=None):
    """Persist the actual interaction history and its current trajectory snapshot."""
    (output / "records.json").write_text(
        json.dumps(
            {
                "calls": calls,
                "checks": checks,
                "verdicts": verdicts,
                "trajectory": ledger,
            },
            indent=2,
        )
    )
