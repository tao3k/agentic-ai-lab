# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Prompt for the factor pilot study."""

import json


def question(c, phase, cards):
    n = 6 + phase
    return json.dumps(
        {
            "task": c["id"],
            "phase": phase,
            "jobs": list(range(n)),
            "durations": c["durations"][:n],
            "weights": c["weights"][phase],
            "sourceEdges": c["edges"],
            "sourceIdentity": c["id"],
            "retained": cards,
            "guidance": "This objective differs from prior phases. Check useful implied precedence factors (especially nonadjacent jobs) once and reuse supported evidence. Compare several feasible schedules. Submit best found.",
        },
        sort_keys=True,
    )
