# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import copy
import tempfile
import unittest
from pathlib import Path
from agentic_ai_lab_testing.assessment_studies.repository_corpus import provenance, qualify, test_receipt as read_test_receipt, tree_identity, model_view


class RepositoryCorpus(unittest.TestCase):
    def record(self):
        return {'pullRequest': {'merged': True, 'created_at': '2026-10-08T01:00:00Z',
                                'merged_at': '2026-10-09T01:00:00Z', 'merge_commit_sha': 'a' * 40},
                'commit': {'sha': 'a' * 40, 'parents': [{'sha': 'b' * 40}],
                           'commit': {'author': {'date': '2026-10-08T01:00:00Z'},
                                      'committer': {'date': '2026-10-09T01:00:00Z'}}},
                'files': [{'filename': 'src/algorithm.py'}, {'filename': 'tests/test_algorithm.py'}]}

    def check(self, record):
        return provenance(record, earliest='2026-09-20T00:00:00Z', frozen_at='2026-10-10T00:00:00Z')

    def test_new_merge_does_not_hide_old_issue(self):
        record = self.record()
        self.assertTrue(self.check(record)['eligible'])
        record['issue'] = {'created_at': '2024-04-01T00:00:00Z'}
        self.assertFalse(self.check(record)['eligible'])
        self.assertIn('unknown', self.check(record)['trainingExposure'])

    def test_future_and_wrong_revision_rejected(self):
        record = self.record()
        record['commit']['commit']['committer']['date'] = '2026-10-11T00:00:00Z'
        self.assertFalse(self.check(record)['eligible'])
        record = self.record(); record['commit']['sha'] = 'c' * 40
        self.assertFalse(self.check(record)['eligible'])

    def test_linked_issue_must_be_collected_before_freshness_admission(self):
        record = self.record(); record['pullRequest']['body'] = 'Fixes #123'
        self.assertFalse(self.check(record)['eligible'])
        record['issue'] = {'number': 123, 'created_at': '2026-10-08T00:00:00Z'}
        self.assertTrue(self.check(record)['eligible'])
        record = self.record(); record['pullRequest']['body'] = '<!-- Example: Fixes #1234 -->\nNew regression.'
        self.assertTrue(self.check(record)['eligible'])

    def test_missing_tests_and_path_escape_rejected(self):
        record = self.record(); record['files'].pop()
        self.assertFalse(self.check(record)['eligible'])
        record['files'].append({'filename': '../tests/test_algorithm.py'})
        with self.assertRaises(ValueError): self.check(record)

    def test_actual_fail_to_pass_and_pass_to_pass(self):
        before = {'exitCode': 1, 'cases': {('suite', 'bug'): 'failed', ('suite', 'control'): 'passed'}}
        after = {'exitCode': 0, 'cases': {('suite', 'bug'): 'passed', ('suite', 'control'): 'passed'}}
        self.assertTrue(qualify(before, after)['qualified'])
        for mutant in ('skipped', 'error', 'failed'):
            broken = copy.deepcopy(after); broken['cases'][('suite', 'control')] = mutant
            self.assertFalse(qualify(before, broken)['qualified'])
        unchanged = copy.deepcopy(after)
        self.assertFalse(qualify(unchanged, after)['qualified'])
        missing = copy.deepcopy(after); missing['cases'].pop(('suite', 'control'))
        self.assertFalse(qualify(before, missing)['qualified'])

    def test_dependency_failure_is_not_a_bug(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp) / 'tests.xml'
            p.write_text('<testsuite><testcase name="x"><failure message="ModuleNotFoundError: dependency"/></testcase></testsuite>')
            self.assertEqual(next(iter(read_test_receipt(p, 1)['cases'].values())), 'error')

    def test_snapshot_tampering_and_solution_separation(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); (root / 'source.py').write_text('old source')
            first, _ = tree_identity(root)
            (root / 'source.py').write_text('new source')
            self.assertNotEqual(first, tree_identity(root)[0])
            (root / 'link').symlink_to('/tmp')
            with self.assertRaises(ValueError): tree_identity(root)
        manifest = {'status': 'admitted', 'public': {'question': 'Fix behavior.', 'parentSnapshotSha256': first, 'taskId': 'fresh-bug', 'goldPatch': 'SECRET'}, 'grader': {'goldPatch': 'SECRET'}}
        self.assertNotIn('SECRET', str(model_view(manifest)))
        manifest['status'] = 'candidate'
        with self.assertRaises(ValueError): model_view(manifest)


if __name__ == '__main__': unittest.main()
