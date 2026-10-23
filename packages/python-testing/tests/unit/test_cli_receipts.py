# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""A failed native case must remain failed in the machine-readable receipt."""

from __future__ import annotations

import json

from agentic_ai_lab_testing import CaseEvidence, CaseRegistry, CaseSpec, ModulePart
from agentic_ai_lab_testing import cli


def test_receipt_preserves_pass_and_failure(tmp_path, monkeypatch) -> None:
    catalog = CaseRegistry()
    catalog.register(CaseSpec("fixture.pass", (ModulePart("session", "proof/pass"),),
                              "native"), lambda _context: CaseEvidence({"exit": 0}))

    def fail(_context):
        raise AssertionError("wrong invariant")

    catalog.register(CaseSpec("fixture.fail", (ModulePart("session", "proof/fail"),),
                              "native"), fail)
    monkeypatch.setattr(cli, "build_catalog", lambda: catalog)
    receipt = tmp_path / "results.json"

    status = cli.main(["run", "--repo-root", str(tmp_path), "--mode", "native",
                       "--module", "session", "--receipt", str(receipt)])

    assert status == 1
    document = json.loads(receipt.read_text())
    assert document["schema"] == "agentic-ai-lab.testing-cases.v1"
    assert document["source_revision"] is None
    assert document["working_tree_dirty"] is None
    assert [(result["identity"], result["status"]) for result in document["results"]] == [
        ("fixture.pass", "PASS"), ("fixture.fail", "FAIL")]
    assert document["results"][0]["evidence"] == {"exit": 0}
    assert document["results"][1]["error"] == "wrong invariant"
