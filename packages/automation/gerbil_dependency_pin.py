#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Project native Gerbil dependency pins into Bazel declarations and locks.

``gerbil.pkg`` and ``dev/gerbil.pkg`` own production and optional development
pins respectively. This tool does not resolve dependencies; gxpkg and Bazel retain
that responsibility.  It only updates and checks the equivalent Bazel source
projection required by isolated builds.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import re
import subprocess
import sys
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BAZEL_SOURCES = ROOT / "gerbil-dependencies.MODULE.bazel"
BAZEL_LOCK = ROOT / "MODULE.bazel.lock"
REVISION = re.compile(r"(?:[0-9a-f]{40}|v\d+(?:\.\d+)+)")
EXTENSION_ID = "@@gerbil_bazel+//gerbil:extensions.bzl%gerbil"
SOURCE_PACKAGE_RULE = (
    "@@gerbil_bazel+//gerbil:source_package_repository.bzl%source_package_repository"
)


def locked_source_package_names(generated: dict[str, object]) -> set[str]:
    return {
        name
        for name, specification in generated.items()
        if specification.get("repoRuleId") == SOURCE_PACKAGE_RULE
    }


def parse_package_pins(text: str) -> dict[str, tuple[str, str]]:
    pins: dict[str, tuple[str, str]] = {}
    pattern = re.compile(
        r'"(?P<repository>github\.com/[^/@\s]+/(?P<package>[^/@\s]+))'
        r'@(?P<revision>[0-9a-f]{40}|v\d+(?:\.\d+)+)"'
    )
    for match in pattern.finditer(text):
        package = match.group("package")
        if package in pins:
            raise ValueError(f"gerbil.pkg repeats direct dependency {package!r}")
        pins[package] = (match.group("repository"), match.group("revision"))
    return pins


def package_pin_owners(root: Path) -> dict[str, tuple[Path, tuple[str, str]]]:
    owners: dict[str, tuple[Path, tuple[str, str]]] = {}
    for relative in ("gerbil.pkg", "dev/gerbil.pkg"):
        path = root / relative
        if not path.exists():
            continue
        for package, pin in parse_package_pins(path.read_text(encoding="utf-8")).items():
            if package in owners:
                raise ValueError(f"duplicate dependency authority for {package!r}")
            owners[package] = (path, pin)
    return owners


def source_block(text: str, repository_name: str) -> tuple[re.Match[str], str]:
    pattern = re.compile(
        r"gerbil_dependency_sources\.source_package\(\n"
        r"(?P<body>.*?^\)\n)",
        re.MULTILINE | re.DOTALL,
    )
    for match in pattern.finditer(text):
        body = match.group("body")
        if re.search(rf'^    name = "{re.escape(repository_name)}",$', body, re.MULTILINE):
            return match, body
    raise ValueError(f"Bazel source declaration {repository_name!r} is absent")


def direct_source_repositories(text: str) -> dict[str, str]:
    repositories: dict[str, str] = {}
    pattern = re.compile(
        r"gerbil_dependency_sources\.source_package\(\n"
        r"(?P<body>.*?^\)\n)",
        re.MULTILINE | re.DOTALL,
    )
    for match in pattern.finditer(text):
        body = match.group("body")
        name = field(body, "name")
        package = field(body, "package")
        if package in repositories:
            raise ValueError(f"Bazel repeats source package {package!r}")
        repositories[package] = name
    return repositories


def field(body: str, name: str) -> str:
    match = re.search(rf'^    {re.escape(name)} = "([^"]*)",$', body, re.MULTILINE)
    if match is None:
        raise ValueError(f"Bazel source field {name!r} is absent")
    return match.group(1)


def expected_projection(repository: str, package: str, revision: str) -> dict[str, object]:
    canonical_uri = f"https://{repository}"
    archive_revision = revision[1:] if revision.startswith("v") else revision
    return {
        "canonical_uri": canonical_uri,
        "package": package,
        "revision": revision,
        "strip_prefix": f"{package}-{archive_revision}",
        "urls": [f"{canonical_uri}/archive/{revision}.tar.gz"],
    }


def declared_projection(text: str, repository_name: str) -> dict[str, object]:
    _match, body = source_block(text, repository_name)
    url_match = re.search(r'^        "([^"]+)",$', body, re.MULTILINE)
    if url_match is None:
        raise ValueError(f"Bazel source URL for {repository_name!r} is absent")
    return {
        "canonical_uri": field(body, "canonical_uri"),
        "package": field(body, "package"),
        "revision": field(body, "revision"),
        "sha256": field(body, "sha256"),
        "strip_prefix": field(body, "strip_prefix"),
        "urls": [url_match.group(1)],
    }


