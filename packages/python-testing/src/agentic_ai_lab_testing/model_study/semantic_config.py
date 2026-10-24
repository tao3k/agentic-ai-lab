# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Read provider configuration as literals without executing shell code."""
import shlex


def configuration(path):
    values = {}
    for line in path.read_text().splitlines():
        name, separator, value = line.strip().removeprefix('export ').partition('=')
        name = name.strip()
        if separator and name in ('DEEPSEEK_API_KEY', 'DEEPSEEK_MODEL', 'ANTHROPIC_MODEL'):
            words = shlex.split(value, comments=True)
            if len(words) != 1:
                raise ValueError('configuration requires a single literal value: ' + name)
            values[name] = words[0]
    return values

