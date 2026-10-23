# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Compare candidate self-review with bounded ASCENT feedback (four calls)."""

from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path

from ..ascent.candidate import candidate_text
from ..ascent.live import key_from_file
from .reporting import report_json
from .archive import require_archive, seal
from .support_native import observe, score
from .support_protocol import SETTINGS, TRANSPORT, digest, preview, validate


def call(client, messages: list[dict], output: Path, name: str):
    record = {"input": messages, "settings": SETTINGS,
              "request_sha256": digest(json.dumps(messages, sort_keys=True).encode())}
    started = time.perf_counter()
    try:
        response = client.responses.create(input=messages, **SETTINGS)
    except Exception as error:
        record.update(error_type=type(error).__name__, seconds=time.perf_counter() - started)
        (output / f"{name}.json").write_text(json.dumps(record, sort_keys=True, indent=2) + "\n")
        raise RuntimeError(f"model call failed: {type(error).__name__}") from None
    record.update(seconds=time.perf_counter() - started,
                  response=response.model_dump(mode="json"))
    (output / f"{name}.json").write_text(json.dumps(record, sort_keys=True, indent=2) + "\n")
    (output / f"{name}.txt").write_text(response.output_text)
    return response


def inert_output(response) -> str | None:
    if response.status != "completed":
        return None
    text = candidate_text(response.output_text)
    return text if text == response.output_text.strip() else None


def run(client, files: dict[str, str], ascent: Path, gerbil_path: Path, output: Path) -> dict:
    results = {}
    for arm in ("self", "native"):
        messages = [{"role": "user", "content": files["initial.txt"]}]
        first = call(client, messages, output, f"{arm}.1")
        review = files["self_review.txt"]
        if arm == "native":
            proposal = inert_output(first)
            observation = (observe(ascent, gerbil_path, proposal, initial=True)
                           if proposal is not None else "invalid-model-output")
            (output / "native.initial.tsv").write_text(observation)
            review = files["native_review.txt"].format(observation=observation)
        messages = [*messages, {"role": "assistant", "content": first.output_text},
                    {"role": "user", "content": review}]
        final = call(client, messages, output, f"{arm}.2")
        proposal = inert_output(final)
        results[arm] = {"response_completed": final.status == "completed",
                        "candidate_readable": proposal is not None}
        if proposal is None:
            results[arm].update(correct=False, reason="invalid-model-output")
        else:
            observed = observe(ascent, gerbil_path, proposal)
            (output / f"{arm}.final.tsv").write_text(observed)
            results[arm].update(score(observed, files["reference.tsv"]))
        (output / "scores.json").write_text(json.dumps(results, sort_keys=True, indent=2) + "\n")
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ascent-root", type=Path, required=True)
    parser.add_argument("--poo-root", type=Path, required=True)
    parser.add_argument("--gerbil-path", type=Path, required=True)
    parser.add_argument("--preview-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--approved-manifest-sha256")
    parser.add_argument("--env-file", type=Path)
    parser.add_argument("--archive-dir", type=Path)
    args = parser.parse_args()
    if args.output_dir is None:
        report_json(preview(args.preview_dir, args.ascent_root, args.poo_root, args.gerbil_path))
        return 0
    manifest = (args.preview_dir / "manifest.json").read_bytes()
    if digest(manifest) != args.approved_manifest_sha256:
        parser.error("live run requires the approved preview manifest SHA256")
    files = validate(args.preview_dir, args.ascent_root, args.poo_root)
    if (args.output_dir.exists() or args.output_dir.resolve().is_relative_to(args.poo_root.resolve())
            or args.output_dir.resolve().is_relative_to(args.ascent_root.resolve())):
        parser.error("raw results require a new external directory")
    if args.archive_dir is None:
        parser.error("live runs require a durable --archive-dir")
    require_archive(args.archive_dir, args.preview_dir, args.output_dir)
    key = os.environ.get("DEEPSEEK_API_KEY") or (key_from_file(args.env_file) if args.env_file else "")
    if not key:
        parser.error("DEEPSEEK_API_KEY or --env-file is required for a live run")
    from openai import OpenAI

    client = OpenAI(api_key=key, **TRANSPORT)
    args.output_dir.mkdir(parents=True)
    (args.output_dir / "preview-manifest.json").write_bytes(manifest)
    try:
        result = run(client, files, args.ascent_root, args.gerbil_path, args.output_dir)
    except Exception:
        seal(args.preview_dir, args.output_dir, args.archive_dir, outcome="failed")
        raise
    seal(args.preview_dir, args.output_dir, args.archive_dir, outcome="completed")
    report_json(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
