# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Command-line progress for the paired model studies."""

from __future__ import annotations

import json
import sys
from typing import Any


def report_record(case_id: str, repeat: int, arm: str,
                  record: dict[str, Any]) -> None:
    outcome = record["score"] if record["score"] is not None else record.get(
        "error_type", record.get("response_status")
    )
    sys.stdout.write(f"{case_id} {repeat} {arm} {outcome}\n")
    sys.stdout.flush()


def report_json(data: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(data, sort_keys=True) + "\n")
