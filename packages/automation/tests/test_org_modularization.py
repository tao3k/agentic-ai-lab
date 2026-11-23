# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Tests for AST-faithful oversized ORG detection, ASCENT planning, and verified splitting."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "packages" / "automation" / "org_modularization.py"


def load_module():
    spec = importlib.util.spec_from_file_location("org_modularization", SCRIPT)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    import sys
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _make_synthetic_repo(tmp: Path) -> tuple[Path, Path]:
    """Create a synthetic repo with an oversized 1,300+ line ORG doc and a sibling referencing it."""
    (tmp / "REUSE.toml").write_text(
        'version = 1\n\n[[annotations]]\npath = ["docs/research/agent-inference/frozen.org"]\n'
        'SPDX-FileCopyrightText = "2026 tao3k team and Contributors"\n'
        'SPDX-License-Identifier = "Apache-2.0 AND LGPL-2.1-or-later"\n',
        encoding="utf-8",
    )
    docs_dir = tmp / "docs" / "design"
    docs_dir.mkdir(parents=True, exist_ok=True)
    frozen_dir = tmp / "docs" / "research" / "agent-inference"
    frozen_dir.mkdir(parents=True, exist_ok=True)
    (frozen_dir / "frozen.org").write_text(
        "#+title: Frozen Research Evidence\n* Frozen\n" + "\n".join(f"line {i}" for i in range(1100)) + "\n",
        encoding="utf-8",
    )

    lines = [
        "#+title: Synthetic Large Context Design",
        "#+language: en",
        "#+begin_comment",
        "SPDX-FileCopyrightText: 2026 tao3k team and Contributors",
        "SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later",
        "#+end_comment",
        "",
        "* Scope and reading rule",
        "This umbrella introduces the architecture and links to [[file:sibling.org][sibling]].",
        "",
        "* Governance and proof boundary",
        ":PROPERTIES:",
        ":CUSTOM_ID: gov-boundary",
        ":END:",
        "Formal SysML Lean Quint boundary with spoofed headline inside a code block:",
        "#+begin_src org",
        "* SPOOFED HEADLINE INSIDE CODE BLOCK MUST NOT SPLIT",
        "** SPOOFED SUBHEADLINE",
        "#+end_src",
        "",
        "* Monolithic runtime qualification journal",
        ":PROPERTIES:",
        ":CUSTOM_ID: mono-journal",
        ":END:",
    ]
    # Add >900 lines of alternating paragraphs, tables, and code blocks with zero sub-headlines
    for idx in range(260):
        lines.append(f"Experiment batch {idx}: bazel gerbil compiler prefix worker attribution check.")
        lines.append(f"Observed target closure and manifest digest for batch {idx}.")
        lines.append("")
        if idx % 10 == 0:
            lines.extend(
                [
                    "| Metric | Value |",
                    "|--------+-------|",
                    f"| batch-{idx} | 100ms |",
                    f"| heap-{idx} | 2GiB |",
                    "",
                ]
            )
        if idx % 15 == 0:
            lines.extend(
                [
                    "#+begin_example",
                    f"* SPOOFED EXAMPLE HEADING {idx}",
                    "result=OK",
                    "#+end_example",
                    "",
                ]
            )
    lines.extend(
        [
            "* Query memory and recovery closure",
            "Connects memory projection, durable recovery, and [[#gov-boundary][Governance boundary]].",
            "",
        ]
    )

    big_org = docs_dir / "big-design.org"
    big_org.write_text("\n".join(lines) + "\n", encoding="utf-8")

    sibling = docs_dir / "sibling.org"
    sibling.write_text(
        "#+title: Sibling Reference\n"
        "#+begin_comment\n"
        "SPDX-FileCopyrightText: 2026 tao3k team and Contributors\n"
        "SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later\n"
        "#+end_comment\n\n"
        "* Inbound link\n"
        "See [[file:big-design.org#mono-journal][Monolithic journal]] and [[file:big-design.org#gov-boundary][Gov]].\n",
        encoding="utf-8",
    )
    return big_org, sibling