def collect_errors(root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    sources_text = (root / "gerbil-dependencies.MODULE.bazel").read_text(encoding="utf-8")
    lock = json.loads((root / "MODULE.bazel.lock").read_text(encoding="utf-8"))
    pins = {package: pin for package, (_path, pin) in package_pin_owners(root).items()}
    repositories = direct_source_repositories(sources_text)
    declared_repository_names = set(repositories.values())
    extension = lock.get("moduleExtensions", {}).get(EXTENSION_ID, {})

    for platform_key, platform_lock in extension.items():
        generated = platform_lock.get("generatedRepoSpecs", {})
        stale = locked_source_package_names(generated) - declared_repository_names
        for repository_name in sorted(stale):
            errors.append(f"{platform_key}: undeclared lock source {repository_name!r}")

    for package, (repository, revision) in pins.items():
        repository_name = repositories.get(package)
        if repository_name is None:
            errors.append(f"Bazel source projection for direct dependency {package!r} is absent")
            continue
        expected = expected_projection(repository, package, revision)
        declared = declared_projection(sources_text, repository_name)
        for name, value in expected.items():
            if declared.get(name) != value:
                errors.append(
                    f"{repository_name}.{name}: expected {value!r}, found {declared.get(name)!r}"
                )
        sha256 = declared.get("sha256")
        if not isinstance(sha256, str) or re.fullmatch(r"[0-9a-f]{64}", sha256) is None:
            errors.append(f"{repository_name}.sha256 is not a canonical SHA-256 digest")

        for platform_key, platform_lock in extension.items():
            generated = platform_lock.get("generatedRepoSpecs", {})
            attributes = generated.get(repository_name, {}).get("attributes")
            if attributes is None:
                errors.append(f"{platform_key}: lock projection {repository_name!r} is absent")
            else:
                for name, value in declared.items():
                    if attributes.get(name) != value:
                        errors.append(
                            f"{platform_key}: lock projection {repository_name}.{name} is stale"
                        )

    usage_digests = {
        platform_lock.get("usagesDigest") for platform_lock in extension.values()
    }
    if len(usage_digests) > 1:
        errors.append("Bazel extension usagesDigest differs across platform lock entries")
    return errors


def archive_digest(url: str) -> str:
    digest = hashlib.sha256()
    request = urllib.request.Request(url, headers={"User-Agent": "agentic-ai-lab-pin/1"})
    with urllib.request.urlopen(request) as response:
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def replace_field(body: str, name: str, value: str) -> str:
    updated, count = re.subn(
        rf'(^    {re.escape(name)} = ")[^"]*(",$)',
        rf"\g<1>{value}\g<2>",
        body,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise ValueError(f"expected one {name!r} field, found {count}")
    return updated


def project_pin(package: str, revision: str, root: Path = ROOT) -> None:
    if REVISION.fullmatch(revision) is None:
        raise ValueError("revision must be a full Git object ID or v-prefixed version tag")

    owners = package_pin_owners(root)
    if package not in owners:
        raise ValueError(f"declared direct dependency {package!r} is absent")
    package_path, _pin = owners[package]
    sources_path = root / "gerbil-dependencies.MODULE.bazel"
    package_text = package_path.read_text(encoding="utf-8")
    pins = parse_package_pins(package_text)
    if package not in pins:
        raise ValueError(f"root/development package dependency {package!r} is absent")
    repository, old_revision = pins[package]
    projection = expected_projection(repository, package, revision)
    url = projection["urls"][0]
    assert isinstance(url, str)
    sha256 = archive_digest(url)

    old_pin = f'"{repository}@{old_revision}"'
    new_pin = f'"{repository}@{revision}"'
    if package_text.count(old_pin) != 1:
        raise ValueError(f"expected one authoritative pin for {package!r}")
    package_text = package_text.replace(old_pin, new_pin)

    sources_text = sources_path.read_text(encoding="utf-8")
    repositories = direct_source_repositories(sources_text)
    repository_name = repositories.get(package)
    if repository_name is None:
        raise ValueError(f"Bazel source projection for direct dependency {package!r} is absent")
    match, body = source_block(sources_text, repository_name)
    updated_body = body
    for name, value in (
        ("canonical_uri", projection["canonical_uri"]),
        ("package", package),
        ("revision", revision),
        ("sha256", sha256),
        ("strip_prefix", projection["strip_prefix"]),
    ):
        assert isinstance(value, str)
        updated_body = replace_field(updated_body, name, value)
    updated_body, url_count = re.subn(
        r'(^        ")[^"]*(",$)',
        rf"\g<1>{url}\g<2>",
        updated_body,
        flags=re.MULTILINE,
    )
    if url_count != 1:
        raise ValueError(f"expected one archive URL, found {url_count}")
    sources_text = sources_text[: match.start("body")] + updated_body + sources_text[match.end("body") :]

    package_path.write_text(package_text, encoding="utf-8")
    sources_path.write_text(sources_text, encoding="utf-8")
    print(f"gerbil-dependency-pin: projected {package}@{revision} sha256={sha256}")


def host_lock_key(extension: dict[str, object]) -> str:
    system = platform.system()
    machine = platform.machine().lower()
    os_name = "osx" if system == "Darwin" else "linux" if system == "Linux" else ""
    arch = {"arm64": "aarch64", "x86_64": "amd64", "amd64": "amd64"}.get(machine, machine)
    key = f"os:{os_name},arch:{arch}"
    if key not in extension:
        raise ValueError(f"native Bazel lock entry {key!r} is absent")
    return key


def sync_lock(root: Path = ROOT) -> None:
    lock_path = root / "MODULE.bazel.lock"
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    extension = lock.get("moduleExtensions", {}).get(EXTENSION_ID)
    if not isinstance(extension, dict) or not extension:
        raise ValueError("Gerbil Bazel extension lock is absent")
    native = extension[host_lock_key(extension)]
    native_repositories = native["generatedRepoSpecs"]
    repositories_by_package = direct_source_repositories(
        (root / "gerbil-dependencies.MODULE.bazel").read_text(encoding="utf-8")
    )
    repository_names = set(repositories_by_package.values())
    for platform_lock in extension.values():
        platform_lock["usagesDigest"] = native["usagesDigest"]
        repositories = platform_lock["generatedRepoSpecs"]
        for repository_name in locked_source_package_names(repositories) - repository_names:
            del repositories[repository_name]
        for repository_name in repository_names:
            repositories[repository_name] = native_repositories[repository_name]
    lock_path.write_text(json.dumps(lock, indent=2) + "\n", encoding="utf-8")
    print("gerbil-dependency-pin: synchronized cross-platform Bazel lock projections")


def ensure_native_commit(url: str, revision: str, target: Path) -> None:
    """Fetch an exact commit without resetting an existing package checkout."""
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("native prefetch requires a full commit SHA")
    created = not target.exists()
    if created:
        target.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "--quiet", str(target)], check=True)
        subprocess.run(["git", "-C", str(target), "remote", "add", "origin", url], check=True)
    elif not (target / ".git").exists():
        raise ValueError(f"native package path is not a Git checkout: {target}")
    present = subprocess.run(
        ["git", "-C", str(target), "cat-file", "-e", f"{revision}^{{commit}}"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0
    if not present:
        print(f"gerbil-native-pin: fetching {revision} into {target}", flush=True)
        subprocess.run(
            ["git", "-C", str(target), "fetch", "--no-tags", "--depth=1", url, revision],
            check=True,
        )
    # A failed first fetch leaves an initialized but unborn checkout. Complete
    # only that new checkout; existing branches and local edits remain intact.
    unborn = subprocess.run(
        ["git", "-C", str(target), "rev-parse", "--verify", "HEAD"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode != 0
    if created or unborn:
        subprocess.run(["git", "-C", str(target), "checkout", "--quiet", "--detach", revision], check=True)
        # gxpkg reads this adjacent Scheme datum to distinguish an installed
        # immutable pin from an untagged detached branch (whose name is empty).
        target.with_name(target.name + ".tag").write_text(json.dumps(revision) + "\n")
    print(f"gerbil-native-pin: ready {revision}", flush=True)


def prepare_native_pins(package_root: Path, root: Path = ROOT, manifest: Path | None = None) -> None:
    """Materialize declared SHA objects; gxpkg still owns tag resolution/builds."""
    package_manifest = manifest if manifest is not None else root / "gerbil.pkg"
    for repository, revision in parse_package_pins(package_manifest.read_text()).values():
        if not re.fullmatch(r"[0-9a-f]{40}", revision):
            continue
        target = (package_root / repository).resolve()
        if not target.is_relative_to(package_root.resolve()):
            raise ValueError("native package pin escapes package root")
        ensure_native_commit(f"https://{repository}.git", revision, target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    check_parser = subparsers.add_parser("check", help="validate native and Bazel pins")
    check_parser.set_defaults(command="check")
    pin_parser = subparsers.add_parser("pin", help="project one direct dependency revision")
    pin_parser.add_argument("package")
    pin_parser.add_argument("revision")
    subparsers.add_parser("sync-lock", help="copy the native lock projection across platforms")
    prepare_parser = subparsers.add_parser("prepare-native", help="fetch immutable commit objects for gxpkg")
    prepare_parser.add_argument("--package-root", type=Path, required=True)
    prepare_parser.add_argument("--manifest", type=Path, help="authoritative package manifest (defaults to root gerbil.pkg)")
    args = parser.parse_args()

    try:
        if args.command == "prepare-native":
            prepare_native_pins(args.package_root, manifest=args.manifest)
        elif args.command == "pin":
            project_pin(args.package, args.revision)
        elif args.command == "sync-lock":
            sync_lock()
        else:
            errors = collect_errors()
            if errors:
                for error in errors:
                    print(f"gerbil-dependency-contract: {error}", file=sys.stderr)
                return 1
            print("gerbil-dependency-contract: ok")
    except (KeyError, OSError, ValueError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
        print(f"gerbil-dependency-pin: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
