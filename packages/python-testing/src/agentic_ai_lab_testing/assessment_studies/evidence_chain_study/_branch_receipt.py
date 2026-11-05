# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Retain the original branch call reservation and supplied evidence provenance."

import copy


def _branch_call_receipt(
    case, arm, branch, step, req, bound, cap, reserve, entry_packet, supplied
):
    """Own the branch call receipt phase and retain its evidence checks."""
    rec = {
        "turn": branch["id"],
        "step": step,
        "usage": None,
        "grossTokens": None,
        "failure": None,
        "suppliedAtoms": copy.deepcopy(supplied),
        "inputReservation": bound,
        "outputCap": cap,
        "nativePacket": None,
        "entryEvidence": entry_packet,
        "suppliedFacts": copy.deepcopy(
            [o["conclusion"] for o in (entry_packet or {}).get("observations", [])]
        ),
        "outputTruncated": False,
    }
    return rec
