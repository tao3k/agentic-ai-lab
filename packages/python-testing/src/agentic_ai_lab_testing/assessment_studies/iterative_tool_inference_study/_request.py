# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"Construct one request from the fixed task contract and complete current response history."

from ._tools import tool_definitions


def _episode_request(plan, instruction, history, assisted):
    """Own the episode request phase and retain its evidence checks."""
    request = {
        "model": "deepseek-flash",
        "instructions": instruction,
        "input": history.input(),
        "tools": tool_definitions(assisted),
        "tool_choice": "auto",
        "reasoning": {"effort": "high"},
        "max_output_tokens": plan["maxOutputTokens"],
        "stream": True,
        "store": False,
    }
    return request
