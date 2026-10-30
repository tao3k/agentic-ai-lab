# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Ask a model bounded questions about existing ASCENT Scheme modules."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import time
from pathlib import Path

from ..ascent.live import key_from_file
from .protocol import require_clean, require_pinned_ascent
from .reporting import report_json
from .runner import source_head

HERE = Path(__file__).resolve().parent
QUESTIONS = HERE / "scheme_questions.json"
ANSWER_ALPHABET = re.compile(r"[()\s0-9A-Za-z?-]+\Z")
MODEL = "deepseek-flash"


def questions() -> list[dict[str, str]]:
    items = json.loads(QUESTIONS.read_text(encoding="utf-8"))
    if not items or len({item["id"] for item in items}) != len(items):
        raise ValueError("questions need distinct identifiers")
    for item in items:
        source = Path(item["source"])
        if (not re.fullmatch(r"[a-z0-9_]+", item["id"])
                or source.is_absolute() or ".." in source.parts
                or source.suffix != ".ss" or not readable_answer(item["answer"])):
            raise ValueError(f"invalid question contract: {item['id']}")
    return items


def payload(item: dict[str, str], ascent_root: Path) -> bytes:
    source = item["source"]
    module = (ascent_root / source).read_bytes()
    return (f";;; ASCENT Scheme source: {source}\n".encode()
            + module + b"\n\nQuestion: " + item["question"].encode()
            + b"\nReturn exactly one (answer ...) S-expression. "
              b"Do not explain or use Markdown.\n")


def preview(preview_dir: Path, ascent_root: Path, poo_root: Path) -> dict[str, str]:
    if preview_dir.exists():
        raise FileExistsError(preview_dir)
    if preview_dir.resolve().is_relative_to(poo_root.resolve()):
        raise ValueError("study preview must stay outside the repository")
    preview_dir.mkdir(parents=True)
    expected_dir = preview_dir / "expected"
    expected_dir.mkdir()
    digests = {}
    rows = []
    for item in questions():
        case = item["id"]
        outgoing = payload(item, ascent_root)
        answer = item["answer"].encode() + b"\n"
        (preview_dir / f"{case}.txt").write_bytes(outgoing)
        (expected_dir / f"{case}.sexp").write_bytes(answer)
        digest = hashlib.sha256(outgoing).hexdigest()
        digests[case] = digest
        rows.append(f"{case}\t{digest}\t{hashlib.sha256(answer).hexdigest()}\t"
                    f"{source_head(ascent_root)}\t{source_head(poo_root)}\t"
                    f"{MODEL}\t1\n")
    (preview_dir / "manifest.tsv").write_text(
        "case\tpayload_sha256\texpected_sha256\tascent_head\t"
        "poo_head\tmodel\trepeats\n" + "".join(rows), encoding="utf-8",
    )
    return digests


def readable_answer(raw: str) -> bool:
    if len(raw) > 2048 or not ANSWER_ALPHABET.fullmatch(raw):
        return False
    depth = 0
    for character in raw:
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth < 0:
                return False
    return depth == 0


def live(preview_dir: Path, output_dir: Path, ascent_root: Path, poo_root: Path,
         api_key: str) -> None:
    from openai import OpenAI

    require_clean(ascent_root)
    require_clean(poo_root)
    require_pinned_ascent(ascent_root, poo_root)
    if output_dir.exists():
        raise FileExistsError(output_dir)
    if output_dir.resolve().is_relative_to(poo_root.resolve()):
        raise ValueError("raw responses must stay outside the repository")
    items = questions()
    preview_rows = (preview_dir / "manifest.tsv").read_text(encoding="utf-8").splitlines()
    if len(preview_rows) != len(items) + 1:
        raise RuntimeError("preview manifest has unexpected case count")
    for item, row in zip(items, preview_rows[1:], strict=True):
        name, digest, expected_digest, ascent_head, poo_head, model, count = row.split("\t")
        case = item["id"]
        outgoing = (preview_dir / f"{case}.txt").read_bytes()
        expected = (preview_dir / "expected" / f"{case}.sexp").read_bytes()
        if (name != case or hashlib.sha256(outgoing).hexdigest() != digest
                or hashlib.sha256(expected).hexdigest() != expected_digest
                or outgoing != payload(item, ascent_root)
                or expected != item["answer"].encode() + b"\n"
                or ascent_head != source_head(ascent_root)
                or poo_head != source_head(poo_root)
                or model != MODEL or count != "1"):
            raise RuntimeError("preview no longer matches question source and heads")
    output_dir.mkdir(parents=True)
    client = OpenAI(api_key=api_key, base_url="https://api.deepseek.com",
                    max_retries=0, timeout=45.0)
    manifest = output_dir / "manifest.tsv"
    manifest.write_text("case\tstatus\tvalid\tcorrect\tseconds\tresponse_id\n",
                        encoding="utf-8")
    for item in items:
        case = item["id"]
        outgoing = (preview_dir / f"{case}.txt").read_text(encoding="utf-8")
        started = time.perf_counter()
        response = client.responses.create(
            model=MODEL, input=[{"role": "user", "content": outgoing}],
            reasoning={"effort": "none"}, temperature=0,
            max_output_tokens=512,
        )
        seconds = round(time.perf_counter() - started, 3)
        raw = response.output_text
        (output_dir / f"{case}.sexp").write_text(raw, encoding="utf-8")
        valid = response.status == "completed" and readable_answer(raw)
        correct = valid and raw.strip() == item["answer"]
        with manifest.open("a", encoding="utf-8") as file:
            file.write(f"{case}\t{response.status}\t{str(valid).lower()}\t"
                       f"{str(correct).lower()}\t{seconds}\t{response.id}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ascent-root", type=Path, required=True)
    parser.add_argument("--poo-root", type=Path, required=True)
    parser.add_argument("--preview-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--env-file", type=Path)
    args = parser.parse_args()
    if args.output_dir is None:
        report_json(preview(args.preview_dir, args.ascent_root, args.poo_root))
        return 0
    api_key = os.environ.get("DEEPSEEK_API_KEY") or (
        key_from_file(args.env_file) if args.env_file else ""
    )
    if not api_key:
        parser.error("DEEPSEEK_API_KEY or --env-file is required for a live run")
    live(args.preview_dir, args.output_dir, args.ascent_root, args.poo_root, api_key)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
