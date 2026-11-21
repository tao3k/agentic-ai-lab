# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from pathlib import Path
from types import SimpleNamespace

import scheme_durable_fixtures as fixture


def test_durable_fixture_preserves_dependency_loadpath_and_bounds_process(monkeypatch):
    expected = '/compiled/project:/compiled/dependency'
    monkeypatch.setenv('GERBIL_LOADPATH', expected)
    monkeypatch.setattr(fixture.shutil, 'which', lambda _: '/usr/bin/gxi')
    original_exists = Path.exists
    monkeypatch.setattr(Path, 'exists', lambda p: True if p.name == 'lib' and p.parent.name == '.gerbil' else original_exists(p))
    calls = []

    def run(argv, **kwargs):
        assert argv[:2] == ["gxi", "-:max-heap=1G,debug=q"]
        calls.append(kwargs)
        return SimpleNamespace(stdout=b'policy' + fixture._SCHEME_PAYLOAD_SEPARATOR + b'runtime')

    monkeypatch.setattr(fixture.subprocess, 'run', run)
    fixture._scheme_generated_durable_payloads.cache_clear()
    try:
        assert fixture._scheme_generated_durable_payloads() == (b'policy', b'runtime')
    finally:
        fixture._scheme_generated_durable_payloads.cache_clear()
    assert calls[0]['env']['GERBIL_LOADPATH'] == expected
    assert calls[0]['timeout'] == 90
    assert calls[0]['check'] is True
