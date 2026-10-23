#!/usr/bin/env python3
"""Fail a qualification command that stops producing real output."""

import argparse
import ctypes
from functools import cache
import os
from pathlib import Path
import select
import selectors
import signal
import subprocess
import sys
import time


def forward_output(destination, chunk: bytes, timeout: float) -> None:
    """Forward every byte under one deadline, preserving the sink's fd mode."""
    descriptor = destination.fileno()
    blocking = os.get_blocking(descriptor)
    pending = memoryview(chunk)
    deadline = time.monotonic() + timeout
    os.set_blocking(descriptor, False)
    try:
        while pending:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("qualification output sink remained blocked")
            if not select.select([], [descriptor], [], min(0.25, remaining))[1]:
                continue
            try:
                written = os.write(descriptor, pending)
            except BlockingIOError:
                continue
            if not written:
                raise BrokenPipeError("qualification output sink accepted no bytes")
            pending = pending[written:]
    finally:
        os.set_blocking(descriptor, blocking)


def group_cpu(group: int) -> dict[int, float]:
    """Count live and reaped compiler CPU, with native Linux tick precision."""
    if Path('/proc/self/stat').exists():
        return proc_group_cpu(Path('/proc'), group, os.sysconf('SC_CLK_TCK'))
    listing = subprocess.check_output(
        ["ps", "-axo", "pid=,pgid=,time="], text=True, timeout=5
    )
    result = {}
    for line in listing.splitlines():
        pid, pgid, elapsed = line.split()
        if int(pgid) != group:
            continue
        if sys.platform == 'darwin':
            try:
                result[int(pid)] = darwin_process_cpu(int(pid))
            except ProcessLookupError:
                pass
            continue
        days, separator, elapsed_time = elapsed.rpartition("-")
        parts = [float(part) for part in elapsed_time.split(":")]
        seconds = 0.0
        for part in parts:
            seconds = seconds * 60 + part
        result[int(pid)] = seconds + (int(days) * 86400 if separator else 0)
    return result


class RusageInfoV1(ctypes.Structure):
    """Public Darwin sys/resource.h ABI; CPU counters are Mach absolute ticks."""
    _fields_ = [('uuid', ctypes.c_uint8 * 16),
                ('user', ctypes.c_uint64), ('system', ctypes.c_uint64),
                ('resources', ctypes.c_uint64 * 8),
                ('child_user', ctypes.c_uint64), ('child_system', ctypes.c_uint64),
                ('child_resources', ctypes.c_uint64 * 4)]


@cache
def darwin_rusage():
    library = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
    read = library.proc_pid_rusage
    read.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.POINTER(RusageInfoV1)]
    read.restype = ctypes.c_int
    return read


class MachTimebaseInfo(ctypes.Structure):
    _fields_ = [('numer', ctypes.c_uint32), ('denom', ctypes.c_uint32)]


@cache
def darwin_cpu_seconds_per_tick() -> float:
    info = MachTimebaseInfo()
    read = ctypes.CDLL('/usr/lib/libSystem.B.dylib').mach_timebase_info
    read.argtypes = [ctypes.POINTER(MachTimebaseInfo)]
    read.restype = ctypes.c_int
    if read(ctypes.byref(info)) != 0 or not info.numer or not info.denom:
        raise OSError('cannot read Darwin CPU timebase')
    return info.numer / info.denom / 1e9


def darwin_process_cpu(pid: int) -> float:
    usage = RusageInfoV1()
    if darwin_rusage()(pid, 1, ctypes.byref(usage)) != 0:  # RUSAGE_INFO_V1
        code = ctypes.get_errno()
        raise OSError(code, os.strerror(code), str(pid))
    return ((usage.user + usage.system + usage.child_user + usage.child_system)
            * darwin_cpu_seconds_per_tick())


