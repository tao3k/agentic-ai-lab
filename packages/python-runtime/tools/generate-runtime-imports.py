#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Generate authoring import phases from the Gerbil compiler's module closure."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
ROOTS = ['modules/workflow/scenario/composition-syntax.ss', 'modules/funflow/profile-library.ss',
         'modules/funflow/runtime-load-projection.ss']


def main():
    expression = '''(for-each (lambda (root)
      (let (ctx (import-module root))
        (for-each (lambda (dep) (displayln (expander-context-id dep)))
                  (gxc#find-runtime-module-deps ctx))
        (displayln (expander-context-id ctx))))
      '(%s))''' % ' '.join(json.dumps(root) for root in ROOTS)
    result = subprocess.run(['gxi', '-:max-heap=1G,debug=q', '-e',
        '(import :gerbil/compiler/driver :gerbil/expander)', '-e', expression],
        cwd=ROOT, check=True, capture_output=True, text=True, timeout=60)
    modules = list(dict.fromkeys(name for name in result.stdout.splitlines()
        if name.startswith(('clan/', 'core/', 'poo-flow/')) and ' ' not in name))
    for name in ['core/profile-composition/selection-syntax',
                 'poo-flow/modules/workflow/scenario/composition-syntax',
                 'poo-flow/modules/funflow/profile-library']:
        if name not in modules:
            modules.append(name)
    target = ROOT / 'packages/python-runtime/src/poo_flow_runtime/projections/runtime_load_imports.json'
    target.write_text(json.dumps({'schema': 'poo-flow.runtime-authoring-imports.v1',
        'owner': 'Gerbil compiler runtime dependency closure', 'roots': ROOTS,
        'modules': modules}, indent=2) + '\n')
    sys.stdout.write(f'GENERATED {len(modules)} actual import phases\n')


if __name__ == '__main__':
    main()
