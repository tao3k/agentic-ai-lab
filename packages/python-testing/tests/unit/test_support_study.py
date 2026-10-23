# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""No paid calls: check isolation of feedback and execution scoring."""

from types import SimpleNamespace

from agentic_ai_lab_testing.model_study import support
from agentic_ai_lab_testing.model_study.support_native import score
from agentic_ai_lab_testing.model_study.support_protocol import SELF_REVIEW, NATIVE_REVIEW

REFERENCE = "\n".join([
    "0\tcomplete\t((0 20))\tvalid\tvalid\ttask-shape\t()",
    "1\tcomplete\t((0 20))\tvalid\tvalid\ttask-shape\t()",
    "2\tcomplete\t((0 8))\tvalid\tvalid\ttask-shape\t()",
    "3\tcomplete\t((0 12))\tvalid\tvalid\ttask-shape\t()",
    "stale\tcomplete\t((0 20))\tinvalid\tinvalid\ttask-shape\t()", "END", "",
])


def test_paired_calls_hold_out_update_states_and_preserve_raw_requests(tmp_path, monkeypatch):
    calls, modes = [], []
    text = "(candidate (relation summary 2) (query summary ?r ?n) (limits 16 64 128))"

    def create(**kwargs):
        calls.append(kwargs)
        return SimpleNamespace(status="completed", output_text=text,
                               model_dump=lambda **_: {"status": "completed", "output_text": text})

    def observe(_root, _path, _proposal, initial=False):
        modes.append(initial)
        return REFERENCE.splitlines()[0] + "\nEND\n" if initial else REFERENCE

    monkeypatch.setattr(support, "observe", observe)
    files = {"initial.txt": "same source and task", "self_review.txt": SELF_REVIEW,
             "native_review.txt": NATIVE_REVIEW, "reference.tsv": REFERENCE}
    result = support.run(SimpleNamespace(responses=SimpleNamespace(create=create)),
                         files, tmp_path, tmp_path, tmp_path)
    assert len(calls) == 4 and modes == [False, True, False]
    assert calls[0]["input"] == calls[2]["input"]
    assert "((0 20))" not in calls[1]["input"][-1]["content"]
    feedback = calls[3]["input"][-1]["content"]
    assert "((0 20))" in feedback and "((0 8))" not in feedback
    assert all(value["correct"] for value in result.values())
    assert (tmp_path / "self.1.json").exists() and (tmp_path / "native.2.txt").read_text() == text


def test_native_validity_does_not_make_wrong_task_results_correct():
    wrong = REFERENCE.replace("2\tcomplete\t((0 8))", "2\tcomplete\t((0 20))")
    result = score(wrong, REFERENCE)
    assert result["matched_states"] == [True, True, False, True]
    assert result["stale_invalid"] is True and result["correct"] is False
    assert result["stale_applicable"] is True
    assert result["states"][2] == {"generation": "2", "complete": True,
                                   "finite_valid": True, "founded_valid": True,
                                   "task_shape": True, "output_matches": False}
    assert score(REFERENCE.replace("task-shape", "outside-task-shape"), REFERENCE)["correct"] is False
    unsafe = SimpleNamespace(status="completed", output_text="(candidate (query summary ?r ?n)) (evil)")
    assert support.inert_output(unsafe) is None
    partial = SimpleNamespace(status="incomplete", output_text="(candidate (query summary ?r ?n))")
    assert support.inert_output(partial) is None


def test_preview_rejects_modified_bytes_before_live_calls(tmp_path, monkeypatch):
    import pytest
    from agentic_ai_lab_testing.model_study import support_protocol as protocol

    ascent, poo, directory = tmp_path / "ascent", tmp_path / "poo", tmp_path / "preview"
    ascent.mkdir()
    poo.mkdir()
    for name in protocol.SOURCES:
        target = ascent / name
        target.parent.mkdir(exist_ok=True)
        target.write_text("source module\n")
    monkeypatch.setattr(protocol, "require_clean", lambda _: None)
    monkeypatch.setattr(protocol, "require_pinned_ascent", lambda *_: None)
    monkeypatch.setattr(protocol, "source_head", lambda _: "a" * 40)
    monkeypatch.setattr(protocol, "observe", lambda *_: REFERENCE)
    protocol.preview(directory, ascent, poo, tmp_path)
    assert protocol.validate(directory, ascent, poo)["reference.tsv"] == REFERENCE
    (directory / "self_review.txt").write_text("replacement instruction")
    with pytest.raises(RuntimeError, match="preview bytes"):
        protocol.validate(directory, ascent, poo)


def test_rejected_receipt_cannot_test_generation_binding():
    rejected = REFERENCE.replace("\tcomplete\t", "\trejected\t").replace(
        "\tvalid\tvalid\t", "\tinvalid\tinvalid\t")
    result = score(rejected, REFERENCE)
    assert result["stale_invalid"] is True
    assert result["stale_applicable"] is False and result["correct"] is False
