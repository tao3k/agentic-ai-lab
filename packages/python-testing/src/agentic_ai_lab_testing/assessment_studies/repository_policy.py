# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Admission rules for source files and local execution output destinations."""
import argparse
from pathlib import Path, PurePosixPath
import subprocess


RAW_SUFFIXES = frozenset({
    '.log', '.stdout', '.stderr', '.gz', '.tgz', '.zip', '.tar', '.bundle',
    '.dylib', '.so', '.dll', '.exe', '.o', '.a', '.pyc', '.whl', '.jsonl', '.bin',
})
BUILD_DIRECTORIES = frozenset({'.cache', '.gerbil', '.lake', '__pycache__',
                               'target', 'node_modules', '.venv'})
DOCUMENT_SUFFIXES = frozenset({'.md', '.org', '.svg', '.png', '.jpg', '.jpeg', '.webp'})
TRANSCRIPT_NAMES = frozenset({'questions.org', 'visible-answers.org', 'rounds.org',
                              'thinking-episodes.md', 'thinking-evidence.md'})


def violation(name):
    """Check the tracked path, including forced additions ignored by Git."""
    path = PurePosixPath(name)
    base = PurePosixPath(name.removesuffix('.license'))
    if BUILD_DIRECTORIES.intersection(path.parts):
        return 'build/cache directory'
    if (base.suffix in RAW_SUFFIXES or '.so.' in base.name
            or (base.suffix.startswith('.o') and base.suffix[2:].isdigit())):
        return 'execution output or compiled artifact'
    if name.startswith(('rust/tests/', 'rust/benchmarks/')):
        return 'workspace output directory; use crate tests/ or benches/'
    if name.startswith('docs/') and base.suffix not in DOCUMENT_SUFFIXES:
        return 'documentation contains generated records or source snapshots'
    if name.startswith('docs/research/') and (
            base.name in TRANSCRIPT_NAMES or base.name.endswith('thinking-annotations.md')):
        return 'generated experiment transcripts belong in .cache, regardless of text format'
    if name.startswith('t/performance/'):
        if base.suffix not in {'.ss', '.md', '.org'} and base.name not in {'baseline.txt', 'justfile'}:
            return 'performance results belong in .cache; keep executable fixtures here'
    if name.startswith('t/qualification/asp-v0122/') and base.name != 'README.md':
        return 'historical qualification outputs belong in .cache'
    return None


def artifact_path(value, *, root=None):
    """Reject a workbench output outside this checkout's cache before writing."""
    root = (Path.cwd() if root is None else Path(root)).resolve()
    # Resolve existing symlink components, including a symlinked .cache itself.
    path = Path(value).resolve()
    cache = root / '.cache'
    if not path.is_relative_to(cache) or cache.resolve() != cache:
        raise argparse.ArgumentTypeError('execution outputs must be inside ' + str(cache))
    return path


def main():
    names = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
    failures = [(name, reason) for name in names if name and (reason := violation(name))]
    for name, reason in failures:
        print(f'{name}: {reason}')
    if failures:
        raise SystemExit(1)
    print(f'Repository policy: {sum(bool(n) for n in names)} tracked paths admitted')


if __name__ == '__main__':
    main()
