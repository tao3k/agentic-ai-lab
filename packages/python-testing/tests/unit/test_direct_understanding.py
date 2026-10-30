# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import pytest
import json
from types import SimpleNamespace
from agentic_ai_lab_testing.model_study.direct.tasks import finite_rows
from agentic_ai_lab_testing.model_study.direct.live import live
from agentic_ai_lab_testing.model_study.direct.live import _provider_response
from agentic_ai_lab_testing.model_study.direct.native import score_candidate


def test_independent_closure_oracle_handles_cycles_and_positive_length_paths():
    assert finite_rows('closure', [(1, 2), (2, 1), (2, 3)]) == [
        (1, 1), (1, 2), (1, 3), (2, 1), (2, 2), (2, 3)]
    assert finite_rows('join', [(1, 2), (2, 1), (2, 3)]) == [(1, 1), (1, 3), (2, 2)]
    assert finite_rows('closure', []) == []


def test_unapproved_new_batch_stops_before_output_or_provider_import(tmp_path):
    preview = tmp_path / 'preview'; preview.mkdir()
    (preview/'plan.json').write_text('{}')
    output = tmp_path / 'unused'
    with pytest.raises(ValueError, match='approval'):
        live(tmp_path, preview, output, None)
    assert not output.exists()


@pytest.mark.parametrize('candidate', ['#.(system "unsafe")', '('*65+')'*65])
def test_candidate_reader_extensions_stop_before_native_loading(tmp_path, candidate):
    output = tmp_path / 'guard'
    observation = score_candidate(tmp_path, tmp_path/'absent-expected',
                                  candidate, output)
    assert not observation['correct']
    assert observation['transportRejected']
    assert not (output/'native-score.log').exists()


@pytest.mark.parametrize('completed', [True, False])
def test_provider_stream_retains_raw_events_and_requires_a_terminal_record(tmp_path, completed):
    def event(kind, **fields):
        return SimpleNamespace(type=kind, **fields,
            model_dump_json=lambda: json.dumps({'type': kind, 'delta': fields.get('delta')}))
    events = [event('response.reasoning_text.delta', delta='offline fixture'),
              event('response.output_text.delta', delta='((11 13))')]
    response = SimpleNamespace(model_dump_json=lambda **options: '{"id":"offline-test"}')
    if completed:
        events.append(event('response.completed', response=response))
    client = SimpleNamespace(responses=SimpleNamespace(create=lambda **request: iter(events)))
    path = tmp_path/'response.json'
    if completed:
        raw, terminal, reasoning, elapsed = _provider_response(client, {}, path)
        assert raw == '((11 13))' and terminal is response and reasoning == 1
        assert json.loads(path.read_text())['id'] == 'offline-test'
    else:
        with pytest.raises(RuntimeError, match='terminal'):
            _provider_response(client, {}, path)
        assert not path.exists()
    archived = [json.loads(line) for line in path.with_suffix('.events.jsonl').read_text().splitlines()]
    assert archived[1]['delta'] == '((11 13))'


def test_native_computation_has_no_interactive_stdin(tmp_path):
    import sys
    from agentic_ai_lab_testing.model_study.direct.native import native_run
    script = "import sys; assert sys.stdin.read() == ''; print('MODULE-OK noninteractive'); print('HARNESS-OK noninteractive'); print('OK')"
    assert 'HARNESS-OK noninteractive' in native_run(
        tmp_path, [sys.executable, '-c', script], tmp_path/'native.log')


def test_history_control_differs_only_by_current_native_observation(tmp_path):
    from agentic_ai_lab_testing.model_study.direct.live import _request
    source = "(def implementation 'source)\n(import :std/test :gerbil-ascent/program/scheme-language)\n(def task 'transfer)"
    (tmp_path/'join-transfer.input.ss').write_text(source)
    (tmp_path/'join-initial.input.ss').write_text(source.replace('transfer', 'initial'))
    plan = {'model': 'offline', 'maxInputBytes': 10000, 'maxOutputTokens': 128}
    item = {'case': 'join-transfer', 'family': 'join', 'reasoningEffort': 'high'}
    initial = {'join': {'raw': '(quote ())', 'observation': {'correct': False, 'witness': 'native fixture'}}}
    history = _request(plan, tmp_path, dict(item, arm='transfer-history'), initial)
    feedback = _request(plan, tmp_path, dict(item, arm='transfer-feedback'), initial)
    assert history['input'][:2] == feedback['input'][:2]
    assert feedback['input'][2]['content'] == json.dumps(initial['join']['observation'], sort_keys=True)+'\n'+history['input'][2]['content']
    assert history['reasoning'] == feedback['reasoning']
