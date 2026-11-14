# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Declare identical task semantics and the preselected evidence capability boundary."


def _episode_instructions(assisted):
    """Own the episode instructions phase and retain its evidence checks."""
    instructions = (
        "Solve the complete complex question using only supplied finite relations. Reason naturally; no subproblem-first plan is required. "
        "cast maps Film to Actor; directed Film to Director; citizen Director to Country; mentor is directed Actor to Actor. "
        "Positive recursion uses a least fixed point; negation must be stratified and positively bound. Source heads are forbidden. "
        "Function calls are available but not forced. Prose and fenced JSON are accepted for a final answer. "
        "An answer can use original actor IDs or zero-based Actor indices, so copying opaque strings is unnecessary. "
        "For Scheme tools, a checked unary relation can be submitted by result reference; this does not certify English intent. "
        "Use existing checked components when the retention metadata permits; avoid reconstructing a completed recursive closure. "
        "Do not redeclare source relations or the already declared answer(Actor). A single head atom or head array is accepted. "
        "If needed, extend expressed claims in a later check. Verification reveals no correct values. "
        + (
            "Scheme execution is available."
            if assisted
            else "Reason over scanned raw facts; Scheme execution is unavailable."
        )
    )
    return instructions