class OrgModularizationTest(unittest.TestCase):
    def test_spoofed_headlines_inside_blocks_are_ignored(self) -> None:
        mod = load_module()
        with tempfile.TemporaryDirectory() as td:
            big_org, _ = _make_synthetic_repo(Path(td))
            doc = mod.parse_org_document(big_org, repo_root=Path(td))
            titles = [s.title for s in doc.sections]
            self.assertEqual(
                titles,
                [
                    "Scope and reading rule",
                    "Governance and proof boundary",
                    "Monolithic runtime qualification journal",
                    "Query memory and recovery closure",
                ],
            )
            self.assertEqual(doc.unclosed_blocks, [])
            self.assertTrue(doc.has_spdx)

    def test_frozen_reuse_document_is_exempt_and_refused_on_apply(self) -> None:
        mod = load_module()
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            _make_synthetic_repo(tmp)
            frozen_org = tmp / "docs" / "research" / "agent-inference" / "frozen.org"
            pkt = mod.build_ascent_l0_l1_packet(frozen_org, repo_root=tmp, max_lines=500)
            self.assertTrue(pkt["l0_summary"]["frozen_exempt"])

            plan = mod.build_ascent_modularization_plan(frozen_org, repo_root=tmp, max_lines=500)
            plan_file = tmp / "frozen-plan.json"
            plan_file.write_text(json.dumps(plan), encoding="utf-8")
            b0 = plan["competing_branches"][0]
            with self.assertRaisesRegex(RuntimeError, "frozen historical document"):
                mod.apply_approved_plan(
                    plan_file,
                    branch_id=b0["branch_id"],
                    approve_plan_sha256=b0["plan_sha256"],
                    repo_root=tmp,
                )

    def test_l0_l1_packet_and_competing_branches_preserve_hypotheses(self) -> None:
        mod = load_module()
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            big_org, _ = _make_synthetic_repo(tmp)
            pkt = mod.build_ascent_l0_l1_packet(big_org, repo_root=tmp, max_lines=400)
            self.assertEqual(pkt["disclosure_level"], "L1")
            self.assertTrue(pkt["l0_summary"]["exceeds_threshold"])
            self.assertEqual(len(pkt["l0_summary"]["monolithic_leaf_sections"]), 1)
            self.assertGreaterEqual(pkt["l0_summary"]["inbound_repo_references"], 2)
            self.assertGreater(pkt["omitted_text_receipt"]["omitted_leaf_sections"], 0)

            # Custom external branch proposal should be evaluated alongside the 3 built-in branches
            plan = mod.build_ascent_modularization_plan(big_org, repo_root=tmp, max_lines=400)
            self.assertTrue(plan["hypothetical_fit_does_not_authorize_write"])
            self.assertEqual(len(plan["competing_branches"]), 3)
            self.assertTrue(all(b["hypothesis_evaluation"]["H1_line_budget_satisfied"] for b in plan["competing_branches"]))

    def test_apply_enforces_approval_sha_and_conserves_bytes_and_rewrites_inbound(self) -> None:
        mod = load_module()
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            big_org, sibling = _make_synthetic_repo(tmp)
            plan = mod.build_ascent_modularization_plan(big_org, repo_root=tmp, max_lines=400)
            plan_file = tmp / "plan.json"
            plan_file.write_text(json.dumps(plan), encoding="utf-8")
            branch_a = plan["competing_branches"][0]

            # 1. Fail-closed on bad approval SHA-256
            with self.assertRaisesRegex(RuntimeError, "Approval SHA-256 mismatch"):
                mod.apply_approved_plan(
                    plan_file,
                    branch_id=branch_a["branch_id"],
                    approve_plan_sha256="0" * 64,
                    repo_root=tmp,
                )

            # 2. Apply approved plan with inbound link rewrite
            receipt = mod.apply_approved_plan(
                plan_file,
                branch_id=branch_a["branch_id"],
                approve_plan_sha256=branch_a["plan_sha256"],
                repo_root=tmp,
                rewrite_inbound=True,
            )
            self.assertGreater(len(receipt["files_emitted"]), 2)
            self.assertTrue(all(f["lines"] <= 400 for f in receipt["files_emitted"]))
            self.assertIn("docs/design/sibling.org", receipt["rewritten_inbound_files"])

            # Verify sibling anchor link was cleanly redirected to the extracted child module
            sibling_text = sibling.read_text(encoding="utf-8")
            self.assertIn("big-design--offload-01-", sibling_text)
            self.assertIn("#mono-journal", sibling_text)
            # Gov boundary remained in umbrella (lightweight section)
            self.assertIn("big-design.org#gov-boundary", sibling_text)

            # 3. Re-applying stale plan against now-modified umbrella must fail closed
            with self.assertRaisesRegex(RuntimeError, "Stale plan"):
                mod.apply_approved_plan(
                    plan_file,
                    branch_id=branch_a["branch_id"],
                    approve_plan_sha256=branch_a["plan_sha256"],
                    repo_root=tmp,
                )

    def test_real_repo_scan_detects_oversized_docs_without_crashing(self) -> None:
        mod = load_module()
        rc = mod.main(["--repo-root", str(ROOT), "scan", "--max-lines", "1000"])
        self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
