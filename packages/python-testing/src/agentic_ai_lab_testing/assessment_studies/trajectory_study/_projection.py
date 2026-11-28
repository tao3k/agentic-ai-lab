# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Projection for the trajectory study study."""

import json


def extract(raw):
    decoder = json.JSONDecoder()
    # Select the final answer object, allowing reasoning and Markdown around it.
    matches = []
    for i, char in enumerate(raw):
        if char != "{":
            continue
        try:
            value, _ = decoder.raw_decode(raw[i:])
        except ValueError:
            continue
        if isinstance(value, dict) and isinstance(value.get("answer"), list):
            matches.append(value["answer"])
    if not matches:
        return None
    value = matches[-1]
    return sorted(set(value)) if all(isinstance(x, str) for x in value) else None
