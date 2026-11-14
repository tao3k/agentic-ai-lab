# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from functools import wraps
import hashlib
import logging
import os
from pathlib import Path
import pytest
from agentic_ai_lab_runtime.semantic_runtime import SemanticRuntime, SemanticRuntimeError

@pytest.fixture(scope='session')
def runtime():
    configured = os.environ.get('AGENTIC_AI_LAB_SEMANTIC_LIBRARY')
    if not configured:
        pytest.skip('semantic AOT artifact must be explicitly configured')
    path = Path(configured)
    with SemanticRuntime(path, expected_digest=hashlib.sha256(path.read_bytes()).hexdigest()) as value:
        yield value
    with pytest.raises(SemanticRuntimeError, match='closed'):
        value.call('descriptor', {})
    value.close()
    result = value._ffi.new('agentic_ai_lab_semantic_result *')
    assert value._lib.agentic_ai_lab_python_semantic_call(b'descriptor', b'{}', 2, result) == 1
    assert value._lib.agentic_ai_lab_python_semantic_open(str(path).encode()) == 1




def pytest_configure(config):
    """Report completed parser work without changing the harness result or rules."""
    if os.environ.get('AGENTIC_AI_LAB_TEST_PROGRESS') != '1':
        return
    from python_lang_project_harness import _runner
    original = _runner.parse_python_file

    @wraps(original)
    def observed(path):
        report = original(path)
        logging.getLogger(__name__).info('PYTHON-HARNESS-PARSED %s', path)
        return report

    def restore():
        _runner.parse_python_file = original

    _runner.parse_python_file = observed
    config.add_cleanup(restore)
