# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Bind native completion to the requested file and retain refusal controls."""

from subprocess import CompletedProcess
from unittest.mock import patch

import pytest

from agentic_ai_lab_testing.checks.evidence import evidence_assessment
from agentic_ai_lab_testing.model import CaseContext


@pytest.mark.parametrize("form", ["relative", "absolute", "normalized"])
def test_completion_accepts_the_same_source_identity(tmp_path, form):
    relative = "t/evidence-assessment-core-test.ss"
    paths = {"relative": relative, "absolute": str(tmp_path / relative),
             "normalized": str(tmp_path / "t/../t/evidence-assessment-core-test.ss")}
    output = f"MODULE-OK {paths[form]}\nHARNESS-OK\nOK\n"
    with patch("agentic_ai_lab_testing.checks.evidence.subprocess.run",
               return_value=CompletedProcess([], 0, output)) as run:
        evidence_assessment(CaseContext(tmp_path, {}))
    assert run.call_args.args[0] == ["just", "test-file", relative]
    assert run.call_args.kwargs["timeout"] == 150


@pytest.mark.parametrize("path", ["other/evidence-assessment-core-test.ss",
                                 "t/evidence-assessment-core-test.ss.extra", ""])
def test_completion_rejects_a_different_or_missing_module(tmp_path, path):
    output = f"MODULE-OK {path}\nHARNESS-OK\nOK\n"
    with patch("agentic_ai_lab_testing.checks.evidence.subprocess.run",
               return_value=CompletedProcess([], 0, output)):
        with pytest.raises(AssertionError, match="did not complete"):
            evidence_assessment(CaseContext(tmp_path, {}))


@pytest.mark.parametrize("error", ["ERROR CASE", "ERROR CHECK", "ERROR MODULE",
                                  "ERROR HARNESS", "Heap overflow", "Stack overflow"])
def test_completion_refuses_errors_even_after_success_markers(tmp_path, error):
    output = f"MODULE-OK t/evidence-assessment-core-test.ss\nHARNESS-OK\nOK\n{error}\n"
    with patch("agentic_ai_lab_testing.checks.evidence.subprocess.run",
               return_value=CompletedProcess([], 0, output)):
        with pytest.raises(AssertionError, match="error marker"):
            evidence_assessment(CaseContext(tmp_path, {}))


@pytest.mark.parametrize("missing", ["HARNESS-OK\n", "OK\n"])
def test_completion_requires_both_harness_and_final_success(tmp_path, missing):
    output = "MODULE-OK t/evidence-assessment-core-test.ss\nHARNESS-OK\nOK\n"
    # Remove an entire line; removing 'OK' as a substring would corrupt all markers.
    output = "\n".join(line for line in output.split("\n") if line != missing.strip())
    with patch("agentic_ai_lab_testing.checks.evidence.subprocess.run",
               return_value=CompletedProcess([], 0, output)):
        with pytest.raises(AssertionError, match="did not complete"):
            evidence_assessment(CaseContext(tmp_path, {}))


def test_nonzero_exit_cannot_be_promoted_by_success_markers(tmp_path):
    output = "MODULE-OK t/evidence-assessment-core-test.ss\nHARNESS-OK\nOK\n"
    with patch("agentic_ai_lab_testing.checks.evidence.subprocess.run",
               return_value=CompletedProcess([], 70, output)):
        with pytest.raises(AssertionError, match="exit=70"):
            evidence_assessment(CaseContext(tmp_path, {}))
