# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Changes during verification must prevent publication of a proof receipt."""
from contextlib import nullcontext
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace

import pytest

from agentic_ai_lab_testing import CaseEvidence
from agentic_ai_lab_testing.checks import quint
from agentic_ai_lab_testing.checks.quint_cases import QuintCase


@pytest.mark.parametrize("change", ["unchanged", "added", "modified", "deleted"])
def test_model_source_cut_controls_receipt_publication(monkeypatch, change):
    root = Path(quint.__file__).resolve().parents[5]
    with tempfile.TemporaryDirectory(prefix="quint-admission-", dir=root / ".gerbil") as directory:
        models = Path(directory)
        source = models / "Control.qnt"
        source.write_text("module Control {}\n")
        receipt = models / "proof.ss"
        case = QuintCase("Control", source_directory=str(models.relative_to(root)))
        monkeypatch.setattr(quint, "GROUPS", {"control": [case]})
        monkeypatch.setattr(sys, "argv", ["quint", "--receipt", str(receipt)])
        monkeypatch.setattr(quint, "_load_backend", lambda root: SimpleNamespace(
            __file__=str(root / "core/dev/proofs/quint/backend.py"),
            backend_session=lambda _progress, _quint: nullcontext("localhost:0")))

        def verifier(*_):
            if change == "added":
                (models / "Added.qnt").write_text("module Added {}\n")
            elif change == "modified":
                source.write_text("module Control { val changed = true }\n")
            elif change == "deleted":
                source.unlink()
            return CaseEvidence({"exit": 0})

        monkeypatch.setattr(quint, "check_quint", verifier)
        if change == "unchanged":
            assert quint.main() == 0
            assert '"agentic-ai-lab.quint-proof.v1"' in receipt.read_text()
        else:
            with pytest.raises(AssertionError, match="changed during qualification"):
                quint.main()
            assert not receipt.exists()
