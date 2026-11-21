# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Exercise content deadlines, frozen request boundaries and literal configuration."""
import asyncio
import json

import pytest

from agentic_ai_lab_testing.model_study.semantic_config import configuration
from agentic_ai_lab_testing.model_study.semantic_provider import ContentTimeout, consume_lines


def line(kind, **fields):
    return 'data: ' + json.dumps(dict(type=kind, **fields))


def test_metadata_and_reasoning_cannot_keep_a_content_stall_alive():
    async def lines():
        while True:
            await asyncio.sleep(0.002)
            yield line('response.reasoning_text.delta', delta='private reasoning')
    record = {}
    with pytest.raises(ContentTimeout):
        asyncio.run(consume_lines(lines(), record, idle_seconds=0.02))
    assert record['raw'] == ''
    assert record['events']
    assert 'private reasoning' not in json.dumps(record)


def test_stalled_content_after_first_delta_fails_without_repair():
    async def lines():
        yield line('response.output_text.delta', delta='(object ("status" ')
        await asyncio.sleep(0.1)
    record = {}
    with pytest.raises(ContentTimeout):
        asyncio.run(consume_lines(lines(), record, idle_seconds=0.02))
    assert record['raw'] == '(object ("status" '


def test_whitespace_content_cannot_reset_the_watchdog():
    async def lines():
        while True:
            await asyncio.sleep(0.002)
            yield line('response.output_text.delta', delta=' ')
    with pytest.raises(ContentTimeout):
        asyncio.run(consume_lines(lines(), {}, idle_seconds=0.02))


def test_terminal_completion_and_genuine_content_are_both_required():
    async def lines():
        yield line('response.output_text.delta', delta='(object ("status" "complete") ("rows" (list)))')
        yield line('response.completed', response={'id': 'test', 'status': 'completed'})
    record = {}
    assert asyncio.run(consume_lines(lines(), record)).startswith('(object')
    assert record['responseId'] == 'test'
    assert len(record['contentGapsSeconds']) == 1


def test_incomplete_output_cannot_be_credited_as_acceptance():
    async def lines():
        yield line('response.output_text.delta', delta='(object)')
        yield line('response.incomplete', response={'status': 'incomplete'})
    with pytest.raises(RuntimeError, match='complete content'):
        asyncio.run(consume_lines(lines(), {}))


def test_configuration_reads_literals_without_executing_shell(tmp_path):
    path = tmp_path/'env'
    path.write_text('export DEEPSEEK_API_KEY="literal-key"\nANTHROPIC_MODEL=deepseek-v4-flash\nUNRELATED=$(touch unsafe)\n')
    assert configuration(path) == {'DEEPSEEK_API_KEY': 'literal-key', 'ANTHROPIC_MODEL': 'deepseek-v4-flash'}

