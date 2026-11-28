# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Record the unaltered returned provider usage, prediction and terminal status."

from ..trajectory_study import extract


def _call_observation(stem, stage, global_round, terminal, meta, raw):
    """Own the call observation phase and retain its evidence checks."""
    observation = {
        "id": stem,
        "stage": stage,
        "round": global_round,
        "usage": terminal.get("usage"),
        "status": terminal.get("status"),
        "error": meta.get("error"),
        "seconds": meta["providerSeconds"],
        "prediction": extract(raw),
    }
    return observation
