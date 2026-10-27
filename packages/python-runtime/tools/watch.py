# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Fail a test process group after five seconds without genuine command output."""
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time


def report_failure(message):
    """Keep watchdog diagnostics on stderr, separate from child test output."""
    sys.stderr.write(f'FAIL: {message}\n')
    sys.stderr.flush()


def capture_failed_process(pid):
    """Collect a bounded Darwin stack after admission has already failed."""
    directory = os.environ.get('AGENTIC_AI_LAB_TEST_STALL_DIAGNOSTICS')
    if sys.platform != 'darwin' or not directory:
        return
    try:
        target = Path(directory)
        target.mkdir(parents=True, exist_ok=True)
        with (target / f'stall-{pid}.txt').open('w') as output:
            try:
                subprocess.run(['/usr/bin/sample', str(pid), '1', '10'],
                               stdout=output, stderr=subprocess.STDOUT,
                               timeout=10, check=False)
            except (OSError, subprocess.TimeoutExpired) as error:
                output.write(f'Stack capture failed: {error}\n')
    except OSError:
        # Diagnostics cannot replace the original watchdog outcome.
        pass


def main(argv):
    child = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             start_new_session=True)
    try:
        with selectors.DefaultSelector() as ready:
            ready.register(child.stdout, selectors.EVENT_READ)
            deadline = time.monotonic() + 5
            while True:
                remaining = max(0, deadline - time.monotonic())
                if not ready.select(timeout=remaining):
                    now = time.monotonic()
                    # KqueueSelector also returns [] on InterruptedError.
                    # Retry only the ORIGINAL deadline's remaining time; an
                    # empty wakeup is neither progress nor proof of expiry.
                    if now < deadline:
                        continue
                    report_failure('five seconds without test progress')
                    # Separate a live/hung worker from an exited worker whose
                    # output pipe remains open. This never overrides failure.
                    sys.stderr.write(f'WATCHDOG-STATE pid={child.pid} child-exit={child.poll()} '
                                     f'silent-seconds={now - deadline + 5:.6f}\n')
                    sys.stderr.flush()
                    # This is failure-only work, never extra time to earn a pass.
                    capture_failed_process(child.pid)
                    if child.poll() is None:
                        os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
                    return 124
                data = os.read(child.stdout.fileno(), 65536)
                if not data:
                    break
                sys.stdout.buffer.write(data)
                sys.stdout.flush()
                deadline = time.monotonic() + 5
        return child.wait()
    finally:
        if child.poll() is None:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()


if __name__ == '__main__':
    # The outer native timeout cancels this process with TERM. Unwind main's
    # existing finally so the independently grouped worker cannot be orphaned.
    def cancel_watch(signum, _frame):
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGTERM, cancel_watch)
    sys.exit(main(sys.argv[1:]))
