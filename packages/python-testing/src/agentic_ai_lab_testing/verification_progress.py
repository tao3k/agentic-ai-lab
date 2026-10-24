# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Report completed parser work during unchanged pytest project gates."""
import sys


def _report_completion(path):
    sys.stdout.write('HARNESS PARSE COMPLETE ' + str(path) + '\n')
    sys.stdout.flush()


def main():
    import pytest

    previous = sys.getprofile()

    def completed(frame, event, result):
        if previous is not None:
            previous(frame, event, result)
        if (event == 'return' and result is not None
                and frame.f_code.co_name == 'parse_python_file'
                and frame.f_globals.get('__name__') == 'python_lang_parser.parser'):
            _report_completion(frame.f_locals['path'])

    sys.setprofile(completed)
    try:
        return pytest.main(sys.argv[1:])
    finally:
        sys.setprofile(previous)


if __name__ == '__main__':
    raise SystemExit(main())
