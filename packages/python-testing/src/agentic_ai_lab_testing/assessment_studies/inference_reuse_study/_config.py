# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the inference reuse study study."""

SCHEMA = {
    "cast": ["Film", "Actor"],
    "directed": ["Film", "Director"],
    "citizen": ["Director", "Country"],
    "mentor": ["Actor", "Actor"],
    "actor_domain": ["Actor"],
    "banned_film": ["Film"],
    "selected_country": ["Country"],
    "target": ["Actor"],
}

STRUCTURES = (
    "mentor-chain",
    "witness-local-exclusion",
    "anti-existential",
    "recursive-mentor",
)
