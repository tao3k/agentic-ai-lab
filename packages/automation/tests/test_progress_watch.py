# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Failure diagnostics must never turn a missed progress deadline into a pass."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

SOURCE = Path(__file__).resolve().parents[3] / 'packages/python-runtime/tools/watch.py'
SPEC = importlib.util.spec_from_file_location('test_watch', SOURCE)
watch = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(watch)


class WatchTest(unittest.TestCase):
    def test_late_success_cannot_override_the_five_second_failure(self):
        child = MagicMock(pid=42)
        child.poll.return_value = 0
        child.wait.return_value = 0
        ready = MagicMock()
        ready.select.return_value = []
        output = io.StringIO()

        def diagnostic(pid):
            self.assertEqual(pid, 42)
            self.assertIn('FAIL: five seconds', output.getvalue())

        with patch.object(watch.subprocess, 'Popen', return_value=child), \
             patch.object(watch.selectors, 'DefaultSelector') as selector, \
             patch.object(watch, 'time', create=True) as clock, \
             patch.object(watch, 'capture_failed_process', side_effect=diagnostic), \
             contextlib.redirect_stderr(output):
            selector.return_value.__enter__.return_value = ready
            clock.monotonic.side_effect = [100., 100., 105.]
            self.assertEqual(watch.main(['child']), 124)
        ready.select.assert_called_once_with(timeout=5)

    def test_failed_process_group_is_still_terminated(self):
        child = MagicMock(pid=42)
        child.poll.side_effect = [None, None, 0]
        ready = MagicMock()
        ready.select.return_value = []
        with patch.object(watch.subprocess, 'Popen', return_value=child), \
             patch.object(watch.selectors, 'DefaultSelector') as selector, \
             patch.object(watch, 'time', create=True) as clock, \
             patch.object(watch, 'capture_failed_process'), \
             patch.object(watch.os, 'killpg') as kill, \
             contextlib.redirect_stderr(io.StringIO()):
            selector.return_value.__enter__.return_value = ready
            clock.monotonic.side_effect = [100., 100., 105.]
            self.assertEqual(watch.main(['child']), 124)
        kill.assert_called_once_with(42, signal.SIGKILL)

    def test_interrupted_selector_does_not_expire_an_unelapsed_deadline(self):
        child = MagicMock(pid=42)
        child.poll.return_value = 0
        child.wait.return_value = 0
        ready = MagicMock()
        # KqueueSelector may return [] immediately after InterruptedError.
        # EOF on the next wakeup is still inside the original five seconds.
        ready.select.side_effect = [[], [(None, watch.selectors.EVENT_READ)]]
        with patch.object(watch.subprocess, 'Popen', return_value=child), \
             patch.object(watch.selectors, 'DefaultSelector') as selector, \
             patch.object(watch, 'time', create=True) as clock, \
             patch.object(watch.os, 'read', return_value=b''), \
             patch.object(watch, 'capture_failed_process') as sample, \
             contextlib.redirect_stderr(io.StringIO()):
            selector.return_value.__enter__.return_value = ready
            clock.monotonic.side_effect = [100., 100., 100.1, 100.1]
            self.assertEqual(watch.main(['child']), 0)
        self.assertEqual(ready.select.call_count, 2)
        self.assertAlmostEqual(ready.select.call_args_list[0].kwargs['timeout'], 5.)
        self.assertAlmostEqual(ready.select.call_args_list[1].kwargs['timeout'], 4.9)
        sample.assert_not_called()

    def test_sample_failure_is_bounded_and_retained(self):
        with tempfile.TemporaryDirectory() as directory, \
             patch.dict(os.environ, AGENTIC_AI_LAB_TEST_STALL_DIAGNOSTICS=directory), \
             patch.object(watch.sys, 'platform', 'darwin'), \
             patch.object(watch.subprocess, 'run',
                          side_effect=subprocess.TimeoutExpired('sample', 10)) as run:
            watch.capture_failed_process(42)
            self.assertEqual(run.call_args.kwargs['timeout'], 10)
            self.assertIn('Stack capture failed',
                          (Path(directory) / 'stall-42.txt').read_text())

    def test_normal_eof_preserves_the_child_status_without_sampling(self):
        for status in (0, 7):
            child = MagicMock(pid=42)
            child.poll.return_value = status
            child.wait.return_value = status
            ready = MagicMock()
            ready.select.return_value = [(None, watch.selectors.EVENT_READ)]
            with patch.object(watch.subprocess, 'Popen', return_value=child), \
                 patch.object(watch.selectors, 'DefaultSelector') as selector, \
                 patch.object(watch.os, 'read', return_value=b''), \
                 patch.object(watch, 'capture_failed_process') as sample:
                selector.return_value.__enter__.return_value = ready
                self.assertEqual(watch.main(['child']), status)
            sample.assert_not_called()

    def test_outer_cancellation_reaps_the_real_worker_group(self):
        worker = 'import os,time; print(os.getpid(), flush=True); time.sleep(60)'
        process = subprocess.Popen(
            [sys.executable, str(SOURCE), sys.executable, '-c', worker],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        worker_pid = None
        try:
            worker_pid = int(process.stdout.readline())
            process.send_signal(signal.SIGTERM)
            self.assertEqual(process.wait(timeout=3), 128 + signal.SIGTERM)
            with self.assertRaises(ProcessLookupError):
                os.kill(worker_pid, 0)
            worker_pid = None
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=3)
            if worker_pid is not None:
                try:
                    os.kill(worker_pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            process.stdout.close()
            process.stderr.close()


if __name__ == '__main__':
    unittest.main()
