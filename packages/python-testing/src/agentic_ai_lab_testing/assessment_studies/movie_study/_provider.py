# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Provider for the movie study study."""

import os
import shlex
from ._config import ROOT


def provider_fatal(response):
    terminal = response.get("terminal") or {}
    return (
        response.get("error") is not None
        or terminal.get("error") is not None
        or terminal.get("status") not in ("completed", "incomplete")
    )


def provider_key():
    if os.environ.get("DEEPSEEK_API_KEY"):
        return os.environ["DEEPSEEK_API_KEY"]
    path = ROOT / ".env"
    if path.is_file():
        for line in path.read_text().splitlines():
            text = line.strip()
            if text.startswith("export "):
                text = text[7:].lstrip()
            if text.split("=", 1)[0].strip() != "DEEPSEEK_API_KEY":
                continue
            parts = shlex.split(text.split("=", 1)[1].strip(), comments=True)
            if len(parts) != 1 or not parts[0]:
                raise ValueError("invalid DEEPSEEK_API_KEY assignment in .env")
            return parts[0]
    raise ValueError("DEEPSEEK_API_KEY is not configured")
