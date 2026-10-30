# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Projection for the consumption study study."""

import copy, json


def parse(raw):
    decoder = json.JSONDecoder()
    for index, char in enumerate(raw):
        if char != "{":
            continue
        try:
            obj, _ = decoder.raw_decode(raw[index:])
        except ValueError:
            continue
        if isinstance(obj, dict) and isinstance(obj.get("rule"), dict):
            return obj
    return None


def proposed(case, stage, obj):
    program = copy.deepcopy(case["programs"][stage])
    program["rules"][-1] = obj["rule"]
    return program
