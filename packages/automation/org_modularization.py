#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""AST-faithful oversized ORG detector, L0/L1 ASCENT planner, and verified splitter.

Bridges deterministic Python ORG Element AST parsing (Slices 35, 45, 48) with
ASCENT-compatible competing-hypothesis modularization planning (Slice 43).

Design invariants:
- Never treat spoofed `* Heading` lines inside `#+begin_* ... #+end_*` blocks
  as structural ORG headlines.
- Never split inside a code/example/comment/quote block, property drawer, or
  ORG table.
- Respect `REUSE.toml` frozen historical paths and `t/qualification/` evidence
  bindings; frozen documents are reported as exempt and refused on apply.
- Competing modularization branches are evaluated side-by-side without reducing
  them to a single hard-coded winner or letting hypothetical fit authorize
  file writes.
- Physical splitting requires an explicit approved plan SHA-256 and passes a
  post-split verification gate (AST re-parse, 100% verbatim line conservation,
  SPDX header coverage, and zero broken relative `[[file:...]]` links).
"""

from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass, field
import fnmatch
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tomllib
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SPDX_COPYRIGHT = "SPDX-FileCopyrightText: 2026 tao3k team and Contributors"
SPDX_LICENSE = "SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later"
DEFAULT_MAX_LINES = 1000
DEFAULT_WINDOW_TARGET_LINES = 220

HEADLINE_RE = re.compile(r"^(\*+)\s+(.*)$")
BEGIN_BLOCK_RE = re.compile(r"^\s*#\+begin_([a-z0-9_-]+)\b", re.I)
END_BLOCK_RE = re.compile(r"^\s*#\+end_([a-z0-9_-]+)\b", re.I)
FILE_LINK_RE = re.compile(r"\[\[file:([^\]#:]+)(?:::([^\]]+)|#([^\]]+))?\]")
INTERNAL_LINK_RE = re.compile(r"\[\[(?:#([^\]\[]+)|\*([^\]\[]+))\]")
TARGET_RE = re.compile(r"<<([^<>]+)>>")
PROPERTY_ANCHOR_RE = re.compile(r"^\s*:(?:CUSTOM_ID|ID):\s+(\S+)\s*$", re.I)
DRAWER_BEGIN_RE = re.compile(r"^\s*:([A-Z0-9_-]+):\s*$")
DRAWER_END_RE = re.compile(r"^\s*:END:\s*$", re.I)
KEYWORD_RE = re.compile(r"^#\+([a-z0-9_-]+):\s*(.*)$", re.I)
TOKEN_RE = re.compile(r"\b[a-z][a-z0-9_-]{3,}\b")

STOPWORDS = {
    "that", "this", "with", "from", "have", "were", "when", "they", "them",
    "into", "only", "also", "then", "than", "each", "same", "does", "must",
    "will", "been", "more", "some", "such", "only", "still", "after", "before",
    "first", "second", "third", "other", "their", "there", "these", "those",
    "without", "within", "through", "between", "against", "under", "over",
    "about", "where", "which", "while", "should", "could", "would", "because",
    "remains", "remain", "retains", "retain", "using", "used", "uses", "make",
    "made", "runs", "running", "file", "files", "line", "lines", "path",
    "paths", "true", "false", "none", "both", "case", "cases", "step", "steps",
}

DOMAIN_SIGNATURES: dict[str, tuple[str, ...]] = {
    "governance-and-proof": (
        "governance", "sysml", "lean", "quint", "apalache", "tlc", "declassification",
        "taint", "cedar", "sandbox", "trifecta", "defeater", "omission", "closure",
        "theorem", "invariant", "taxonomy", "ascent", "epistemic", "disclosure",
    ),
    "build-and-runtime-attribution": (
        "bazel", "gerbil", "gambit", "yuanxu", "compile", "compiler", "prefix",
        "worker", "workers", "heap", "dlclose", "signal", "process", "exit",
        "build", "make", "target", "targets", "manifest", "cache", "sandbox",
    ),
    "query-memory-and-recovery": (
        "memory", "query", "gql", "orgize", "durable", "recovery", "checkpoint",
        "session", "worktree", "temporal", "watermark", "invalidation", "anchor",
        "contract", "context", "projection", "module", "modules", "store",
    ),
}


@dataclass(frozen=True)
class AtomicBlock:
    """An indivisible ORG element span (paragraph, table, block, or drawer)."""

    block_id: str
    kind: str
    start_line: int
    end_line: int
    anchors: tuple[str, ...] = ()
    outbound_links: tuple[str, ...] = ()

    @property
    def line_count(self) -> int:
        return self.end_line - self.start_line + 1


@dataclass
class OrgSection:
    """One AST headline node with exact 1-based inclusive line bounds."""

    section_id: str
    level: int
    title: str
    start_line: int
    end_line: int
    parent_id: str | None = None
    children: list[str] = field(default_factory=list)
    anchors: list[str] = field(default_factory=list)
    outbound_file_links: list[dict[str, str | None]] = field(default_factory=list)
    internal_refs: list[str] = field(default_factory=list)
    code_block_lines: int = 0
    table_lines: int = 0
    top_terms: list[str] = field(default_factory=list)
    blocks: list[AtomicBlock] = field(default_factory=list)

    @property
    def line_count(self) -> int:
        return self.end_line - self.start_line + 1


@dataclass
class OrgDocument:
    """Parsed ORG AST preserving exact source bytes and line indices."""

    path: Path
    rel_path: str
    sha256: str
    total_lines: int
    total_bytes: int
    title: str
    has_spdx: bool
    preamble_end_line: int
    unclosed_blocks: list[str]
    lines: list[str]
    sections: list[OrgSection]
    top_level_ids: list[str]
    file_links: list[dict[str, Any]]
    anchors: dict[str, str]  # anchor -> section_id


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def slugify(text: str, max_len: int = 44) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    if not slug:
        return "section"
    if len(slug) <= max_len:
        return slug
    cut = slug[:max_len]
    if "-" in cut and slug[max_len] != "-":
        cut = cut.rsplit("-", 1)[0]
    return cut.rstrip("-") or slug[:max_len].rstrip("-")


def load_frozen_reuse_patterns(repo_root: Path = ROOT) -> tuple[str, ...]:
    """Extract frozen/preserved byte-exact path patterns from REUSE.toml."""
    reuse_path = repo_root / "REUSE.toml"
    if not reuse_path.is_file():
        return ()
    raw_text = reuse_path.read_text(encoding="utf-8")
    payload = tomllib.loads(raw_text)
    frozen: list[str] = []
    for annotation in payload.get("annotations", []):
        paths = annotation.get("path", [])
        if isinstance(paths, str):
            paths = [paths]
        for pat in paths:
            if isinstance(pat, str) and (
                pat.startswith("docs/research/agent-inference/")
                or pat.startswith("t/qualification/")
            ):
                frozen.append(pat)
    return tuple(frozen)


def is_frozen_path(rel_path: str, frozen_patterns: tuple[str, ...]) -> bool:
    if rel_path.startswith("t/qualification/"):
        return True
    return any(fnmatch.fnmatch(rel_path, pat) for pat in frozen_patterns)


def _extract_top_terms(lines: list[str], limit: int = 8) -> list[str]:
    counts: Counter[str] = Counter()
    in_block = False
    for line in lines:
        s = line.strip()
        if BEGIN_BLOCK_RE.match(s):
            in_block = True
            continue
        if END_BLOCK_RE.match(s):
            in_block = False
            continue
        if in_block:
            continue
        for tok in TOKEN_RE.findall(line.lower()):
            if tok not in STOPWORDS:
                counts[tok] += 1
    return [term for term, _ in counts.most_common(limit)]


def _parse_atomic_blocks(lines: list[str], start_line: int, end_line: int, prefix: str) -> list[AtomicBlock]:
    """Segment a line range [start_line, end_line] (1-based) into indivisible ORG blocks."""
    blocks: list[AtomicBlock] = []
    i = start_line
    idx = 0

    def add_block(kind: str, b_start: int, b_end: int) -> None:
        nonlocal idx
        idx += 1
        seg = lines[b_start - 1 : b_end]
        anchors: list[str] = []
        out_links: list[str] = []
        for ln in seg:
            for m in TARGET_RE.finditer(ln):
                anchors.append(m.group(1).strip())
            am = PROPERTY_ANCHOR_RE.match(ln)
            if am:
                anchors.append(am.group(1).strip())
            for lm in FILE_LINK_RE.finditer(ln):
                out_links.append(lm.group(1))
        blocks.append(
            AtomicBlock(
                block_id=f"{prefix}.b{idx:03d}",
                kind=kind,
                start_line=b_start,
                end_line=b_end,
                anchors=tuple(dict.fromkeys(anchors)),
                outbound_links=tuple(dict.fromkeys(out_links)),
            )
        )

    while i <= end_line:
        line = lines[i - 1]
        stripped = line.strip()
        if not stripped:
            i += 1
            continue

        bm = BEGIN_BLOCK_RE.match(line)
        if bm:
            btype = bm.group(1).lower()
            b_start = i
            i += 1
            while i <= end_line:
                em = END_BLOCK_RE.match(lines[i - 1])
                if em and em.group(1).lower() == btype:
                    i += 1
                    break
                i += 1
            add_block(f"block:{btype}", b_start, min(i - 1, end_line))
            continue

        if stripped.upper() == ":PROPERTIES:" or (DRAWER_BEGIN_RE.match(line) and not DRAWER_END_RE.match(line)):
            b_start = i
            i += 1
            while i <= end_line:
                if DRAWER_END_RE.match(lines[i - 1]):
                    i += 1
                    break
                i += 1
            add_block("drawer", b_start, min(i - 1, end_line))
            continue

        if stripped.startswith("|"):
            b_start = i
            i += 1
            while i <= end_line and lines[i - 1].strip().startswith("|"):
                i += 1
            add_block("table", b_start, i - 1)
            continue

        # Ordinary paragraph / list block until blank line or structural delimiter
        b_start = i
        i += 1
        while i <= end_line:
            nxt = lines[i - 1]
            ns = nxt.strip()
            if not ns or ns.startswith("|") or BEGIN_BLOCK_RE.match(nxt) or DRAWER_BEGIN_RE.match(nxt):
                break
            i += 1
        add_block("paragraph", b_start, i - 1)

    return blocks


def parse_org_document(path: Path, repo_root: Path = ROOT) -> OrgDocument:
    """Parse an ORG file into a block-aware AST without falling for spoofed headlines."""
    raw = path.read_bytes()
    text = raw.decode("utf-8")
    lines = text.splitlines()
    rel_path = path.resolve().relative_to(repo_root.resolve()).as_posix() if path.resolve().is_relative_to(repo_root.resolve()) else path.as_posix()

    title = path.stem
    has_copyright = SPDX_COPYRIGHT in text
    has_license = SPDX_LICENSE in text

    open_block: str | None = None
    unclosed_blocks: list[str] = []
    raw_headlines: list[tuple[int, int, str]] = []
    file_links: list[dict[str, Any]] = []

    for line_no, line in enumerate(lines, start=1):
        if open_block is None:
            bm = BEGIN_BLOCK_RE.match(line)
            if bm:
                open_block = bm.group(1).lower()
                continue
            km = KEYWORD_RE.match(line)
            if km and km.group(1).lower() == "title":
                title = km.group(2).strip()
            hm = HEADLINE_RE.match(line)
            if hm:
                raw_headlines.append((line_no, len(hm.group(1)), hm.group(2).strip()))
            for lm in FILE_LINK_RE.finditer(line):
                file_links.append(
                    {
                        "line": line_no,
                        "target_rel": lm.group(1),
                        "search": lm.group(2),
                        "custom_id": lm.group(3),
                    }
                )
        else:
            em = END_BLOCK_RE.match(line)
            if em and em.group(1).lower() == open_block:
                open_block = None

    if open_block is not None:
        unclosed_blocks.append(open_block)

    total_lines = len(lines)
    preamble_end = raw_headlines[0][0] - 1 if raw_headlines else total_lines

    # Build hierarchical section tree with exact inclusive [start_line, end_line]
    sections: list[OrgSection] = []
    stack: list[OrgSection] = []
    top_level_ids: list[str] = []

    for idx, (line_no, level, htitle) in enumerate(raw_headlines, start=1):
        sec_id = f"S{idx:03d}"
        while stack and stack[-1].level >= level:
            popped = stack.pop()
            popped.end_line = line_no - 1
        parent_id = stack[-1].section_id if stack else None
        sec = OrgSection(
            section_id=sec_id,
            level=level,
            title=htitle,
            start_line=line_no,
            end_line=total_lines,
            parent_id=parent_id,
        )
        if stack:
            stack[-1].children.append(sec_id)
        else:
            top_level_ids.append(sec_id)
        stack.append(sec)
        sections.append(sec)

    while stack:
        stack.pop().end_line = total_lines

    # Annotate every section with anchors, links, code/table counts, terms, and atomic blocks
    all_anchors: dict[str, str] = {}
    for sec in sections:
        seg = lines[sec.start_line - 1 : sec.end_line]
        in_blk: str | None = None
        anchors: list[str] = []
        internal_refs: list[str] = []
        out_links: list[dict[str, str | None]] = []
        code_lines = 0
        table_lines = 0
        for offset, ln in enumerate(seg):
            if in_blk is None:
                bm = BEGIN_BLOCK_RE.match(ln)
                if bm:
                    in_blk = bm.group(1).lower()
                    code_lines += 1
                    continue
                if ln.strip().startswith("|"):
                    table_lines += 1
                am = PROPERTY_ANCHOR_RE.match(ln)
                if am:
                    anchor = am.group(1).strip()
                    anchors.append(anchor)
                    all_anchors[anchor] = sec.section_id
                for tm in TARGET_RE.finditer(ln):
                    anchor = tm.group(1).strip()
                    anchors.append(anchor)
                    all_anchors[anchor] = sec.section_id
                for lm in FILE_LINK_RE.finditer(ln):
                    out_links.append(
                        {
                            "target_rel": lm.group(1),
                            "search": lm.group(2),
                            "custom_id": lm.group(3),
                        }
                    )
                for im in INTERNAL_LINK_RE.finditer(ln):
                    ref = (im.group(1) or im.group(2) or "").strip()
                    if ref:
                        internal_refs.append(ref)
            else:
                code_lines += 1
                em = END_BLOCK_RE.match(ln)
                if em and em.group(1).lower() == in_blk:
                    in_blk = None
        sec.anchors = list(dict.fromkeys(anchors))
        sec.internal_refs = list(dict.fromkeys(internal_refs))
        sec.outbound_file_links = out_links
        sec.code_block_lines = code_lines
        sec.table_lines = table_lines
        sec.top_terms = _extract_top_terms(seg)
        # Parse atomic blocks for leaf sections (excluding the headline line itself)
        if not sec.children and sec.end_line > sec.start_line:
            sec.blocks = _parse_atomic_blocks(lines, sec.start_line + 1, sec.end_line, sec.section_id)

    return OrgDocument(
        path=path,
        rel_path=rel_path,
        sha256=sha256_bytes(raw),
        total_lines=total_lines,
        total_bytes=len(raw),
        title=title,
        has_spdx=has_copyright and has_license,
        preamble_end_line=preamble_end,
        unclosed_blocks=unclosed_blocks,
        lines=lines,
        sections=sections,
        top_level_ids=top_level_ids,
        file_links=file_links,
        anchors=all_anchors,
    )


def list_repo_org_files(repo_root: Path = ROOT, roots: tuple[str, ...] = ("docs",)) -> list[Path]:
    """List non-submodule `.org` files under the specified roots."""
    submodules: set[str] = set()
    try:
        stage_out = subprocess.run(
            ["git", "ls-files", "--stage"],
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        for line in stage_out.splitlines():
            meta, p = line.split("\t", 1)
            if meta.split()[0] == "160000":
                submodules.add(p)
    except (subprocess.SubprocessError, FileNotFoundError):
        pass

    results: list[Path] = []
    for root_rel in roots:
        base = (repo_root / root_rel).resolve()
        if base.is_file() and base.suffix == ".org":
            results.append(base)
            continue
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*.org")):
            rel = p.relative_to(repo_root.resolve()).as_posix()
            if any(rel == sm or rel.startswith(sm + "/") for sm in submodules):
                continue
            results.append(p)
    return results


def collect_inbound_references(target_path: Path, repo_root: Path = ROOT) -> list[dict[str, Any]]:
    """Find all repository `[[file:...]]` or path references targeting `target_path`."""
    resolved_root = repo_root.resolve()
    resolved_target = target_path.resolve()
    target_rel = (
        resolved_target.relative_to(resolved_root).as_posix()
        if resolved_target.is_relative_to(resolved_root)
        else resolved_target.as_posix()
    )
    inbound: list[dict[str, Any]] = []
    scan_roots = [resolved_root / d for d in ("docs", "t", "dev", "packages", "proofs") if (resolved_root / d).exists()]
    for base in scan_roots:
        for p in sorted(base.rglob("*")):
            if not p.is_file() or p.suffix not in (".org", ".md", ".py", ".sysml", ".just", ".yml"):
                continue
            rp = p.resolve()
            if rp == resolved_target:
                continue
            try:
                text = rp.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
            if resolved_target.name not in text:
                continue
            src_rel = rp.relative_to(resolved_root).as_posix()
            is_qual = src_rel.startswith("t/qualification/") or "qualification" in src_rel
            for line_no, line in enumerate(text.splitlines(), start=1):
                matched = False
                for lm in FILE_LINK_RE.finditer(line):
                    candidate = (p.parent / lm.group(1)).resolve()
                    if candidate == resolved_target:
                        inbound.append(
                            {
                                "source_file": src_rel,
                                "line": line_no,
                                "kind": "org-file-link",
                                "raw_target": lm.group(1),
                                "search": lm.group(2),
                                "custom_id": lm.group(3),
                                "qualification_bound": is_qual,
                            }
                        )
                        matched = True
                if not matched and target_rel in line:
                    inbound.append(
                        {
                            "source_file": src_rel,
                            "line": line_no,
                            "kind": "path-mention",
                            "raw_target": target_rel,
                            "search": None,
                            "custom_id": None,
                            "qualification_bound": is_qual,
                        }
                    )
    return inbound


def group_monolithic_blocks_into_windows(
    section: OrgSection,
    lines: list[str],
    target_window_lines: int = DEFAULT_WINDOW_TARGET_LINES,
) -> list[dict[str, Any]]:
    """Group atomic blocks of a monolithic headline-less section into bounded L1 windows."""
    if not section.blocks:
        return []
    windows: list[dict[str, Any]] = []
    cur_blocks: list[AtomicBlock] = []
    cur_start: int | None = None
    cur_end: int | None = None

    def flush() -> None:
        nonlocal cur_blocks, cur_start, cur_end
        if not cur_blocks or cur_start is None or cur_end is None:
            return
        w_idx = len(windows) + 1
        seg = lines[cur_start - 1 : cur_end]
        first_line = next((ln.strip() for ln in seg if ln.strip()), "")
        windows.append(
            {
                "window_id": f"{section.section_id}.W{w_idx:02d}",
                "start_line": cur_start,
                "end_line": cur_end,
                "line_count": cur_end - cur_start + 1,
                "block_count": len(cur_blocks),
                "first_line_preview": first_line[:100],
                "top_terms": _extract_top_terms(seg, limit=6),
                "anchors": [a for b in cur_blocks for a in b.anchors],
            }
        )
        cur_blocks = []
        cur_start = None
        cur_end = None

    for blk in section.blocks:
        if cur_start is None:
            cur_start = blk.start_line
            cur_end = blk.end_line
            cur_blocks = [blk]
            continue
        projected = blk.end_line - cur_start + 1
        if projected > target_window_lines and cur_blocks:
            flush()
            cur_start = blk.start_line
            cur_end = blk.end_line
            cur_blocks = [blk]
        else:
            cur_end = blk.end_line
            cur_blocks.append(blk)
    flush()
    return windows


def decompose_into_modular_units(doc: OrgDocument, max_lines: int = DEFAULT_MAX_LINES) -> list[dict[str, Any]]:
    """Adaptive AST decomposition: expand oversized parents into children or atomic block chunks."""
    sec_by_id = {s.section_id: s for s in doc.sections}
    units: list[dict[str, Any]] = []

    def visit(sec_id: str) -> None:
        sec = sec_by_id[sec_id]
        if sec.line_count <= max_lines:
            units.append(
                {
                    "unit_id": sec.section_id,
                    "kind": "headline-section",
                    "level": sec.level,
                    "title": sec.title,
                    "start_line": sec.start_line,
                    "end_line": sec.end_line,
                    "line_count": sec.line_count,
                    "anchors": sec.anchors,
                    "internal_refs": sec.internal_refs,
                    "outbound_targets": sorted({l["target_rel"] for l in sec.outbound_file_links if l["target_rel"]}),
                    "top_terms": sec.top_terms,
                }
            )
            return

        if sec.children:
            first_child = sec_by_id[sec.children[0]]
            intro_end = first_child.start_line - 1
            if intro_end >= sec.start_line:
                intro_seg = doc.lines[sec.start_line - 1 : intro_end]
                units.append(
                    {
                        "unit_id": f"{sec.section_id}.intro",
                        "kind": "section-intro",
                        "level": sec.level,
                        "title": f"{sec.title} (intro)",
                        "start_line": sec.start_line,
                        "end_line": intro_end,
                        "line_count": intro_end - sec.start_line + 1,
                        "anchors": [],
                        "internal_refs": [],
                        "outbound_targets": [],
                        "top_terms": _extract_top_terms(intro_seg),
                    }
                )
            for child_id in sec.children:
                visit(child_id)
            return

        # Oversized monolithic leaf section without sub-headlines: split on atomic block boundaries!
        chunk_budget = max(200, int(max_lines * 0.72))
        windows = group_monolithic_blocks_into_windows(sec, doc.lines, target_window_lines=chunk_budget)
        if not windows:
            units.append(
                {
                    "unit_id": sec.section_id,
                    "kind": "indivisible-monolith",
                    "level": sec.level,
                    "title": sec.title,
                    "start_line": sec.start_line,
                    "end_line": sec.end_line,
                    "line_count": sec.line_count,
                    "anchors": sec.anchors,
                    "internal_refs": sec.internal_refs,
                    "outbound_targets": sorted({l["target_rel"] for l in sec.outbound_file_links if l["target_rel"]}),
                    "top_terms": sec.top_terms,
                }
            )
            return

        for idx, win in enumerate(windows, start=1):
            start_ln = sec.start_line if idx == 1 else win["start_line"]
            end_ln = win["end_line"]
            units.append(
                {
                    "unit_id": f"{sec.section_id}.part{idx:02d}",
                    "kind": "monolith-block-slice",
                    "parent_section_id": sec.section_id,
                    "level": sec.level,
                    "title": f"{sec.title} (part {idx})",
                    "start_line": start_ln,
                    "end_line": end_ln,
                    "line_count": end_ln - start_ln + 1,
                    "anchors": win["anchors"],
                    "internal_refs": [],
                    "outbound_targets": [],
                    "top_terms": win["top_terms"],
                    "boundary_note": "Atomic ORG block boundary (never mid-table or mid-codeblock); requires L2 review of narrative seam",
                }
            )

    for top_id in doc.top_level_ids:
        visit(top_id)
    return units


def classify_domain(terms: list[str], title: str) -> str:
    bag = set(terms) | set(TOKEN_RE.findall(title.lower()))
    best_domain = "general-design"
    best_hits = 0
    for domain, sig in DOMAIN_SIGNATURES.items():
        hits = len(bag & set(sig))
        if hits > best_hits:
            best_hits = hits
            best_domain = domain
    return best_domain


def build_ascent_l0_l1_packet(
    path: Path,
    *,
    repo_root: Path = ROOT,
    max_lines: int = DEFAULT_MAX_LINES,
) -> dict[str, Any]:
    """Build the compact L0/L1 progressive-disclosure packet for ASCENT planning."""
    doc = parse_org_document(path, repo_root=repo_root)
    frozen_patterns = load_frozen_reuse_patterns(repo_root)
    frozen = is_frozen_path(doc.rel_path, frozen_patterns)
    inbound = collect_inbound_references(path, repo_root=repo_root)

    sec_by_id = {s.section_id: s for s in doc.sections}
    title_to_sec = {s.title.lower(): s.section_id for s in doc.sections}

    # Build section-to-section coupling edges
    internal_edges: list[dict[str, str]] = []
    for sec in doc.sections:
        for ref in sec.internal_refs:
            target_sec = doc.anchors.get(ref) or title_to_sec.get(ref.lower())
            if target_sec and target_sec != sec.section_id:
                internal_edges.append({"from": sec.section_id, "to": target_sec, "ref": ref})

    # Map inbound links to sections when #custom_id or ::*heading is specified
    inbound_by_section: dict[str, int] = Counter()
    qual_inbound_count = sum(1 for r in inbound if r["qualification_bound"])
    for ref in inbound:
        cid = ref.get("custom_id")
        srch = ref.get("search")
        if cid and cid in doc.anchors:
            inbound_by_section[doc.anchors[cid]] += 1
        elif srch and srch.startswith("*"):
            hit = title_to_sec.get(srch.lstrip("*").strip().lower())
            if hit:
                inbound_by_section[hit] += 1

    monolithic_sections: list[dict[str, Any]] = []
    l1_sections: list[dict[str, Any]] = []
    for sec in doc.sections:
        is_monolith = (not sec.children) and (sec.line_count > max_lines)
        entry: dict[str, Any] = {
            "section_id": sec.section_id,
            "parent_id": sec.parent_id,
            "level": sec.level,
            "title": sec.title,
            "start_line": sec.start_line,
            "end_line": sec.end_line,
            "line_count": sec.line_count,
            "code_block_lines": sec.code_block_lines,
            "table_lines": sec.table_lines,
            "anchors": sec.anchors,
            "outbound_link_count": len(sec.outbound_file_links),
            "inbound_anchor_refs": inbound_by_section.get(sec.section_id, 0),
            "domain_hint": classify_domain(sec.top_terms, sec.title),
            "top_terms": sec.top_terms,
            "monolithic_leaf": is_monolith,
        }
        if is_monolith:
            windows = group_monolithic_blocks_into_windows(sec, doc.lines)
            entry["l1_block_windows"] = windows
            monolithic_sections.append(
                {
                    "section_id": sec.section_id,
                    "title": sec.title,
                    "line_count": sec.line_count,
                    "atomic_block_count": len(sec.blocks),
                    "window_count": len(windows),
                }
            )
        l1_sections.append(entry)

    # Explicit Slice-48 omitted-body receipt (L1 omits raw prose; L2/L3 fetched on demand)
    omitted_spans = [
        {
            "section_id": sec.section_id,
            "start_line": sec.start_line,
            "end_line": sec.end_line,
            "fetch_command": f"python3 packages/automation/org_modularization.py read-section {doc.rel_path} --section-id {sec.section_id}",
        }
        for sec in doc.sections
        if not sec.children
    ]

    return {
        "schema": "agentic-ai-org-modularization-packet-v1",
        "disclosure_level": "L1",
        "l0_summary": {
            "rel_path": doc.rel_path,
            "title": doc.title,
            "sha256": doc.sha256,
            "total_lines": doc.total_lines,
            "total_bytes": doc.total_bytes,
            "max_lines_threshold": max_lines,
            "exceeds_threshold": doc.total_lines > max_lines,
            "frozen_exempt": frozen,
            "has_spdx": doc.has_spdx,
            "unclosed_blocks": doc.unclosed_blocks,
            "top_level_section_count": len(doc.top_level_ids),
            "total_section_count": len(doc.sections),
            "monolithic_leaf_sections": monolithic_sections,
            "outbound_file_links": len(doc.file_links),
            "inbound_repo_references": len(inbound),
            "qualification_bound_inbound_references": qual_inbound_count,
        },
        "l1_sections": l1_sections,
        "coupling_graph": {
            "internal_cross_section_edges": internal_edges,
            "inbound_references_sample": inbound[:25],
        },
        "omitted_text_receipt": {
            "policy": "Slice-48 L1 outline only; prose bodies omitted to prevent context pollution. Request L2/L3 spans on demand before finalizing narrative split seams.",
            "omitted_leaf_sections": len(omitted_spans),
            "on_demand_handles": omitted_spans,
        },
    }


def _evaluate_branch(
    doc: OrgDocument,
    branch_id: str,
    strategy_name: str,
    rationale: str,
    keep_units: list[dict[str, Any]],
    extracted_modules: list[dict[str, Any]],
    *,
    max_lines: int,
    inbound_refs: list[dict[str, Any]],
    frozen: bool,
) -> dict[str, Any]:
    """Evaluate a modularization branch against every independent risk/quality axis."""
    # Build unit -> target_file mapping
    target_for_anchor: dict[str, str] = {}
    unit_targets: dict[str, str] = {}
    for u in keep_units:
        unit_targets[u["unit_id"]] = doc.path.name
        for a in u.get("anchors", []):
            target_for_anchor[a] = doc.path.name

    for mod in extracted_modules:
        for u in mod["units"]:
            unit_targets[u["unit_id"]] = mod["target_filename"]
            for a in u.get("anchors", []):
                target_for_anchor[a] = mod["target_filename"]

    # Umbrella size estimate = preamble + kept units + module index table (~6 + len(extracted))
    umbrella_lines = doc.preamble_end_line + sum(u["line_count"] for u in keep_units) + 8 + len(extracted_modules) * 2
    module_sizes = [
        {"file": doc.path.name, "role": "umbrella", "estimated_lines": umbrella_lines}
    ]
    for mod in extracted_modules:
        # 12 lines overhead for title + SPDX + back-link header
        est = 12 + sum(u["line_count"] for u in mod["units"])
        mod["estimated_lines"] = est
        module_sizes.append({"file": mod["target_filename"], "role": "extracted-module", "estimated_lines": est})

    over_budget = [m for m in module_sizes if m["estimated_lines"] > max_lines]
    max_mod_lines = max((m["estimated_lines"] for m in module_sizes), default=0)

    # Count internal cross-module cut edges
    cut_edges = 0
    for u in keep_units + [u for mod in extracted_modules for u in mod["units"]]:
        src_file = unit_targets[u["unit_id"]]
        for ref in u.get("internal_refs", []):
            dst_file = target_for_anchor.get(ref)
            if dst_file and dst_file != src_file:
                cut_edges += 1

    # Count inbound links targeting anchors moved out of the umbrella (supports both #cid and ::#cid)
    moved_anchors = {a for a, fname in target_for_anchor.items() if fname != doc.path.name}
    impacted_inbound = 0
    impacted_qual_inbound = 0
    for ref in inbound_refs:
        srch = ref.get("search")
        cid = ref.get("custom_id") or (srch[1:] if isinstance(srch, str) and srch.startswith("#") else None)
        if cid and cid in moved_anchors:
            impacted_inbound += 1
            if ref.get("qualification_bound"):
                impacted_qual_inbound += 1

    # Check if chronological reading order is preserved across umbrella + extracted modules
    ordered_starts = [u["start_line"] for u in keep_units]
    all_extracted_order = [u["start_line"] for mod in extracted_modules for u in mod["units"]]
    preserves_order = (all_extracted_order == sorted(all_extracted_order)) and (ordered_starts == sorted(ordered_starts))

    monolith_splits = sum(
        1 for mod in extracted_modules for u in mod["units"] if u.get("kind") == "monolith-block-slice"
    )
    open_questions: list[str] = []
    if monolith_splits > 0:
        open_questions.append(
            f"Branch splits {monolith_splits} monolithic headline-less slice(s) on atomic ORG block boundaries; "
            f"inspect boundary lines at L2/L3 to confirm narrative coherence and choose descriptive sub-titles."
        )
    if impacted_qual_inbound > 0:
        open_questions.append(
            f"{impacted_qual_inbound} qualification-bound inbound reference(s) target moved anchors; "
            f"confirm historical evidence path policy before relocating those anchors."
        )
    if frozen:
        open_questions.append(
            "Source document is frozen in REUSE.toml; apply is unconditionally blocked unless freeze policy changes."
        )

    canonical_spec = {
        "source_rel_path": doc.rel_path,
        "source_sha256": doc.sha256,
        "branch_id": branch_id,
        "keep_ranges": [[u["start_line"], u["end_line"]] for u in keep_units],
        "extracted_modules": [
            {
                "target_filename": mod["target_filename"],
                "title": mod["title"],
                "ranges": [[u["start_line"], u["end_line"]] for u in mod["units"]],
            }
            for mod in extracted_modules
        ],
    }
    plan_sha256 = hashlib.sha256(
        json.dumps(canonical_spec, sort_keys=True).encode("utf-8")
    ).hexdigest()

    return {
        "branch_id": branch_id,
        "strategy": strategy_name,
        "rationale": rationale,
        "plan_sha256": plan_sha256,
        "authorization_status": "proposal-only-requires-explicit-approval",
        "canonical_spec": canonical_spec,
        "module_sizes": module_sizes,
        "hypothesis_evaluation": {
            "H1_line_budget_satisfied": len(over_budget) == 0,
            "H2_max_module_lines": max_mod_lines,
            "H3_cross_module_cut_edges": cut_edges,
            "H4_inbound_anchor_links_impacted": impacted_inbound,
            "H5_qualification_evidence_safe": (not frozen) and (impacted_qual_inbound == 0),
            "H6_chronological_order_preserved": preserves_order,
            "H7_extracted_module_count": len(extracted_modules),
            "H8_monolithic_block_seams_requiring_l2_review": monolith_splits,
        },
        "open_questions": open_questions,
    }


def _pack_contiguous_units(
    units: list[dict[str, Any]],
    stem: str,
    max_lines: int,
    label_prefix: str,
) -> list[dict[str, Any]]:
    """Pack a sequence of units into contiguous extracted modules respecting max_lines."""
    modules: list[dict[str, Any]] = []
    cur: list[dict[str, Any]] = []
    cur_lines = 12
    budget = max(250, max_lines - 20)

    def flush() -> None:
        nonlocal cur, cur_lines
        if not cur:
            return
        idx = len(modules) + 1
        lead_slug = slugify(cur[0]["title"], max_len=28)
        fname = f"{stem}--{label_prefix}-{idx:02d}-{lead_slug}.org"
        title = cur[0]["title"] if len(cur) == 1 else f"{cur[0]['title']} .. {cur[-1]['title']}"
        modules.append({"target_filename": fname, "title": title, "units": list(cur)})
        cur = []
        cur_lines = 12

    for u in units:
        if cur and cur_lines + u["line_count"] > budget:
            flush()
        cur.append(u)
        cur_lines += u["line_count"]
    flush()
    return modules


def build_ascent_modularization_plan(
    path: Path,
    *,
    repo_root: Path = ROOT,
    max_lines: int = DEFAULT_MAX_LINES,
    custom_branch_path: Path | None = None,
) -> dict[str, Any]:
    """Generate and evaluate competing modularization branches (Slice 43 + 48)."""
    doc = parse_org_document(path, repo_root=repo_root)
    frozen_patterns = load_frozen_reuse_patterns(repo_root)
    frozen = is_frozen_path(doc.rel_path, frozen_patterns)
    inbound = collect_inbound_references(path, repo_root=repo_root)
    units = decompose_into_modular_units(doc, max_lines=max_lines)
    stem = doc.path.stem

    branches: list[dict[str, Any]] = []

    # Branch A: Umbrella + Heavy-Offload (keep intro + lightweight index sections in original file;
    # offload monolithic / heavy sections to minimize inbound link churn)
    heavy_threshold = max(120, int(max_lines * 0.25))
    keep_a: list[dict[str, Any]] = []
    offload_a: list[dict[str, Any]] = []
    keep_budget = max(250, int(max_lines * 0.70))
    kept_lines = doc.preamble_end_line + 16
    for u in units:
        is_heavy = (u["kind"] == "monolith-block-slice") or (u["line_count"] >= heavy_threshold)
        if not is_heavy and (kept_lines + u["line_count"] <= keep_budget):
            keep_a.append(u)
            kept_lines += u["line_count"]
        else:
            offload_a.append(u)
    mods_a = _pack_contiguous_units(offload_a, stem, max_lines, "offload")
    branches.append(
        _evaluate_branch(
            doc,
            "branch-a-umbrella-heavy-offload",
            "Umbrella + Heavy-Offload",
            "Preserve lightweight overview/index sections in the original path while extracting heavy/monolithic subtrees into sibling ORG modules.",
            keep_a,
            mods_a,
            max_lines=max_lines,
            inbound_refs=inbound,
            frozen=frozen,
        )
    )

    # Branch B: Chronological Balanced Contiguous Partition (keep first brief intro in umbrella,
    # partition remaining sections strictly in chronological reading order)
    keep_b: list[dict[str, Any]] = []
    rest_b: list[dict[str, Any]] = []
    intro_budget = max(120, int(max_lines * 0.22))
    intro_used = doc.preamble_end_line + 16
    for u in units:
        if not rest_b and u["kind"] != "monolith-block-slice" and (intro_used + u["line_count"] <= intro_budget):
            keep_b.append(u)
            intro_used += u["line_count"]
        else:
            rest_b.append(u)
    mods_b = _pack_contiguous_units(rest_b, stem, max_lines, "part")
    branches.append(
        _evaluate_branch(
            doc,
            "branch-b-chronological-slices",
            "Chronological Contiguous Slices",
            "Preserve strict original reading order by turning the original file into a thin umbrella and slicing contiguous chunks within the line budget.",
            keep_b,
            mods_b,
            max_lines=max_lines,
            inbound_refs=inbound,
            frozen=frozen,
        )
    )

    # Branch C: Semantic Domain Cohesion Clusters (group units by domain signature while keeping
    # umbrella thin and isolating monolithic logs)
    domain_buckets: dict[str, list[dict[str, Any]]] = {}
    keep_c: list[dict[str, Any]] = []
    for idx, u in enumerate(units):
        if idx < 2 and u["line_count"] <= 120 and u["kind"] != "monolith-block-slice":
            keep_c.append(u)
            continue
        dom = "monolithic-log" if u["kind"] == "monolith-block-slice" else classify_domain(u["top_terms"], u["title"])
        domain_buckets.setdefault(dom, []).append(u)
    mods_c: list[dict[str, Any]] = []
    for dom in sorted(domain_buckets):
        mods_c.extend(_pack_contiguous_units(domain_buckets[dom], stem, max_lines, dom))
    branches.append(
        _evaluate_branch(
            doc,
            "branch-c-domain-cohesion",
            "Domain Cohesion Clusters",
            "Cluster related sections by semantic ownership domain (governance/proof, build/runtime attribution, query/memory/recovery) and isolate monolithic logs.",
            keep_c,
            mods_c,
            max_lines=max_lines,
            inbound_refs=inbound,
            frozen=frozen,
        )
    )

    # Optional investigator/ASCENT custom proposed branch
    if custom_branch_path is not None:
        custom = json.loads(custom_branch_path.read_text(encoding="utf-8"))
        unit_by_id = {u["unit_id"]: u for u in units}
        c_keep = [unit_by_id[uid] for uid in custom.get("keep_unit_ids", [])]
        c_mods = []
        for mod in custom.get("extracted_modules", []):
            c_mods.append(
                {
                    "target_filename": mod["target_filename"],
                    "title": mod["title"],
                    "units": [unit_by_id[uid] for uid in mod["unit_ids"]],
                }
            )
        branches.append(
            _evaluate_branch(
                doc,
                custom.get("branch_id", "branch-custom-proposed"),
                custom.get("strategy", "Investigator / ASCENT Proposed Branch"),
                custom.get("rationale", "Bounded proposal supplied externally for competing-hypothesis evaluation."),
                c_keep,
                c_mods,
                max_lines=max_lines,
                inbound_refs=inbound,
                frozen=frozen,
            )
        )

    contradictions = [
        "Trade-off: Branch A minimizes umbrella link churn for lightweight sections, while Branch B preserves strict contiguous chronological order.",
        "Trade-off: Branch C maximizes semantic domain cohesion per file, but reorders sections relative to the original file timeline.",
    ]

    return {
        "schema": "agentic-ai-org-modularization-plan-v1",
        "hypothetical_fit_does_not_authorize_write": True,
        "source": {
            "rel_path": doc.rel_path,
            "title": doc.title,
            "sha256": doc.sha256,
            "total_lines": doc.total_lines,
            "max_lines_threshold": max_lines,
            "frozen_exempt": frozen,
            "inbound_repo_references": len(inbound),
            "modular_unit_count": len(units),
        },
        "competing_branches": branches,
        "contradictions_and_tradeoffs": contradictions,
        "omitted_alternatives_receipt": {
            "preserved_branch_ids": [b["branch_id"] for b in branches],
            "note": "No branch is auto-selected or executed. Human or governance approval must supply both --branch and --approve-plan-sha256.",
        },
    }


def apply_approved_plan(
    plan_path: Path,
    *,
    branch_id: str,
    approve_plan_sha256: str,
    repo_root: Path = ROOT,
    dry_run: bool = False,
    rewrite_inbound: bool = False,
) -> dict[str, Any]:
    """Deterministically apply an explicitly approved modularization branch and verify invariants."""
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    branch = next((b for b in plan.get("competing_branches", []) if b.get("branch_id") == branch_id), None)
    if branch is None:
        raise RuntimeError(f"Branch '{branch_id}' not found in {plan_path}")

    canonical_spec = branch["canonical_spec"]
    recomputed_sha = hashlib.sha256(
        json.dumps(canonical_spec, sort_keys=True).encode("utf-8")
    ).hexdigest()
    if recomputed_sha != branch.get("plan_sha256") or recomputed_sha != approve_plan_sha256:
        raise RuntimeError(
            f"Approval SHA-256 mismatch for {branch_id}: expected={recomputed_sha} provided={approve_plan_sha256}"
        )

    source_rel = canonical_spec["source_rel_path"]
    frozen_patterns = load_frozen_reuse_patterns(repo_root)
    if is_frozen_path(source_rel, frozen_patterns):
        raise RuntimeError(f"Refusing to split frozen historical document: {source_rel}")

    source_path = (repo_root / source_rel).resolve()
    doc = parse_org_document(source_path, repo_root=repo_root)
    if doc.sha256 != canonical_spec["source_sha256"]:
        raise RuntimeError(
            f"Stale plan: {source_rel} changed since plan generation "
            f"(expected={canonical_spec['source_sha256']}, actual={doc.sha256})"
        )
    if doc.unclosed_blocks:
        raise RuntimeError(f"Source {source_rel} has unclosed ORG blocks: {doc.unclosed_blocks}")

    # Validate exact partition coverage of all post-preamble lines without overlap
    covered_lines: list[int] = []
    all_ranges: list[tuple[int, int, str]] = []
    for r in canonical_spec["keep_ranges"]:
        all_ranges.append((int(r[0]), int(r[1]), doc.path.name))
    for mod in canonical_spec["extracted_modules"]:
        for r in mod["ranges"]:
            all_ranges.append((int(r[0]), int(r[1]), mod["target_filename"]))

    for s_ln, e_ln, owner in sorted(all_ranges):
        if s_ln < 1 or e_ln > doc.total_lines or s_ln > e_ln:
            raise RuntimeError(f"Invalid line range [{s_ln}, {e_ln}] for {owner}")
        covered_lines.extend(range(s_ln, e_ln + 1))

    if len(covered_lines) != len(set(covered_lines)):
        raise RuntimeError("Overlapping line ranges detected in approved plan")

    expected_post_preamble = set(range(doc.preamble_end_line + 1, doc.total_lines + 1))
    uncovered = sorted(expected_post_preamble - set(covered_lines))
    # Only blank separator lines between atomic blocks may be omitted
    non_blank_uncovered = [ln for ln in uncovered if doc.lines[ln - 1].strip()]
    if non_blank_uncovered:
        raise RuntimeError(f"Plan omits non-blank source lines: {non_blank_uncovered[:10]}")

    # Pre-scan anchors across umbrella and extracted modules so cross-module [[#anchor]] links can be rewritten cleanly
    anchor_owner: dict[str, str] = {}
    for s_ln, e_ln in canonical_spec["keep_ranges"]:
        for ln in doc.lines[s_ln - 1 : e_ln]:
            am = PROPERTY_ANCHOR_RE.match(ln)
            if am:
                anchor_owner[am.group(1).strip()] = source_path.name
            for tm in TARGET_RE.finditer(ln):
                anchor_owner[tm.group(1).strip()] = source_path.name
    for mod in canonical_spec["extracted_modules"]:
        for s_ln, e_ln in mod["ranges"]:
            for ln in doc.lines[s_ln - 1 : e_ln]:
                am = PROPERTY_ANCHOR_RE.match(ln)
                if am:
                    anchor_owner[am.group(1).strip()] = mod["target_filename"]
                for tm in TARGET_RE.finditer(ln):
                    anchor_owner[tm.group(1).strip()] = mod["target_filename"]

    rewritten_internal_links: list[dict[str, str]] = []

    def _rewrite_cross_module_anchors(chunk_lines: list[str], owner_filename: str) -> list[str]:
        out: list[str] = []
        for ln in chunk_lines:
            def _sub(match: re.Match[str]) -> str:
                cid = match.group(1)
                if cid and cid in anchor_owner and anchor_owner[cid] != owner_filename:
                    dst = anchor_owner[cid]
                    rewritten_internal_links.append({"from": owner_filename, "to": dst, "anchor": cid})
                    return f"[[file:{dst}#{cid}]"
                return match.group(0)

            out.append(INTERNAL_LINK_RE.sub(_sub, ln))
        return out

    # Build extracted module contents and record anchor moves
    written_files: dict[Path, str] = {}
    moved_anchors: dict[str, str] = {a: f for a, f in anchor_owner.items() if f != source_path.name}
    extracted_raw_lines: list[str] = []

    for mod in canonical_spec["extracted_modules"]:
        target_path = source_path.parent / mod["target_filename"]
        if target_path.exists():
            raise RuntimeError(f"Refusing to overwrite existing file: {target_path}")
        body_chunks: list[str] = []
        first_non_blank: str | None = None
        for s_ln, e_ln in mod["ranges"]:
            chunk_lines = doc.lines[s_ln - 1 : e_ln]
            extracted_raw_lines.extend(chunk_lines)
            if first_non_blank is None:
                first_non_blank = next((ln for ln in chunk_lines if ln.strip()), None)
            rewritten_chunk = _rewrite_cross_module_anchors(chunk_lines, mod["target_filename"])
            body_chunks.append("\n".join(rewritten_chunk))
        header_lines = [
            f"#+title: {mod['title']}",
            "#+language: en",
            "#+begin_comment",
            SPDX_COPYRIGHT,
            SPDX_LICENSE,
            "#+end_comment",
            "",
            f"Extracted module of [[file:{source_path.name}][{doc.title}]].",
            "",
        ]
        if first_non_blank is None or not first_non_blank.startswith("* "):
            header_lines.extend([f"* {mod['title']}", ""])
        written_files[target_path] = "\n".join(header_lines) + "\n\n".join(body_chunks).rstrip() + "\n"

    # Build rewritten umbrella file
    preamble_lines = doc.lines[: doc.preamble_end_line]
    kept_raw_lines: list[str] = []
    kept_chunks: list[str] = []
    for s_ln, e_ln in canonical_spec["keep_ranges"]:
        chunk_lines = doc.lines[s_ln - 1 : e_ln]
        kept_raw_lines.extend(chunk_lines)
        rewritten_chunk = _rewrite_cross_module_anchors(chunk_lines, source_path.name)
        kept_chunks.append("\n".join(rewritten_chunk))

    index_lines = [
        "* Modularized child ORG modules",
        "",
        "| Child module | Title |",
        "|--------------+-------|",
    ]
    for mod in canonical_spec["extracted_modules"]:
        index_lines.append(f"| [[file:{mod['target_filename']}][{mod['target_filename']}]] | {mod['title']} |")

    umbrella_parts = ["\n".join(preamble_lines).rstrip()]
    if kept_chunks:
        umbrella_parts.append("\n\n".join(kept_chunks).rstrip())
    umbrella_parts.append("\n".join(index_lines))
    written_files[source_path] = "\n\n".join(p for p in umbrella_parts if p).rstrip() + "\n"

    # Stage-1/Stage-2 verification before/after writing
    # Verify 100% non-blank body line conservation!
    original_non_blank = Counter(
        doc.lines[ln - 1] for ln in range(doc.preamble_end_line + 1, doc.total_lines + 1) if doc.lines[ln - 1].strip()
    )
    emitted_non_blank = Counter(ln for ln in (kept_raw_lines + extracted_raw_lines) if ln.strip())
    if original_non_blank != emitted_non_blank:
        raise RuntimeError("Line conservation check failed: emitted non-blank lines differ from original source")

    rewritten_inbound_files: list[str] = []
    if not dry_run:
        for fpath, content in written_files.items():
            fpath.write_text(content, encoding="utf-8")

        if rewrite_inbound and moved_anchors:
            for ref in collect_inbound_references(source_path, repo_root=repo_root):
                srch = ref.get("search")
                cid = ref.get("custom_id") or (srch[1:] if isinstance(srch, str) and srch.startswith("#") else None)
                if cid and cid in moved_anchors:
                    src_p = repo_root / ref["source_file"]
                    old_txt = src_p.read_text(encoding="utf-8")
                    new_rel = Path(ref["raw_target"]).with_name(moved_anchors[cid]).as_posix()
                    new_txt = old_txt
                    for sep in ("::#", "#"):
                        old_pat = f"[[file:{ref['raw_target']}{sep}{cid}]"
                        new_pat = f"[[file:{new_rel}{sep}{cid}]"
                        if old_pat in new_txt:
                            new_txt = new_txt.replace(old_pat, new_pat)
                    if new_txt != old_txt:
                        src_p.write_text(new_txt, encoding="utf-8")
                        rewritten_inbound_files.append(ref["source_file"])

        # Post-split Stage-2 AST, SPDX, and relative-link verification on every written file
        for fpath in written_files:
            reparsed = parse_org_document(fpath, repo_root=repo_root)
            if reparsed.unclosed_blocks:
                raise RuntimeError(f"Post-split AST check failed (unclosed blocks) on {fpath.name}: {reparsed.unclosed_blocks}")
            if (fpath != source_path or doc.has_spdx) and not reparsed.has_spdx:
                raise RuntimeError(f"Post-split SPDX header missing on {fpath.name}")
            for lk in reparsed.file_links:
                rel_target = lk["target_rel"]
                resolved = (fpath.parent / rel_target).resolve()
                if not resolved.exists() and "dev/d2/output/org-agentic-inquiry" not in rel_target:
                    raise RuntimeError(f"Post-split broken relative link in {fpath.name}: {rel_target}")

    return {
        "schema": "agentic-ai-org-modularization-apply-receipt-v1",
        "dry_run": dry_run,
        "branch_id": branch_id,
        "approved_plan_sha256": recomputed_sha,
        "source_rel_path": source_rel,
        "files_emitted": [
            {
                "path": (
                    p.resolve().relative_to(repo_root.resolve()).as_posix()
                    if p.resolve().is_relative_to(repo_root.resolve())
                    else str(p)
                ),
                "lines": len(content.splitlines()),
                "sha256": sha256_bytes(content.encode("utf-8")),
            }
            for p, content in written_files.items()
        ],
        "non_blank_body_lines_conserved": sum(original_non_blank.values()),
        "rewritten_internal_links": rewritten_internal_links,
        "rewritten_inbound_files": sorted(set(rewritten_inbound_files)),
    }


def cmd_scan(args: argparse.Namespace) -> int:
    repo_root = args.repo_root.resolve()
    frozen_patterns = load_frozen_reuse_patterns(repo_root)
    org_files = list_repo_org_files(repo_root, roots=tuple(args.roots))

    oversized: list[dict[str, Any]] = []
    monolithic_only: list[dict[str, Any]] = []
    for p in org_files:
        doc = parse_org_document(p, repo_root=repo_root)
        frozen = is_frozen_path(doc.rel_path, frozen_patterns)
        monoliths = [
            {"section_id": s.section_id, "title": s.title, "lines": s.line_count}
            for s in doc.sections
            if (not s.children) and (s.line_count > args.max_lines)
        ]
        if doc.total_lines > args.max_lines:
            oversized.append(
                {
                    "rel_path": doc.rel_path,
                    "total_lines": doc.total_lines,
                    "top_level_sections": len(doc.top_level_ids),
                    "monolithic_leaves": monoliths,
                    "frozen_exempt": frozen,
                    "unclosed_blocks": doc.unclosed_blocks,
                }
            )
        elif monoliths:
            monolithic_only.append({"rel_path": doc.rel_path, "monolithic_leaves": monoliths})

    oversized.sort(key=lambda item: item["total_lines"], reverse=True)
    actionable = [item for item in oversized if not item["frozen_exempt"]]
    report = {
        "schema": "agentic-ai-org-modularity-scan-v1",
        "max_lines_threshold": args.max_lines,
        "scanned_org_files": len(org_files),
        "oversized_count": len(oversized),
        "actionable_oversized_count": len(actionable),
        "frozen_exempt_oversized_count": len(oversized) - len(actionable),
        "oversized_documents": oversized,
        "monolithic_sections_under_file_limit": monolithic_only,
    }
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(
            f"ORG-MODULARITY-SCAN files={len(org_files)} threshold={args.max_lines} "
            f"oversized={len(oversized)} actionable={len(actionable)} frozen_exempt={len(oversized) - len(actionable)}"
        )
        for item in oversized:
            flag = "FROZEN-EXEMPT" if item["frozen_exempt"] else "ACTIONABLE"
            mono = f" monolithic_leaves={len(item['monolithic_leaves'])}" if item["monolithic_leaves"] else ""
            print(f"  [{flag}] {item['total_lines']:5d} lines  {item['rel_path']}{mono}")

    if args.fail_on_unmodularized and actionable:
        return 1
    return 0


def cmd_packet(args: argparse.Namespace) -> int:
    repo_root = args.repo_root.resolve()
    target = (repo_root / args.org_file).resolve() if not Path(args.org_file).is_absolute() else Path(args.org_file)
    packet = build_ascent_l0_l1_packet(target, repo_root=repo_root, max_lines=args.max_lines)
    out_text = json.dumps(packet, indent=2) + "\n"
    if args.output:
        args.output.write_text(out_text, encoding="utf-8")
    else:
        print(out_text, end="")
    return 0


def cmd_read_section(args: argparse.Namespace) -> int:
    repo_root = args.repo_root.resolve()
    target = (repo_root / args.org_file).resolve() if not Path(args.org_file).is_absolute() else Path(args.org_file)
    doc = parse_org_document(target, repo_root=repo_root)
    if args.section_id:
        sec = next((s for s in doc.sections if s.section_id == args.section_id), None)
        if sec is None:
            raise SystemExit(f"Unknown section_id '{args.section_id}' in {doc.rel_path}")
        start_ln, end_ln = sec.start_line, sec.end_line
    else:
        start_ln = max(1, args.start_line or 1)
        end_ln = min(doc.total_lines, args.end_line or min(doc.total_lines, start_ln + 80))

    max_span = args.max_span
    truncated = False
    if end_ln - start_ln + 1 > max_span:
        end_ln = start_ln + max_span - 1
        truncated = True
    payload = {
        "schema": "agentic-ai-org-progressive-read-v1",
        "disclosure_level": "L2-L3",
        "rel_path": doc.rel_path,
        "start_line": start_ln,
        "end_line": end_ln,
        "truncated": truncated,
        "content": "\n".join(f"{ln:5d}: {doc.lines[ln - 1]}" for ln in range(start_ln, end_ln + 1)),
    }
    print(json.dumps(payload, indent=2))
    return 0


def cmd_plan(args: argparse.Namespace) -> int:
    repo_root = args.repo_root.resolve()
    target = (repo_root / args.org_file).resolve() if not Path(args.org_file).is_absolute() else Path(args.org_file)
    plan = build_ascent_modularization_plan(
        target,
        repo_root=repo_root,
        max_lines=args.max_lines,
        custom_branch_path=args.propose_branch,
    )
    out_text = json.dumps(plan, indent=2) + "\n"
    if args.output:
        args.output.write_text(out_text, encoding="utf-8")
    if args.json or not args.output:
        if args.json:
            print(out_text, end="")
        else:
            src = plan["source"]
            print(
                f"ASCENT-ORG-MODULARIZATION-PLAN file={src['rel_path']} "
                f"lines={src['total_lines']} threshold={src['max_lines_threshold']} "
                f"frozen={src['frozen_exempt']} units={src['modular_unit_count']} "
                f"branches={len(plan['competing_branches'])}"
            )
            for b in plan["competing_branches"]:
                ev = b["hypothesis_evaluation"]
                print(
                    f"  - {b['branch_id']} ({b['strategy']}): "
                    f"modules={ev['H7_extracted_module_count']}+umbrella "
                    f"max_lines={ev['H2_max_module_lines']} "
                    f"budget_ok={ev['H1_line_budget_satisfied']} "
                    f"cut_edges={ev['H3_cross_module_cut_edges']} "
                    f"inbound_impacted={ev['H4_inbound_anchor_links_impacted']} "
                    f"order_ok={ev['H6_chronological_order_preserved']} "
                    f"plan_sha256={b['plan_sha256'][:12]}"
                )
    return 0


def cmd_apply(args: argparse.Namespace) -> int:
    receipt = apply_approved_plan(
        args.plan_json.resolve(),
        branch_id=args.branch,
        approve_plan_sha256=args.approve_plan_sha256,
        repo_root=args.repo_root.resolve(),
        dry_run=args.dry_run,
        rewrite_inbound=args.rewrite_inbound,
    )
    print(json.dumps(receipt, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=ROOT, help="Repository root directory")
    sub = parser.add_subparsers(dest="command", required=True)

    p_scan = sub.add_parser("scan", help="Detect oversized ORG documents and monolithic headline-less sections")
    p_scan.add_argument("--roots", nargs="+", default=["docs"], help="Relative directories or files to scan")
    p_scan.add_argument("--max-lines", type=int, default=DEFAULT_MAX_LINES)
    p_scan.add_argument("--json", action="store_true")
    p_scan.add_argument("--fail-on-unmodularized", action="store_true")
    p_scan.set_defaults(func=cmd_scan)

    p_pkt = sub.add_parser("packet", help="Export L0/L1 AST + coupling packet for ASCENT planning")
    p_pkt.add_argument("org_file", type=str)
    p_pkt.add_argument("--max-lines", type=int, default=DEFAULT_MAX_LINES)
    p_pkt.add_argument("--output", type=Path, default=None)
    p_pkt.set_defaults(func=cmd_packet)

    p_read = sub.add_parser("read-section", help="On-demand L2/L3 progressive disclosure reader")
    p_read.add_argument("org_file", type=str)
    p_read.add_argument("--section-id", type=str, default=None)
    p_read.add_argument("--start-line", type=int, default=None)
    p_read.add_argument("--end-line", type=int, default=None)
    p_read.add_argument("--max-span", type=int, default=120)
    p_read.set_defaults(func=cmd_read_section)

    p_plan = sub.add_parser("plan", help="Generate and evaluate competing ASCENT modularization branches")
    p_plan.add_argument("org_file", type=str)
    p_plan.add_argument("--max-lines", type=int, default=DEFAULT_MAX_LINES)
    p_plan.add_argument("--propose-branch", type=Path, default=None, help="Optional JSON file defining an investigator/ASCENT-proposed branch")
    p_plan.add_argument("--output", type=Path, default=None)
    p_plan.add_argument("--json", action="store_true")
    p_plan.set_defaults(func=cmd_plan)

    p_apply = sub.add_parser("apply", help="Apply an explicitly approved modularization branch and run post-split verification")
    p_apply.add_argument("plan_json", type=Path)
    p_apply.add_argument("--branch", type=str, required=True)
    p_apply.add_argument("--approve-plan-sha256", type=str, required=True)
    p_apply.add_argument("--dry-run", action="store_true")
    p_apply.add_argument("--rewrite-inbound", action="store_true")
    p_apply.set_defaults(func=cmd_apply)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
