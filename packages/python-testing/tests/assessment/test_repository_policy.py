# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import argparse
from pathlib import Path
import tempfile
import unittest
import os
import subprocess
import sys

from agentic_ai_lab_testing.assessment_studies.repository_policy import artifact_path, violation


class RepositoryPolicyTests(unittest.TestCase):
    def test_raw_files_and_sidecars_are_rejected_in_any_directory(self):
        for name in ('x/stdout.log', 'docs/a.json', 'x/raw.tar.gz', 'x/git.bundle',
                     'x/lib.dylib', 'x/lib.o12', 'x/result.stderr', 'x/result.stdout.license',
                     'x/lib.so.3', 'x/target/a.rs', 'rust/tests/receipt.json',
                     't/performance/rounds/receipt.sexp',
                     'docs/research/study/visible-answers.org',
                     'docs/research/study/thinking-episodes.md',
                     'docs/research/study/direct-thinking-annotations.md'):
            with self.subTest(name=name):
                self.assertIsNotNone(violation(name))

    def test_fixed_inputs_and_standard_language_tests_remain_sources(self):
        for name in ('t/fixtures/paper-inputs/openjdk-source.json',
                     't/qualification/fixtures/polonius/controls.sexp',
                     't/performance/ordered-relations/baseline.txt',
                     't/performance/ordered-relations/benchmark.ss',
                     'rust/ascent/tests/closure.rs', 'rust/ascent/benches/execution.rs',
                     'docs/performance/rust/runtime-crash-20261015.md'):
            with self.subTest(name=name):
                self.assertIsNone(violation(name))

    def test_output_rejected_before_directory_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            output = root / 'docs/results'
            with self.assertRaises(argparse.ArgumentTypeError):
                artifact_path(output, root=root)
            self.assertFalse(output.exists())
            self.assertEqual(artifact_path(root / '.cache/run', root=root), root / '.cache/run')

    def test_symlink_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / '.cache').mkdir()
            (root / '.cache/escape').symlink_to(root / 'docs', target_is_directory=True)
            with self.assertRaises(argparse.ArgumentTypeError):
                artifact_path(root / '.cache/escape/result.json', root=root)
            (root / '.cache/escape').unlink()
            (root / '.cache').rmdir()
            (root / '.cache').symlink_to(root / 'elsewhere', target_is_directory=True)
            with self.assertRaises(argparse.ArgumentTypeError):
                artifact_path(root / '.cache/result.json', root=root)

    def test_forced_addition_cannot_bypass_index_check(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / '.gitignore').write_text('*.stderr\n')
            (root / 'run.stderr').write_text('retained failure\n')
            subprocess.run(['git', '-C', str(root), 'add', '-f', 'run.stderr'], check=True)
            env = dict(os.environ, PYTHONPATH=str(Path(__file__).resolve().parents[2] / 'src'))
            result = subprocess.run([sys.executable, '-m', 'agentic_ai_lab_testing.assessment_studies.repository_policy'],
                                    cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn('run.stderr: execution output', result.stdout)
