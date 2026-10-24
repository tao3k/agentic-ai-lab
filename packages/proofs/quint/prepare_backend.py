# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Install/bootstrap the pinned backend before any proof qualification.

Dependency download is preparation, not a passing proof receipt. The proof
runner retains its independent five-second real-output and 45-second limits.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

models = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='poo-quint-prepare-') as directory:
    print('QUINT-PREPARE backend=0.62.1', flush=True)
    prepared = subprocess.run([
        str(models / 'node_modules/.bin/quint'), 'verify',
        str(models / 'GovernanceCore.qnt'), '--main', 'GovernanceCore',
        '--backend', 'tlc', '--apalache-version', '0.62.1',
        '--invariant', 'safety', '--verbosity', '3',
    ], cwd=directory, check=False, timeout=60, capture_output=True)
    if prepared.returncode:
        sys.stderr.buffer.write(prepared.stdout + prepared.stderr)
        raise SystemExit(prepared.returncode)
print('QUINT-PREPARE-OK (not a proof receipt)', flush=True)
