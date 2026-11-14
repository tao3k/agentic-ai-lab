# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Seal preview and result bytes in a durable, independently verifiable bundle."""

from __future__ import annotations

import hashlib
import json
import shutil
import tempfile
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_durable(path: Path) -> None:
    resolved = path.resolve()
    if any(resolved.is_relative_to(root.resolve()) for root in
           (Path('/tmp'), Path('/private/tmp'), Path(tempfile.gettempdir()))):
        raise ValueError('evidence archive must be outside temporary directories')
    if path.exists():
        raise ValueError('evidence archive destination must be new')


def require_archive(destination: Path, *sources: Path) -> None:
    require_durable(destination)
    if any(destination.resolve().is_relative_to(source.resolve())
           or source.resolve().is_relative_to(destination.resolve()) for source in sources):
        raise ValueError('archive destination must be outside evidence inputs')


def verify(directory: Path) -> dict:
    manifest = json.loads((directory / 'archive-manifest.json').read_text())
    if any(p.is_symlink() for p in directory.rglob('*')):
        raise RuntimeError('evidence archive contains symbolic links')
    actual = {str(p.relative_to(directory)): sha256(p) for p in directory.rglob('*')
              if p.is_file() and p != directory / 'archive-manifest.json'}
    if actual != manifest['files']:
        raise RuntimeError('evidence archive file inventory or hashes changed')
    return manifest


def seal(preview: Path, results: Path, destination: Path, *, outcome: str) -> dict:
    require_archive(destination, preview, results)
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix='.evidence-staging-', dir=destination.parent))
    try:
        for name, source in (('preview', preview), ('results', results)):
            if any(p.is_symlink() for p in source.rglob('*')):
                raise ValueError('evidence inputs must not contain symbolic links')
            shutil.copytree(source, staging / name)
        manifest = {'format': 'poo-model-evidence-v1', 'outcome': outcome,
                    'files': {str(p.relative_to(staging)): sha256(p)
                              for p in staging.rglob('*') if p.is_file()}}
        (staging / 'archive-manifest.json').write_text(json.dumps(manifest, sort_keys=True, indent=2) + '\n')
        verify(staging)
        staging.rename(destination)
        return verify(destination)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
