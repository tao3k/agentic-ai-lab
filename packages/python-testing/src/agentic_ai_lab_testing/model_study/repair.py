# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Preview and run one Scheme candidate, native receipt, and repair turn."""

from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path

from ..ascent.candidate import candidate_text
from ..ascent.live import key_from_file
from .protocol import require_clean, require_pinned_ascent
from .repair_native import NativeTool, control_score, score
from .repair_preview import (
    CONTROLS, MODEL, TASK, preview, repair_payload, syntax_payload,
    validate_preview,
)
from .reporting import report_json
from .scheme import readable_answer

def live(directory: Path, output: Path, poo_root: Path, ascent_root: Path,
         gerbil_path: Path, api_key: str, repair_only: bool = False) -> None:
    from openai import OpenAI

    require_clean(poo_root)
    require_clean(ascent_root)
    require_pinned_ascent(ascent_root, poo_root)
    if output.exists():
        raise FileExistsError(output)
    if output.resolve().is_relative_to(poo_root.resolve()):
        raise ValueError("raw output must stay outside the repository")
    payload = validate_preview(directory, poo_root, ascent_root,
                               gerbil_path, repair_only)
    output.mkdir(parents=True)
    client = OpenAI(api_key=api_key, base_url="https://api.deepseek.com",
                    max_retries=0, timeout=45.0)
    records: list[dict[str, object]] = []
    try:
        for name in (() if repair_only else CONTROLS):
            control_payload = (directory / f"{name}.ss").read_text(
                encoding="utf-8")
            started = time.perf_counter()
            response = client.responses.create(
                model=MODEL, input=[{"role": "user", "content": control_payload}],
                reasoning={"effort": "none"}, temperature=0,
                max_output_tokens=512,
            )
            raw = response.output_text
            answer = output / f"{name}.sexp"
            answer.write_text(raw, encoding="utf-8")
            verdict = "(score (valid #f) (correct #f))"
            if response.status == "completed" and readable_answer(raw):
                verdict = control_score(
                    directory / "expected" / f"{name}.sexp", answer,
                    poo_root, ascent_root, gerbil_path,
                )
            records.append({"case": name, "response_id": response.id,
                            "status": response.status, "native_score": verdict,
                            "seconds": round(time.perf_counter() - started, 3)})
        tool = NativeTool(poo_root, ascent_root, gerbil_path)
        try:
            run_repair(tool, client, directory, output, poo_root,
                       ascent_root, gerbil_path, records, payload)
        finally:
            tool.close()
    finally:
        (output / "manifest.json").write_text(
            json.dumps(records, indent=2) + "\n", encoding="utf-8",
        )


def run_repair(tool: NativeTool, client: object, directory: Path, output: Path,
               poo_root: Path, ascent_root: Path, gerbil_path: Path,
               records: list[dict[str, object]], payload: str) -> None:
    for turn in (1, 2):
        started = time.perf_counter()
        response = client.responses.create(
            model=MODEL, input=[{"role": "user", "content": payload}],
            reasoning={"effort": "none"}, temperature=0,
            max_output_tokens=1024,
        )
        raw = response.output_text
        (output / f"candidate-{turn}.sexp").write_text(raw, encoding="utf-8")
        candidate = candidate_text(raw) if response.status == "completed" else None
        if candidate is None:
            records.append({"case": "repair", "turn": turn,
                            "response_id": response.id,
                            "status": response.status, "syntax": False,
                            "seconds": round(time.perf_counter() - started, 3)})
            if turn == 1:
                payload = syntax_payload(
                    (directory / TASK).read_text(encoding="utf-8"))
            continue
        receipt = tool.attempt(candidate)
        native_ns = tool.last_native_ns
        receipt_path = output / f"receipt-{turn}.sexp"
        receipt_path.write_text(receipt, encoding="utf-8")
        verdict = score(receipt_path, poo_root, ascent_root, gerbil_path)
        records.append({"case": "repair", "turn": turn,
                        "response_id": response.id,
                        "status": response.status, "syntax": True,
                        "native_score": verdict,
                        "native_seconds": round(native_ns / 1e9, 3)
                        if native_ns is not None else None,
                        "seconds": round(time.perf_counter() - started, 3)})
        if verdict == "(score (exact #t))":
            break
        payload = repair_payload(
            (directory / TASK).read_text(encoding="utf-8"),
            candidate, receipt.strip(),
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--poo-root", type=Path, required=True)
    parser.add_argument("--ascent-root", type=Path, required=True)
    parser.add_argument("--gerbil-path", type=Path, required=True)
    parser.add_argument("--preview-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--repair-only", action="store_true",
                        help="reuse the already scored control calls")
    args = parser.parse_args()
    if args.output_dir is None:
        preview(args.preview_dir, args.poo_root, args.ascent_root,
                args.gerbil_path, args.repair_only)
        report_json({"preview": str(args.preview_dir),
                     "max_calls": 2 if args.repair_only else 4})
        return 0
    api_key = os.environ.get("DEEPSEEK_API_KEY") or (
        key_from_file(args.env_file) if args.env_file else ""
    )
    if not api_key:
        parser.error("DEEPSEEK_API_KEY or --env-file is required")
    live(args.preview_dir, args.output_dir, args.poo_root,
         args.ascent_root, args.gerbil_path, api_key, args.repair_only)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
