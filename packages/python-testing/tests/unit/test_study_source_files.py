# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Moved implementations remain evidence inputs; unrelated files stay separate."""

from hashlib import sha256

from agentic_ai_lab_testing.assessment_studies._source_files import _source_files


def test_source_closure_follows_imports_without_running_them(tmp_path):
    package = tmp_path / "example"
    package.mkdir()
    (package / "__init__.py").write_text("")
    entry = package / "entry.py"
    entry.write_text("from .provider import compute\n")
    provider = package / "provider.py"
    provider.write_text(
        'from . import premise\nraise RuntimeError("must not execute")\n'
    )
    premise = package / "premise.py"
    premise.write_text("VALUE = 1\n")
    unrelated = package / "unrelated.py"
    unrelated.write_text("VALUE = 9\n")
    result = _source_files({"entry": entry}, package)
    assert set(result.values()) == {entry, provider, premise, package / "__init__.py"}
    assert result["entry"] == entry
    before = {
        key: sha256(path.read_bytes()).hexdigest() for key, path in result.items()
    }
    premise.write_text("VALUE = 2\n")
    after = {
        key: sha256(path.read_bytes()).hexdigest()
        for key, path in _source_files({"entry": entry}, package).items()
    }
    assert after != before
    unrelated.write_text("VALUE = 10\n")
    assert after == {
        key: sha256(path.read_bytes()).hexdigest()
        for key, path in _source_files({"entry": entry}, package).items()
    }


def test_package_entrypoints_and_declared_data_are_retained(tmp_path):
    package = tmp_path / "example"
    package.mkdir()
    api = package / "__init__.py"
    api.write_text("from .implementation import compute\n")
    implementation = package / "implementation.py"
    implementation.write_text("def compute(): return 1\n")
    command = package / "__main__.py"
    command.write_text("from . import compute\n")
    data = tmp_path / "original-evidence.json"
    data.write_text('{"unchanged": true}')
    result = _source_files({"api": api, "evidence": data}, package)
    assert set(result.values()) == {api, implementation, command, data}
    assert result["evidence"] == data


def test_transitive_helpers_do_not_inherit_an_unused_command(tmp_path):
    package = tmp_path / "example"
    helper = package / "helpers"
    helper.mkdir(parents=True)
    (package / "__init__.py").write_text("")
    (helper / "__init__.py").write_text("")
    entry = package / "entry.py"
    entry.write_text("from .helpers.values import VALUE\n")
    (helper / "values.py").write_text("VALUE = 1\n")
    command = helper / "__main__.py"
    command.write_text('raise RuntimeError("unrelated command")\n')
    before = _source_files({"entry": entry}, package)
    assert command not in before.values()
    command.write_text('raise RuntimeError("still unrelated")\n')
    assert before == _source_files({"entry": entry}, package)
