#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Package-fixture preparation only; runtime never invokes flake lock."""
import argparse
from pathlib import Path
import shutil
import subprocess
import json

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--package-ref', required=True, help='Pinned Nix package-set flake reference')
args = parser.parse_args()
root = Path(__file__).resolve().parents[3]
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=False)
package_ref = args.package_ref
fixture = root / 't/fixtures/opentofu'
source = (fixture / 'selected-flake/flake.nix.in').read_text()
(output / 'flake.nix').write_text(source.replace('@PACKAGE_SET@', package_ref))
shutil.copy2(fixture / 'selected-flake/providers.nix', output / 'providers.nix')
shutil.copy2(fixture / 'aws-5.100.0/package.nix', output / 'aws-package.nix')
shutil.copy2(fixture / 'hashicorp-package.nix', output / 'hashicorp-package.nix')
shutil.copytree(root / 'modules/services/opentofu/nix', output / 'lib')
subprocess.run(['nix', '--extra-experimental-features', 'nix-command flakes',
                'flake', 'lock', f'path:{output}'], check=True, timeout=120)
print(output)