def proc_group_cpu(root: Path, group: int, ticks: int) -> dict[int, float]:
    result = {}
    for entry in root.iterdir():
        if not entry.name.isdecimal():
            continue
        try:
            # comm can contain spaces or parentheses. Fields after its final
            # ')' start at state (3); pgrp is 5 and CPU fields are 14..17.
            fields = (entry / 'stat').read_text().rsplit(')', 1)[1].split()
            if int(fields[2]) == group:
                result[int(entry.name)] = sum(map(int, fields[11:15])) / ticks
        except (FileNotFoundError, ProcessLookupError):
            continue  # A compiler can exit between directory and stat reads.
    return result


def stop_group(child: subprocess.Popen[bytes]) -> None:
    try:
        os.killpg(child.pid, signal.SIGTERM)
        child.wait(timeout=1)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        child.wait()
    except ProcessLookupError:
        pass
    finally:
        # A completed leader can leave compiler descendants holding pipe FDs.
        # The supervisor owns this process group, including those descendants.
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--idle-seconds", type=float, default=5)
    parser.add_argument("--startup-seconds", type=float, default=5)
    parser.add_argument("--separate-stderr", action="store_true",
                        help="preserve stdout row protocols while supervising both streams")
    parser.add_argument("--cpu-progress", action="store_true",
                        help="build only: count measured process-group CPU advances as activity")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command or args.idle_seconds <= 0 or args.startup_seconds <= 0:
        parser.error("expected a command and positive startup/idle limits")

    child = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE if args.separate_stderr else subprocess.STDOUT,
        start_new_session=True,
        bufsize=0,
    )
    assert child.stdout is not None
    selector = selectors.DefaultSelector()
    selector.register(child.stdout, selectors.EVENT_READ, sys.stdout.buffer)
    if child.stderr is not None:
        selector.register(child.stderr, selectors.EVENT_READ, sys.stderr.buffer)
    last_output = time.monotonic()
    saw_output = False
    cpu_high_water = 0.0
    last_cpu_sample = 0.0
    signal.signal(signal.SIGTERM, lambda _signum, _frame: sys.exit(124))
    try:
        while selector.get_map() or child.poll() is None:
            ready = selector.select(timeout=0.25)
            if not ready and child.poll() is not None:
                # Drain ready bytes first, then terminate orphan descendants
                # instead of waiting forever on their inherited output pipes.
                return child.returncode
            if args.cpu_progress and time.monotonic() - last_cpu_sample >= 1:
                current_cpu = group_cpu(child.pid)
                total = sum(current_cpu.values())
                # Reaping transfers CPU from a child to its parent. Compare
                # group totals, so that transfer alone cannot invent activity.
                advance = max(0, total - cpu_high_water)
                cpu_high_water = max(cpu_high_water, total)
                last_cpu_sample = time.monotonic()
                if advance > 0:
                    last_output = last_cpu_sample
                    saw_output = True
                    print(f"[build-activity] cpu-advance={advance:.3f}s "
                          f"processes={len(current_cpu)}", file=sys.stderr, flush=True)
            if ready:
                for key, _events in ready:
                    chunk = os.read(key.fd, 65536)
                    if chunk:
                        limit = args.idle_seconds if saw_output else args.startup_seconds
                        remaining = limit - (time.monotonic() - last_output)
                        forward_output(key.data, chunk, remaining)
                        last_output = time.monotonic()
                        saw_output = True
                    else:
                        selector.unregister(key.fileobj)
            elif time.monotonic() - last_output > (
                args.idle_seconds if saw_output else args.startup_seconds
            ):
                limit = args.idle_seconds if saw_output else args.startup_seconds
                print(
                    f"[progress-watchdog] FAIL: no command "
                    f"{'output or CPU advance' if args.cpu_progress else 'output'} for "
                    f"{limit:g}s",
                    file=sys.stderr,
                    flush=True,
                )
                stop_group(child)
                return 124
        return child.wait()
    finally:
        stop_group(child)
        selector.close()
        child.stdout.close()
        if child.stderr is not None:
            child.stderr.close()


if __name__ == "__main__":
    raise SystemExit(main())
