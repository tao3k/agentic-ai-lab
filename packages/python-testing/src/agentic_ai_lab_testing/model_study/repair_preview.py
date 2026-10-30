# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Own the exact model payload preview and committed-head validation."""

from __future__ import annotations

import hashlib
import shutil
import subprocess
from pathlib import Path

from .repair_native import SCHEME_SOURCE_DIR, scheme_env
from .runner import source_head

MODEL = "deepseek-flash"
TASK = "repair_task.ss"
CONTROLS = ("control_pure", "control_contract")


def native_control(script: Path, poo_root: Path, ascent_root: Path,
                   gerbil_path: Path) -> str:
    result = subprocess.run(
        ["gerbil", "-:max-heap=1G,debug=q", "env", "gxi", str(script)],
        cwd=poo_root, env=scheme_env(ascent_root, gerbil_path),
        text=True, capture_output=True, timeout=90, check=True,
    )
    lines = [line for line in result.stdout.splitlines() if line.startswith("(")]
    if len(lines) != 1:
        raise RuntimeError(f"native Scheme control emitted {len(lines)} data lines")
    return lines[0] + "\n"


def repair_payload(task: str, candidate: str, receipt: str) -> str:
    return (task + "\n;;; Native tool feedback; one repair turn only.\n"
            + f"(def prior-candidate '{candidate})\n"
            + f"(def native-receipt '{receipt})\n"
            + ";;; Return one corrected (candidate ...) datum.\n")


def syntax_payload(task: str) -> str:
    return (task + "\n;;; Native reader rejected the first output's"
            " candidate syntax. Return one (candidate ...) datum.\n")


def preview(directory: Path, poo_root: Path, ascent_root: Path,
            gerbil_path: Path, repair_only: bool = False) -> None:
    if directory.exists():
        raise FileExistsError(directory)
    if directory.resolve().is_relative_to(poo_root.resolve()):
        raise ValueError("preview must stay outside the repository")
    directory.mkdir(parents=True)
    source = SCHEME_SOURCE_DIR / TASK
    shutil.copyfile(source, directory / TASK)
    if not repair_only:
        expected_dir = directory / "expected"
        expected_dir.mkdir()
        control_digests = []
        for name in CONTROLS:
            control = SCHEME_SOURCE_DIR / f"{name}.ss"
            shutil.copyfile(control, directory / control.name)
            (expected_dir / f"{name}.sexp").write_text(
                native_control(control, poo_root, ascent_root, gerbil_path),
                encoding="utf-8",
            )
            control_digests.append(
                f"{name}\t{hashlib.sha256(control.read_bytes()).hexdigest()}\n"
            )
        (directory / "controls.tsv").write_text(
            "name\tpayload_sha256\n" + "".join(control_digests),
            encoding="utf-8",
        )
    task = source.read_text(encoding="utf-8")
    (directory / "repair-template.ss").write_text(
        repair_payload(task, "<candidate-from-first-call>",
                       "<native-receipt-from-tool>"), encoding="utf-8",
    )
    (directory / "syntax-template.ss").write_text(
        syntax_payload(task), encoding="utf-8",
    )
    (directory / "manifest.tsv").write_text(
        "payload_sha256\tascent_head\tpoo_head\tmodel\tmax_calls\n"
        f"{hashlib.sha256(source.read_bytes()).hexdigest()}\t"
        f"{source_head(ascent_root)}\t{source_head(poo_root)}\t{MODEL}\t"
        f"{2 if repair_only else 4}\n",
        encoding="utf-8",
    )


def validate_preview(directory: Path, poo_root: Path, ascent_root: Path,
                     gerbil_path: Path, repair_only: bool) -> str:
    header, row = (directory / "manifest.tsv").read_text(
        encoding="utf-8").splitlines()
    if header != "payload_sha256\tascent_head\tpoo_head\tmodel\tmax_calls":
        raise RuntimeError("preview manifest changed")
    digest, ascent_head, poo_head, model, max_calls = row.split("\t")
    payload = (directory / TASK).read_text(encoding="utf-8")
    if (hashlib.sha256(payload.encode()).hexdigest() != digest
            or payload != (SCHEME_SOURCE_DIR / TASK).read_text(encoding="utf-8")
            or ascent_head != source_head(ascent_root)
            or poo_head != source_head(poo_root)
            or model != MODEL
            or max_calls != ("2" if repair_only else "4")):
        raise RuntimeError("preview no longer matches committed source and heads")
    if ((directory / "repair-template.ss").read_text(encoding="utf-8")
            != repair_payload(payload, "<candidate-from-first-call>",
                              "<native-receipt-from-tool>")
            or (directory / "syntax-template.ss").read_text(
                encoding="utf-8") != syntax_payload(payload)):
        raise RuntimeError("repair preview changed")
    if repair_only:
        if (directory / "controls.tsv").exists():
            raise RuntimeError("repair-only preview unexpectedly has controls")
    else:
        control_rows = (directory / "controls.tsv").read_text(
            encoding="utf-8").splitlines()
        if (len(control_rows) != len(CONTROLS) + 1
                or control_rows[0] != "name\tpayload_sha256"):
            raise RuntimeError("control manifest changed")
        for name, row in zip(CONTROLS, control_rows[1:], strict=True):
            actual_name, control_digest = row.split("\t")
            control = (directory / f"{name}.ss").read_bytes()
            if (actual_name != name
                    or hashlib.sha256(control).hexdigest() != control_digest
                    or control != (SCHEME_SOURCE_DIR / f"{name}.ss").read_bytes()
                    or (directory / "expected" / f"{name}.sexp").read_text(
                        encoding="utf-8") != native_control(
                            SCHEME_SOURCE_DIR / f"{name}.ss", poo_root,
                            ascent_root, gerbil_path)):
                raise RuntimeError("control preview changed")
    return payload
