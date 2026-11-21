# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Study protocol output retains its live stream, terminator and flush policy."""

from io import StringIO
from unittest.mock import Mock

from agentic_ai_lab_testing.model_study.reporting import report_text


def test_reporting_preserves_record_values_and_custom_terminator():
    stream = StringIO()
    report_text("CASE-OK", 3, {"valid": True}, end="", file=stream)
    assert stream.getvalue() == "CASE-OK 3 {'valid': True}"


def test_reporting_uses_the_current_stdout(monkeypatch):
    stream = StringIO()
    monkeypatch.setattr("sys.stdout", stream)
    report_text("proof", "support")
    assert stream.getvalue() == "proof support\n"


def test_reporting_honors_explicit_stream_and_flush():
    stream = Mock()
    report_text("journal", file=stream, flush=True)
    stream.write.assert_called_once_with("journal\n")
    stream.flush.assert_called_once_with()


def test_reporting_does_not_add_an_unrequested_flush():
    stream = Mock()
    report_text(file=stream)
    stream.write.assert_called_once_with("\n")
    stream.flush.assert_not_called()
