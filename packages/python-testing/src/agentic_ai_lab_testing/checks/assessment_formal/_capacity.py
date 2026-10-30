# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Capacity for the assessment formal study."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys


def capacity(heap_mib: int = 1024) -> int:
    ceiling = os.environ.get("ASCENT_FORMAL_WORKERS")
    if ceiling is not None and (not ceiling.isdecimal() or int(ceiling) < 1):
        raise ValueError("ASCENT_FORMAL_WORKERS must be a positive integer")
    cpu = (
        len(os.sched_getaffinity(0))
        if hasattr(os, "sched_getaffinity")
        else (os.cpu_count() or 1)
    )
    quota = Path("/sys/fs/cgroup/cpu.max")
    if quota.exists():
        amount, period = quota.read_text().split()
        if amount.isdecimal():
            cpu = min(cpu, max(1, (int(amount) + int(period) - 1) // int(period)))
    memory = (
        os.sysconf("SC_PHYS_PAGES") * os.sysconf("SC_PAGE_SIZE")
        if sys.platform != "darwin"
        else int(subprocess.check_output(["sysctl", "-n", "hw.memsize"], text=True))
    )
    path = Path("/sys/fs/cgroup/memory.max")
    if path.exists() and path.read_text().strip().isdecimal():
        memory = min(memory, int(path.read_text()))
    # A 1 GiB TLC heap plus native overhead; leave room for Lean and the OS.
    detected = max(
        1, min(cpu, max(1, (memory - 2 * 1024**3) // ((heap_mib + 256) * 1024**2)))
    )
    # A caller may reduce concurrency without changing any model or obligation.
    return detected if ceiling is None else min(detected, int(ceiling))
