# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Build the current obligation view and source-bound evidence packet without changing tool semantics."

from ._shared_cases import shared_packet


def _shared_turn_context(plan, task, ids, store, arm):
    """Own the shared turn context phase and retain its evidence checks."""
    context = {
        "question": plan["question"],
        "obligations": [n for n in task["needs"] if n[0] in ids],
    }
    packet = shared_packet(store, task, ids) if arm != "baseline" else None
    if packet:
        context["evidence"] = {k: packet[k] for k in ("scope", "facts")}
        if arm == "scheme":
            context["evidence"].update(
                {k: packet[k] for k in ("fragments", "nodeEncoding")}
            )
    return context, packet
