# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from types import SimpleNamespace

import pytest
from agentic_ai_lab_testing.model_study import archive
from agentic_ai_lab_testing.model_study import shared_repair as repair
from agentic_ai_lab_testing.model_study.support_native import score

REFERENCE = '\n'.join([
    *(f'{g}\tcomplete\t((0 {n}))\tvalid\tvalid\ttask-shape\t()'
      for g, n in enumerate((20, 20, 8, 12, 8, 12, 8))),
    'stale\tcomplete\t((0 20))\tinvalid\tinvalid\ttask-shape\t()', 'END', '',
])


def test_repairs_share_seed_and_hold_out_semantic_discriminators(tmp_path, monkeypatch):
    calls = []
    text = '(candidate (query summary ?r ?n) (limits 16 64 128))'
    def create(**kwargs):
        calls.append(kwargs['input'])
        return SimpleNamespace(status='completed', output_text=text,
                               model_dump=lambda **_: {'status': 'completed', 'output_text': text})
    monkeypatch.setattr(repair, 'observe', lambda *_args, **kwargs: REFERENCE)
    files = {'reference.tsv': REFERENCE}
    for task in repair.TASKS:
        common = f'contract; task; shared {task} seed'
        files[f'{task}.self.txt'] = common + '\n' + repair.SELF
        files[f'{task}.native.txt'] = common + '\n' + repair.NATIVE.format(observation='invalid-form (clause 8 body 3)')
    result = repair.run(SimpleNamespace(responses=SimpleNamespace(create=create)),
                        files, tmp_path, tmp_path, tmp_path)
    assert len(calls) == 4 and all(value['correct'] for value in result.values())
    assert [item[0]['content'].split('\n')[0] for item in calls] == [
        'contract; task; shared compute seed', 'contract; task; shared compute seed',
        'contract; task; shared filter seed', 'contract; task; shared filter seed']
    assert all('((0 12))' not in item[0]['content'] for item in calls)
    assert [name for name in result] == ['compute.self', 'compute.native', 'filter.native', 'filter.self']


def test_seven_state_score_detects_guard_and_blocked_failures():
    wrong = REFERENCE.replace('4\tcomplete\t((0 8))', '4\tcomplete\t((0 20))')
    result = score(wrong, REFERENCE, state_count=7)
    assert len(result['states']) == 7 and not result['correct']
    assert result['states'][4]['finite_valid'] and not result['states'][4]['output_matches']


def test_archive_verifies_bytes_and_preserves_failed_run(tmp_path, monkeypatch):
    preview, result, destination = (tmp_path / name for name in ('preview', 'result', 'archive'))
    preview.mkdir(); result.mkdir()
    (preview / 'manifest.json').write_text('{"approved": true}')
    (result / 'error.json').write_text('{"error_type": "TimeoutError"}')
    monkeypatch.setattr(archive, 'require_durable', lambda _: None)
    manifest = archive.seal(preview, result, destination, outcome='failed')
    assert manifest['outcome'] == 'failed' and archive.verify(destination) == manifest
    (destination / 'results/error.json').write_text('changed')
    with pytest.raises(RuntimeError, match='hashes changed'):
        archive.verify(destination)


def test_temporary_archive_is_rejected_before_calls(tmp_path):
    with pytest.raises(ValueError, match='temporary directories'):
        archive.require_durable(tmp_path / 'raw')


def test_repair_preview_rejects_modified_prompt_before_any_call(tmp_path, monkeypatch):
    import json
    ascent, poo, directory = (tmp_path / name for name in ('ascent', 'poo', 'preview'))
    for path in (ascent, poo, directory):
        path.mkdir()
    files = {name: b'frozen' for name in repair.names()}
    files['reference.tsv'] = REFERENCE.encode()
    monkeypatch.setattr(repair, 'require_clean', lambda _: None)
    monkeypatch.setattr(repair, 'require_pinned_ascent', lambda *_: None)
    monkeypatch.setattr(repair, 'source_head', lambda _: 'a' * 40)
    for name, raw in files.items():
        (directory / name).write_bytes(raw)
    (directory / 'manifest.json').write_text(json.dumps(repair.metadata(ascent, poo, files)))
    assert repair.validate(directory, ascent, poo)['reference.tsv'] == REFERENCE
    (directory / 'compute.native.txt').write_text('replacement prompt')
    with pytest.raises(RuntimeError, match='preview bytes'):
        repair.validate(directory, ascent, poo)


def test_archive_cannot_be_nested_in_inputs(tmp_path, monkeypatch):
    monkeypatch.setattr(archive, 'require_durable', lambda _: None)
    with pytest.raises(ValueError, match='outside evidence inputs'):
        archive.require_archive(tmp_path / 'result/archive', tmp_path / 'preview', tmp_path / 'result')
    with pytest.raises(ValueError, match='outside evidence inputs'):
        archive.require_archive(tmp_path / 'archive', tmp_path / 'preview', tmp_path / 'archive/result')
