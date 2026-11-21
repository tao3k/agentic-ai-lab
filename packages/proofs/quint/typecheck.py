# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Typecheck every owned Quint source, including generic imports and mutants."""
from pathlib import Path
import subprocess

models = Path(__file__).resolve().parent
quint = models / 'node_modules/.bin/quint'
version = subprocess.run([str(quint), '--version'], capture_output=True, text=True,
                         check=True, timeout=5).stdout.strip()
if version != '0.33.0':
    raise SystemExit(f'expected Quint 0.33.0, got {version!r}')
sources = [*models.glob('*.qnt'), *(models.parents[2] / 'core/dev/proofs/quint').glob('*.qnt')]
for source in sorted(sources):
    print(f'QUINT-TYPECHECK {source.name}', flush=True)
    subprocess.run([str(quint), 'typecheck', str(source)], check=True, timeout=5)
print('QUINT-TYPECHECK-OK', flush=True)
