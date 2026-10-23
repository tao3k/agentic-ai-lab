# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Check build supervision against CPU work, a sleeping child and failure."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from agentic_ai_lab_testing.assessment_studies.supervision import proc_group_cpu, darwin_process_cpu


class BuildActivity(unittest.TestCase):
    def run_child(self, code):
        return subprocess.run(
            [sys.executable, str(Path(__import__('agentic_ai_lab_testing.assessment_studies.supervision',fromlist=['x']).__file__)),
             '--cpu-progress', '--startup-seconds', '2', '--idle-seconds', '2',
             '--', sys.executable, '-c', code],
            capture_output=True, text=True, timeout=15)

    def test_cpu_work_can_continue_without_output(self):
        result = self.run_child('import time\nend=time.monotonic()+4\n'
                                'while time.monotonic()<end: pass\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('cpu-advance=', result.stderr)

    def test_sleeping_child_is_stopped(self):
        result = self.run_child('import time; time.sleep(10)')
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertIn('FAIL', result.stderr)

    def test_child_failure_propagates(self):
        result = self.run_child('raise SystemExit(7)')
        self.assertEqual(result.returncode, 7, result.stderr)

    def test_short_lived_compiler_children_count_after_reaping(self):
        result = self.run_child(
            'import subprocess,sys,time\nend=time.monotonic()+4\n'
            'while time.monotonic()<end:\n'
            ' subprocess.run([sys.executable,"-c",'
            '"import time; end=time.process_time()+.04\\nwhile time.process_time()<end: pass"], check=True)\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('cpu-advance=', result.stderr)

    def test_closed_output_does_not_disable_stall_detection(self):
        result = self.run_child('import os,time; os.close(1); os.close(2); time.sleep(10)')
        self.assertEqual(result.returncode, 124, result.stderr)

    def test_closed_output_keeps_real_cpu_work_alive(self):
        result = self.run_child('import os,time\nos.close(1); os.close(2)\n'
                                'end=time.monotonic()+4\nwhile time.monotonic()<end: pass\n')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_failed_leader_does_not_wait_for_orphan_pipe_owners(self):
        result = self.run_child('import subprocess,sys; '
                                'subprocess.Popen([sys.executable,"-c","import time; time.sleep(30)"]); '
                                'raise SystemExit(7)')
        self.assertEqual(result.returncode, 7, result.stderr)

    def test_darwin_cpu_converts_self_and_reaped_child_ticks(self):
        def read(pid, flavor, pointer):
            self.assertEqual((pid, flavor), (42, 1))
            usage = pointer._obj
            usage.user, usage.system = 2400000, 4800000
            usage.child_user, usage.child_system = 7200000, 9600000
            return 0
        for scale in (125 / 3 / 1e9, 1 / 1e9):
            with self.subTest(scale=scale), \
                 patch('agentic_ai_lab_testing.assessment_studies.supervision.darwin_rusage', return_value=read), \
                 patch('agentic_ai_lab_testing.assessment_studies.supervision.darwin_cpu_seconds_per_tick', return_value=scale):
                self.assertAlmostEqual(darwin_process_cpu(42), 24000000 * scale)

    @unittest.skipUnless(sys.platform == 'darwin', 'Darwin native CPU clock')
    def test_darwin_native_cpu_matches_process_clock(self):
        before = darwin_process_cpu(os.getpid())
        started = time.process_time()
        while time.process_time() - started < .2:
            pass
        elapsed = time.process_time() - started
        measured = darwin_process_cpu(os.getpid()) - before
        self.assertAlmostEqual(measured, elapsed, delta=.02)

    def test_linux_cpu_includes_reaped_children_and_tick_precision(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for pid, group, times in ((11, 42, (2, 3, 4, 5)), (12, 43, (9, 9, 9, 9))):
                process = root / str(pid)
                process.mkdir()
                fields = ['S', '1', str(group)] + ['0'] * 8 + list(map(str, times))
                (process / 'stat').write_text(f'{pid} (compiler (child)) ' + ' '.join(fields))
            (root / '13').mkdir()  # Directory of an already exited compiler.
            self.assertEqual(proc_group_cpu(root, 42, 100), {11: .14})


class SeparateStreams(unittest.TestCase):
    def run_child(self, code):
        return subprocess.run(
            [sys.executable, str(Path(__import__('agentic_ai_lab_testing.assessment_studies.supervision',fromlist=['x']).__file__)),
             '--separate-stderr', '--startup-seconds', '.5', '--idle-seconds', '.5',
             '--', sys.executable, '-c', code],
            capture_output=True, timeout=5)

    def test_binary_stdout_and_diagnostics_remain_separate(self):
        result = self.run_child("import sys; sys.stdout.buffer.write(b'row\\x00\\xff\\n'); "
                                "sys.stderr.buffer.write(b'admitted\\n')")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'row\x00\xff\n')
        self.assertEqual(result.stderr, b'admitted\n')

    def test_real_stderr_progress_keeps_empty_stdout_alive(self):
        result = self.run_child("import sys,time\nfor i in range(6):\n"
                                " print(i,file=sys.stderr,flush=True); time.sleep(.2)\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'')
        self.assertEqual(result.stderr, b'0\n1\n2\n3\n4\n5\n')

    def test_total_wall_time_does_not_replace_real_inactivity(self):
        advancing = self.run_child("import time\nfor i in range(6):\n"
                                   " print(i, flush=True); time.sleep(.2)\n")
        self.assertEqual(advancing.returncode, 0, advancing.stderr)
        self.assertEqual(advancing.stdout, b'0\n1\n2\n3\n4\n5\n')
        stalled = self.run_child("import time; print('started', flush=True); time.sleep(2)")
        self.assertEqual(stalled.returncode, 124, stalled.stderr)
        self.assertIn(b'no command output', stalled.stderr)

    def test_stalled_child_is_rejected_and_failure_propagates(self):
        stalled = self.run_child('import time; time.sleep(2)')
        self.assertEqual(stalled.returncode, 124, stalled.stderr)
        self.assertEqual(stalled.stdout, b'')
        self.assertIn(b'FAIL', stalled.stderr)
        failed = self.run_child('raise SystemExit(7)')
        self.assertEqual(failed.returncode, 7, failed.stderr)


if __name__ == '__main__':
    unittest.main()
