# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Declare the fixed task, tool semantics and selected evidence capability."


def _episode_instruction(assisted):
    """Own the episode instruction phase and retain its evidence checks."""
    instruction = (
        "Solve the complete complex question using only supplied finite facts. No source facts are initially known; acquire facts or check evidence before answering. "
        "Use function calls. Retain established evidence rather than repeat completed reasoning. No required subproblem decomposition. "
        "cast relates Film to Actor, directed Film to Director, citizen Director to Country, mentor directed Actor to Actor. "
        "Rules use head arrays; shared variables join; multiple rules union; positive recursion reaches a least fixed point; negation is stratified with variables positively bound. "
        "answer(Actor) and source declarations already exist; contract.relations declares only new derived relations. Never define source heads. "
        "Source-bound evidence aliases can be referenced in later rule bodies without redeclaring them. "
        "Submit an answer with submit_answer; verifier reveals no gold values. "
        + (
            "Scheme checks and retains expressed reasoning evidence to support later thinking."
            if assisted
            else "Reason over scanned raw facts; derived query execution is unavailable."
        )
    )
    return instruction
