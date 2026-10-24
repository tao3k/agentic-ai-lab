#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Qualify Agentic AI Lab as a clean external Bzlmod consumer without shell logic."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


class ExternalModuleError(RuntimeError):
    pass


@dataclass(frozen=True)
class ExternalModuleConfig:
    bazel_command: tuple[str, ...]
    mode: str
    output_base: Path | None = None
    keep_root: bool = False

    def validate(self) -> None:
        if self.mode not in {"analysis", "full"}:
            raise ExternalModuleError(
                f"unsupported external-module test mode: {self.mode}"
            )
        if not self.bazel_command:
            raise ExternalModuleError("Bazel command is empty")
        if self.output_base is not None and not self.output_base.is_absolute():
            raise ExternalModuleError(
                f"AGENTIC_AI_LAB_EXTERNAL_BAZEL_OUTPUT_BASE must be an absolute path: {self.output_base}"
            )


def _tracked_paths(repo_root: Path) -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=repo_root,
        check=True,
        capture_output=True,
    )
    return [Path(value.decode()) for value in result.stdout.split(b"\0") if value]


def _export_tracked_tree(repo_root: Path, destination: Path) -> None:
    for relative in _tracked_paths(repo_root):
        source = repo_root / relative
        target = destination / relative
        if source.is_dir() and not source.is_symlink():
            target.mkdir(parents=True, exist_ok=True)
            if relative == Path("core"):
                if not (source / ".git").exists():
                    raise ExternalModuleError("Core submodule is not initialized")
                _export_tracked_tree(source, target)
            continue
        if not source.exists() and not source.is_symlink():
            # A local qualification run projects the current working tree, so
            # index entries deleted by the pending change are intentionally absent.
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target, follow_symlinks=False)


def _write_consumer_module(
    consumer: Path, exported: Path, include_override: bool
) -> None:
    module = (
        'module(name = "agentic_ai_lab_external_consumer", version = "0.0.0")\n\n'
        'bazel_dep(name = "agentic_ai_lab", version = "0.1.0")\n'
        f'local_path_override(module_name = "agentic_ai_lab", path = "{exported}")\n'
    )
    if include_override:
        module += (exported / "gerbil-bazel.MODULE.bazel").read_text(encoding="utf-8")
    (consumer / "MODULE.bazel").write_text(module, encoding="utf-8")


def _run_bazel(
    config: ExternalModuleConfig,
    consumer: Path,
    tmpdir: Path,
    output_args: list[str],
    args: list[str],
    *,
    capture_output: bool = False,
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["TMPDIR"] = str(tmpdir)
    return subprocess.run(
        [*config.bazel_command, *output_args, *args],
        cwd=consumer,
        env=environment,
        text=True,
        capture_output=capture_output,
        check=False,
    )


def run_external_module(
    repo_root: Path, config: ExternalModuleConfig
) -> dict[str, object]:
    config.validate()
    if config.output_base is not None:
        config.output_base.mkdir(parents=True, exist_ok=True)

    temporary = (
        None
        if config.keep_root
        else tempfile.TemporaryDirectory(prefix="agentic-ai-lab-external-")
    )
    test_root = (
        Path(tempfile.mkdtemp(prefix="agentic-ai-lab-external-"))
        if temporary is None
        else Path(temporary.name)
    )
    try:
        exported = test_root / "agentic-ai-lab"
        consumer = test_root / "consumer"
        bazel_tmp = test_root / "tmp"
        exported.mkdir()
        consumer.mkdir()
        bazel_tmp.mkdir()
        _export_tracked_tree(repo_root, exported)
        if (exported / ".gerbil").exists():
            raise ExternalModuleError(
                "external Agentic AI Lab export unexpectedly contains .gerbil"
            )

        _write_consumer_module(consumer, exported, include_override=False)
        missing_override = _run_bazel(
            config,
            consumer,
            bazel_tmp,
            [f"--output_user_root={test_root / 'bazel-no-root-override'}"],
            ["query", "--lockfile_mode=off", "@agentic_ai_lab//:compile"],
            capture_output=True,
        )
        if missing_override.returncode == 0:
            raise ExternalModuleError(
                "external Agentic AI Lab consumer unexpectedly succeeded without a root gerbil_bazel override"
            )
        print(
            "external module requires root gerbil_bazel override until the source-package API is released",
            file=sys.stderr,
        )

        _write_consumer_module(consumer, exported, include_override=True)
        (consumer / "BUILD.bazel").write_text(
            'alias(\n    name = "agentic_ai_lab_compile",\n    actual = "@agentic_ai_lab//:compile",\n)\n',
            encoding="utf-8",
        )
        output_args = (
            [f"--output_base={config.output_base}"]
            if config.output_base is not None
            else [f"--output_user_root={test_root / 'bazel'}"]
        )
        query = _run_bazel(
            config,
            consumer,
            bazel_tmp,
            output_args,
            ["query", "--lockfile_mode=off", "@agentic_ai_lab//:compile"],
        )
        if query.returncode != 0:
            raise ExternalModuleError(
                f"external Bazel query failed with status {query.returncode}"
            )
        build_args = ["build", "--jobs=2"]
        if config.mode == "analysis":
            build_args.append("--nobuild")
        build_args.extend(["--lockfile_mode=off", "//:agentic_ai_lab_compile"])
        build = _run_bazel(config, consumer, bazel_tmp, output_args, build_args)
        if build.returncode != 0:
            raise ExternalModuleError(
                f"external Bazel build failed with status {build.returncode}"
            )

        return {
            "schema": "agentic-ai-lab.external-bazel-module.v1",
            "mode": config.mode,
            "ambientGerbil": False,
            "configured": True,
            "requiresRootGerbilBazelOverride": True,
            "compiled": config.mode == "full",
            "receiptOwner": "gerbil-bazel",
            "agenticAiLabReceiptValidator": False,
        }
    finally:
        if temporary is not None:
            temporary.cleanup()
        elif config.keep_root:
            print(f"preserved external-module test root: {test_root}", file=sys.stderr)


def config_from_environment() -> ExternalModuleConfig:
    bazel = tuple(shlex.split(os.environ.get("BAZEL", "bazelisk")))
    output_base_value = os.environ.get("AGENTIC_AI_LAB_EXTERNAL_BAZEL_OUTPUT_BASE")
    return ExternalModuleConfig(
        bazel_command=bazel,
        mode=os.environ.get("AGENTIC_AI_LAB_EXTERNAL_TEST_MODE", "full"),
        output_base=Path(output_base_value) if output_base_value else None,
        keep_root=os.environ.get("AGENTIC_AI_LAB_EXTERNAL_TEST_KEEP_ROOT") == "1",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parents[3]
    )
    args = parser.parse_args()
    try:
        receipt = run_external_module(
            args.repo_root.resolve(), config_from_environment()
        )
    except ExternalModuleError as error:
        print(str(error), file=sys.stderr)
        return (
            2
            if "unsupported" in str(error) or "must be an absolute" in str(error)
            else 1
        )
    print(json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
