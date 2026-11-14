# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Gerbil AOT executable cache for Scheme runtime projection rows."""

from __future__ import annotations

import hashlib
import os
import subprocess
from pathlib import Path
from typing import NamedTuple


class SchemeAotArtifact(NamedTuple):
    source: Path
    binary: Path


def scheme_load_aot_enabled() -> bool:
    value = os.environ.get("AGENTIC_AI_LAB_SCHEME_LOAD_AOT", "1").strip().lower()
    return value not in {"0", "false", "no", "off"}


def scheme_load_aot_compile_enabled() -> bool:
    value = os.environ.get("AGENTIC_AI_LAB_SCHEME_LOAD_AOT_COMPILE", "0").strip().lower()
    return value in {"1", "true", "yes", "on"}


def scheme_aot_artifact(
    workdir: Path,
    cache_key: tuple[object, ...],
) -> SchemeAotArtifact:
    digest = _scheme_aot_digest(cache_key)
    artifact_dir = workdir / ".cache" / "agentic-ai-lab-runtime-aot" / digest[:2] / digest
    return SchemeAotArtifact(
        source=artifact_dir / "projection-runner.ss",
        binary=artifact_dir / "projection-runner",
    )


def run_aot_projection(
    workdir: Path,
    cache_key: tuple[object, ...],
) -> subprocess.CompletedProcess[str] | None:
    artifact = scheme_aot_artifact(workdir, cache_key)
    if not artifact.binary.exists():
        return None
    return subprocess.run(
        (str(artifact.binary),),
        cwd=workdir,
        env=_scheme_aot_env(workdir),
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def build_aot_projection(
    workdir: Path,
    cache_key: tuple[object, ...],
    runner_source: str,
) -> SchemeAotArtifact:
    artifact = scheme_aot_artifact(workdir, cache_key)
    artifact.source.parent.mkdir(parents=True, exist_ok=True)
    artifact.source.write_text(runner_source, encoding="utf-8")
    _compile_aot_projection(workdir, artifact)
    return artifact


def _compile_aot_projection(
    workdir: Path,
    artifact: SchemeAotArtifact,
) -> None:
    failures: list[str] = []
    for command in _scheme_aot_compile_commands(workdir, artifact):
        try:
            subprocess.run(
                command.argv,
                cwd=workdir,
                env=command.env,
                check=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            return
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or exc.stdout or "").strip()
            failures.append(f"{' '.join(command.argv[:3])}: {detail}")
    raise RuntimeError(f"Scheme AOT compile failed: {'; '.join(failures)}")


class _SchemeAotCommand(NamedTuple):
    argv: tuple[str, ...]
    env: dict[str, str] | None


def _scheme_aot_compile_commands(
    workdir: Path,
    artifact: SchemeAotArtifact,
) -> tuple[_SchemeAotCommand, ...]:
    direct_env = _direct_gerbil_env(workdir)
    fallback = _SchemeAotCommand(
        ("gxpkg", "env", "gxc", "-exe", "-o", str(artifact.binary), str(artifact.source)),
        None,
    )
    if direct_env is None:
        return (fallback,)
    direct = _SchemeAotCommand(
        ("gxc", "-exe", "-o", str(artifact.binary), str(artifact.source)),
        direct_env,
    )
    return (direct, fallback)


def _scheme_aot_env(workdir: Path) -> dict[str, str]:
    return _direct_gerbil_env(workdir) or dict(os.environ)


def _direct_gerbil_env(workdir: Path) -> dict[str, str] | None:
    gerbil_path = workdir / ".gerbil"
    if not (gerbil_path / "lib" / "agentic-ai-lab").exists():
        return None
    env = dict(os.environ)
    env["GERBIL_PATH"] = str(gerbil_path)
    env["PATH"] = f"{gerbil_path / 'bin'}:{env.get('PATH', '')}"
    return env


def _scheme_aot_digest(cache_key: tuple[object, ...]) -> str:
    return hashlib.sha256(repr(cache_key).encode("utf-8")).hexdigest()


__all__ = [
    "build_aot_projection",
    "run_aot_projection",
    "scheme_aot_artifact",
    "scheme_load_aot_compile_enabled",
    "scheme_load_aot_enabled",
]
