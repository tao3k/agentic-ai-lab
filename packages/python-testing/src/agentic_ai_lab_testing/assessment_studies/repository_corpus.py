# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Admission checks for temporally held-out, executable repository tasks.

GitHub dates establish provenance, not knowledge of a model's training set.
Only evaluator-side metadata enters this module; its output is not a prompt.
"""
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath


def timestamp(value):
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.tzinfo is None:
        raise ValueError('provenance timestamps must include a timezone')
    return result.astimezone(timezone.utc)


def repository_path(value):
    path = PurePosixPath(value)
    if not value or path.is_absolute() or '..' in path.parts or '\\' in value:
        raise ValueError('invalid repository path')
    return path


def tree_identity(directory):
    """Bind every model-visible file; never follow links outside its snapshot."""
    files = {}
    for path in sorted(directory.rglob('*')):
        if path.is_symlink():
            raise ValueError('model snapshot may not contain symbolic links')
        if path.is_file():
            relative = path.relative_to(directory).as_posix()
            repository_path(relative)
            if '.git' in Path(relative).parts:
                raise ValueError('model snapshot may not contain git history')
            files[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    if not files:
        raise ValueError('empty model snapshot')
    return hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest(), files


def provenance(record, *, earliest, frozen_at):
    """Return explicit exclusion reasons, including old issue/new merge cases."""
    reasons = []
    lower, upper = timestamp(earliest), timestamp(frozen_at)
    pr, commit = record['pullRequest'], record['commit']
    if not pr.get('merged') or not pr.get('merged_at'):
        return {'eligible': False, 'reasons': ['pull request is not merged']}
    issue = record.get('issue')
    body = re.sub(r'<!--.*?-->', '', pr.get('body') or '', flags=re.DOTALL)
    references = re.findall(r'(?i)\bfix(?:es|ed)?\s+#(\d+)', body)
    if references and (not issue or str(issue.get('number')) not in references):
        reasons.append('original linked issue disclosure metadata has not been collected')
    dates = {'pullRequestCreated': pr['created_at'], 'merged': pr['merged_at'],
             'commitAuthored': commit['commit']['author']['date'],
             'commitCommitted': commit['commit']['committer']['date']}
    if issue:
        dates['issueCreated'] = issue['created_at']
    first_public = min(timestamp(value) for key, value in dates.items()
                       if key in ('pullRequestCreated', 'issueCreated'))
    if first_public < lower:
        reasons.append('problem first disclosed before the temporal holdout window')
    if any(timestamp(value) > upper for value in dates.values()):
        reasons.append('provenance contains a date after the frozen collection time')
    sha = pr['merge_commit_sha']
    parents = commit.get('parents', [])
    if not re.fullmatch(r'[0-9a-f]{40}', sha or '') or commit.get('sha') != sha or not parents:
        reasons.append('fixed revision or parent identity is missing or inconsistent')
    filenames = [f['filename'] for f in record['files']]
    for filename in filenames:
        repository_path(filename)
    tests = [n for n in filenames if is_test(n)]
    source_suffixes = ('.py', '.rs', '.ss', '.scm', '.js', '.ts', '.go', '.c', '.cpp', '.java', '.jl')
    code = [n for n in filenames if n.endswith(source_suffixes) and not is_test(n)]
    if not tests or not code:
        reasons.append('task needs both executable source changes and regression tests')
    return {'eligible': not reasons, 'reasons': reasons, 'dates': dates,
            'firstPublicAt': first_public.isoformat(), 'fixedCommit': sha,
            'parentCommit': parents[0]['sha'] if parents else None,
            'sourceFiles': code, 'testFiles': tests,
            'trainingExposure': 'unknown; recency is not proof of exclusion from training'}


def is_test(path):
    p = PurePosixPath(path)
    return path.endswith('.py') and (any(part in ('test', 'tests', 'testing') for part in p.parts)
                                   or p.name.startswith('test_'))


def test_receipt(xml_path, exit_code):
    """Keep collection/setup errors distinct from failing semantic assertions."""
    root = ET.parse(xml_path).getroot()
    cases = {}
    for case in root.iter('testcase'):
        key = (case.get('classname', ''), case.get('name', ''))
        if key in cases:
            raise ValueError('duplicate test identity in qualification receipt')
        if case.find('error') is not None:
            status = 'error'
        elif case.find('failure') is not None:
            failure = case.find('failure')
            message = failure.get('message', '') + (failure.text or '')
            # A missing dependency or broken harness is not a demonstrated bug.
            status = 'error' if re.search(r'\b(?:ImportError|ModuleNotFoundError|SyntaxError)\b', message) else 'failed'
        elif case.find('skipped') is not None:
            status = 'skipped'
        else:
            status = 'passed'
        cases[key] = status
    return {'exitCode': exit_code, 'cases': cases}


def qualify(before, after):
    """Same tests, actual failure-to-pass, and no lost passing control tests."""
    reasons = []
    left, right = before['cases'], after['cases']
    if not left or set(left) != set(right):
        reasons.append('before and after must execute the same nonempty test identities')
    if before['exitCode'] != 1 or after['exitCode'] != 0:
        reasons.append('expected semantic failure exit 1 before and successful exit 0 after')
    if any(v not in ('passed', 'failed') for v in left.values()) or any(v != 'passed' for v in right.values()):
        reasons.append('errors, skips, or post-fix failures cannot qualify a task')
    failed = [key for key, value in left.items() if value == 'failed' and right.get(key) == 'passed']
    passed = [key for key, value in left.items() if value == 'passed' and right.get(key) == 'passed']
    if not failed:
        reasons.append('no failing test becomes passing')
    return {'qualified': not reasons, 'reasons': reasons,
            'failToPass': [list(k) for k in sorted(failed)],
            'passToPass': [list(k) for k in sorted(passed)]}


def model_view(manifest):
    """Allow-list the public task. PR descriptions and grader inputs stay private.

    This is payload construction, not filesystem isolation. The evaluator must
    expose only the separately hashed parent snapshot through its read tools.
    """
    if manifest.get('status') != 'admitted':
        raise ValueError('only admitted tasks may enter paid evaluation')
    public = manifest['public']
    required = ('question', 'parentSnapshotSha256', 'taskId')
    if any(not public.get(key) for key in required):
        raise ValueError('incomplete model-visible task')
    return {key: public[key] for key in required}
