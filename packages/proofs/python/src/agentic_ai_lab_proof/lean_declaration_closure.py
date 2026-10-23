# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import time
from typing import Callable, Mapping, Sequence


SCHEMA_ID = "agentic-ai-lab.lean-declaration-closure.v1"
DEFAULT_LEAN_EXPORT_TIMEOUT_SECONDS = 30.0


class LeanClosureError(ValueError):
    def __init__(self, code: str, detail: str) -> None:
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


def _require_string(value: object, field: str) -> str:
    if not isinstance(value, str) or not value:
        raise LeanClosureError("invalid-field", field)
    return value


def _require_string_tuple(value: object, field: str) -> tuple[str, ...]:
    if not isinstance(value, list) or any(not isinstance(item, str) or not item for item in value):
        raise LeanClosureError("invalid-field", field)
    return tuple(value)


def _require_mapping_list(
    value: object,
    field: str,
) -> list[object]:
    if not isinstance(value, list):
        raise LeanClosureError("invalid-field", field)
    return value


@dataclass(frozen=True)
class LeanSourceRange:
    start_line: int
    start_column: int
    start_char_utf16: int
    end_line: int
    end_column: int
    end_char_utf16: int

    @classmethod
    def from_mapping(cls, value: object) -> LeanSourceRange:
        if not isinstance(value, Mapping):
            raise LeanClosureError(
                "invalid-source-range",
                "expected object",
            )
        fields = (
            "start_line",
            "start_column",
            "start_char_utf16",
            "end_line",
            "end_column",
            "end_char_utf16",
        )
        parsed: dict[str, int] = {}
        for field in fields:
            item = value.get(field)
            if not isinstance(item, int) or item < 0:
                raise LeanClosureError("invalid-source-range", field)
            parsed[field] = item
        if parsed["start_line"] == 0 or parsed["end_line"] == 0:
            raise LeanClosureError("invalid-source-range", "line numbers are 1-based")
        if (
            parsed["end_line"],
            parsed["end_char_utf16"],
        ) < (
            parsed["start_line"],
            parsed["start_char_utf16"],
        ):
            raise LeanClosureError("invalid-source-range", "end precedes start")
        return cls(**parsed)

    def canonical_record(self) -> dict[str, int]:
        return {
            "start_line": self.start_line,
            "start_column": self.start_column,
            "start_char_utf16": self.start_char_utf16,
            "end_line": self.end_line,
            "end_column": self.end_column,
            "end_char_utf16": self.end_char_utf16,
        }


@dataclass(frozen=True)
class LeanDeclaration:
    name: str
    kind: str
    owner_module: str
    local_dependencies: tuple[str, ...]
    source_range: LeanSourceRange | None = None

    @classmethod
    def from_mapping(cls, value: object) -> LeanDeclaration:
        if not isinstance(value, Mapping):
            raise LeanClosureError("invalid-declaration", "expected object")
        return cls(
            name=_require_string(value.get("name"), "declaration.name"),
            kind=_require_string(value.get("kind"), "declaration.kind"),
            owner_module=_require_string(value.get("owner_module"), "declaration.owner_module"),
            local_dependencies=_require_string_tuple(
                value.get("local_dependencies"),
                "declaration.local_dependencies",
            ),
            source_range=(
                LeanSourceRange.from_mapping(source_range)
                if (source_range := value.get("source_range")) is not None
                else None
            ),
        )

    def canonical_record(self) -> dict[str, object]:
        record: dict[str, object] = {
            "kind": self.kind,
            "local_dependencies": list(self.local_dependencies),
            "name": self.name,
            "owner_module": self.owner_module,
        }
        if self.source_range is not None:
            record["source_range"] = self.source_range.canonical_record()
        return record


@dataclass(frozen=True)
class LeanProofBaseInterfaceDeclaration:
    name: str
    declaration_role: str
    level_params: tuple[str, ...]
    type_source: str
    value_source: str | None

    @classmethod
    def from_mapping(
        cls,
        value: object,
    ) -> LeanProofBaseInterfaceDeclaration:
        if not isinstance(value, Mapping):
            raise LeanClosureError(
                "invalid-proof-base-interface-declaration",
                "expected object",
            )
        value_source = value.get("value_source")
        if value_source is not None and (not isinstance(value_source, str) or not value_source):
            raise LeanClosureError(
                "invalid-field",
                "proof_base_interface.value_source",
            )
        declaration_role = _require_string(
            value.get("declaration_role"),
            "proof_base_interface.declaration_role",
        )
        if declaration_role not in {
            "abbrev",
            "axiom",
            "definition",
            "instance",
        }:
            raise LeanClosureError(
                "invalid-field",
                "proof_base_interface.declaration_role",
            )
        return cls(
            name=_require_string(
                value.get("name"),
                "proof_base_interface.name",
            ),
            declaration_role=declaration_role,
            level_params=_require_string_tuple(
                value.get("level_params"),
                "proof_base_interface.level_params",
            ),
            type_source=_require_string(
                value.get("type_source"),
                "proof_base_interface.type_source",
            ),
            value_source=value_source,
        )

    def canonical_record(self) -> dict[str, object]:
        return {
            "declaration_role": self.declaration_role,
            "level_params": list(self.level_params),
            "name": self.name,
            "type_source": self.type_source,
            "value_source": self.value_source,
        }


@dataclass(frozen=True)
class LeanDeclarationClosure:
    lean_version: str
    root_module: str
    root_declarations: tuple[str, ...]
    base_imports: tuple[str, ...]
    proof_base_imports: tuple[str, ...]
    proof_base_interface: tuple[
        LeanProofBaseInterfaceDeclaration,
        ...,
    ]
    owner_modules: tuple[str, ...]
    declarations: tuple[LeanDeclaration, ...]
    schema_id: str = SCHEMA_ID

    def __post_init__(self) -> None:
        if self.schema_id != SCHEMA_ID:
            raise LeanClosureError("unsupported-schema", self.schema_id)
        for field, value in (
            ("lean_version", self.lean_version),
            ("root_module", self.root_module),
        ):
            _require_string(value, field)
        if not self.root_declarations:
            raise LeanClosureError("missing-root-declaration", self.root_module)
        if len(set(self.root_declarations)) != len(self.root_declarations):
            raise LeanClosureError("duplicate-root-declaration", self.root_module)
        if not self.base_imports:
            raise LeanClosureError("missing-base-import", self.root_module)
        if len(set(self.proof_base_imports)) != len(self.proof_base_imports):
            raise LeanClosureError(
                "duplicate-proof-base-import",
                self.root_module,
            )
        interface_names = tuple(declaration.name for declaration in self.proof_base_interface)
        if len(set(interface_names)) != len(interface_names):
            raise LeanClosureError(
                "duplicate-proof-base-interface-declaration",
                self.root_module,
            )
        if tuple(sorted(set(self.owner_modules))) != self.owner_modules:
            raise LeanClosureError("non-canonical-owner-modules", self.root_module)

        emitted: set[str] = set()
        owners: set[str] = set()
        for declaration in self.declarations:
            if declaration.name in emitted:
                raise LeanClosureError(
                    "duplicate-declaration",
                    declaration.name,
                )
            missing = [
                dependency
                for dependency in declaration.local_dependencies
                if dependency not in emitted
            ]
            if missing:
                raise LeanClosureError(
                    "non-topological-declaration",
                    f"{declaration.name}: {','.join(missing)}",
                )
            emitted.add(declaration.name)
            owners.add(declaration.owner_module)

        missing_roots = [
            declaration for declaration in self.root_declarations if declaration not in emitted
        ]
        if missing_roots:
            raise LeanClosureError(
                "root-outside-closure",
                ",".join(missing_roots),
            )
        if owners != set(self.owner_modules):
            raise LeanClosureError(
                "owner-module-mismatch",
                self.root_module,
            )

    @classmethod
    def from_mapping(cls, value: object) -> LeanDeclarationClosure:
        if not isinstance(value, Mapping):
            raise LeanClosureError("invalid-receipt", "expected object")
        declarations = value.get("declarations")
        if not isinstance(declarations, list):
            raise LeanClosureError("invalid-field", "declarations")
        return cls(
            schema_id=_require_string(value.get("schema_id"), "schema_id"),
            lean_version=_require_string(
                value.get("lean_version"),
                "lean_version",
            ),
            root_module=_require_string(value.get("root_module"), "root_module"),
            root_declarations=_require_string_tuple(
                value.get("root_declarations"),
                "root_declarations",
            ),
            base_imports=_require_string_tuple(
                value.get("base_imports"),
                "base_imports",
            ),
            proof_base_imports=_require_string_tuple(
                value.get("proof_base_imports"),
                "proof_base_imports",
            ),
            proof_base_interface=tuple(
                LeanProofBaseInterfaceDeclaration.from_mapping(declaration)
                for declaration in _require_mapping_list(
                    value.get("proof_base_interface"),
                    "proof_base_interface",
                )
            ),
            owner_modules=_require_string_tuple(
                value.get("owner_modules"),
                "owner_modules",
            ),
            declarations=tuple(
                LeanDeclaration.from_mapping(declaration) for declaration in declarations
            ),
        )

    @classmethod
    def from_json(cls, source: str) -> LeanDeclarationClosure:
        try:
            value = json.loads(source)
        except json.JSONDecodeError as error:
            raise LeanClosureError("invalid-json", str(error)) from error
        return cls.from_mapping(value)

    def canonical_manifest(self) -> dict[str, object]:
        return {
            "base_imports": list(self.base_imports),
            "declarations": [declaration.canonical_record() for declaration in self.declarations],
            "lean_version": self.lean_version,
            "owner_modules": list(self.owner_modules),
            "proof_base_imports": list(self.proof_base_imports),
            "proof_base_interface": [
                declaration.canonical_record() for declaration in self.proof_base_interface
            ],
            "root_declarations": list(self.root_declarations),
            "root_module": self.root_module,
            "schema_id": self.schema_id,
        }

    @property
    def closure_digest(self) -> str:
        canonical = json.dumps(
            self.canonical_manifest(),
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        ).encode()
        return f"sha256:{sha256(canonical).hexdigest()}"

    def owner_modules_in_dependency_order(self) -> tuple[str, ...]:
        declaration_owners = {
            declaration.name: declaration.owner_module for declaration in self.declarations
        }
        dependencies = {owner_module: set() for owner_module in self.owner_modules}
        for declaration in self.declarations:
            for dependency in declaration.local_dependencies:
                dependency_owner = declaration_owners[dependency]
                if dependency_owner != declaration.owner_module:
                    dependencies[declaration.owner_module].add(dependency_owner)

        result: list[str] = []
        emitted: set[str] = set()
        while len(result) < len(dependencies):
            ready = sorted(
                owner
                for owner, owner_dependencies in dependencies.items()
                if owner not in emitted and owner_dependencies.issubset(emitted)
            )
            if not ready:
                unresolved = sorted(set(dependencies) - emitted)
                raise LeanClosureError(
                    "owner-module-cycle",
                    ",".join(unresolved),
                )
            result.extend(ready)
            emitted.update(ready)
        return tuple(result)


@dataclass(frozen=True)
class LeanOwnerSource:
    module: str
    path: Path
    owner_path: str
    source_digest: str


Runner = Callable[..., subprocess.CompletedProcess[str]]
PhaseObserver = Callable[[Mapping[str, object]], None]


@dataclass(frozen=True)
class LeanDeclarationClosureRequest:
    root_module: str
    root_declarations: tuple[str, ...]
    base_imports: tuple[str, ...] = ("Init",)
    proof_base_imports: tuple[str, ...] = ()


def _artifact_digest(path: Path) -> tuple[bytes, int]:
    digest = hashlib.sha256()
    total_bytes = 0
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
            total_bytes += len(chunk)
    return digest.digest(), total_bytes


def _observe_export_phase(
    observer: PhaseObserver | None,
    *,
    phase: str,
    started: float,
    **fields: object,
) -> None:
    if observer is None:
        return
    observer(
        {
            "elapsed_ms": round((time.monotonic() - started) * 1000),
            "phase": phase,
            "schema_id": "agentic-ai-lab.lean-export-driver-phase.v1",
            "state": "completed",
            **fields,
        }
    )


def _observe_native_export_phases(
    observer: PhaseObserver | None,
    stderr: str,
) -> None:
    if observer is None:
        return
    for line in stderr.splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, Mapping) and value.get("schema_id") == "agentic-ai-lab.lean-export-phase.v1":
            observer(value)


def export_declaration_closure(
    *,
    lean_root: Path,
    root_module: str,
    root_declarations: Sequence[str],
    base_imports: Sequence[str] = ("Init",),
    proof_base_imports: Sequence[str] = (),
    timeout_seconds: float = DEFAULT_LEAN_EXPORT_TIMEOUT_SECONDS,
    runner: Runner = subprocess.run,
    phase_observer: PhaseObserver | None = None,
    _build_prepared: bool = False,
    _exporter_digest: bytes | None = None,
    _exported_json_provider: Callable[[], str] | None = None,
) -> LeanDeclarationClosure:
    if not root_declarations:
        raise LeanClosureError("missing-root-declaration", root_module)
    if (
        not isinstance(timeout_seconds, (int, float))
        or isinstance(timeout_seconds, bool)
        or not math.isfinite(timeout_seconds)
        or timeout_seconds <= 0
    ):
        raise LeanClosureError(
            "invalid-lean-export-timeout",
            f"expected a positive finite number; actual={timeout_seconds!r}",
        )

    deadline = time.monotonic() + timeout_seconds

    def run_export_phase(
        command: Sequence[str],
        *,
        phase: str,
    ) -> subprocess.CompletedProcess[str]:
        remaining_seconds = deadline - time.monotonic()
        if remaining_seconds <= 0:
            raise LeanClosureError(
                "lean-declaration-closure-export-timeout",
                (f"phase={phase}; root_module={root_module}; budget_seconds={timeout_seconds:g}"),
            )
        try:
            started = time.monotonic()
            result = runner(
                command,
                cwd=lean_root,
                capture_output=True,
                check=False,
                text=True,
                timeout=remaining_seconds,
            )
            _observe_export_phase(
                phase_observer,
                phase=phase,
                started=started,
                returncode=result.returncode,
            )
            return result
        except subprocess.TimeoutExpired as error:
            raise LeanClosureError(
                "lean-declaration-closure-export-timeout",
                (f"phase={phase}; root_module={root_module}; budget_seconds={timeout_seconds:g}"),
            ) from error

    exporter = Path(".lake/build/bin/agenticAiLabDeclarationClosure")
    if not _build_prepared:
        build = run_export_phase(
            ["lake", "build", root_module, "agenticAiLabDeclarationClosure"],
            phase="lake-build",
        )
        if build.returncode != 0:
            raise LeanClosureError(
                "lake-build-failed",
                build.stderr.strip() or build.stdout.strip() or root_module,
            )
    elif _exporter_digest is None and runner is subprocess.run:
        raise LeanClosureError(
            "lean-export-generation-invalid",
            "prepared build requires exporter digest",
        )

    cache_path: Path | None = None
    exported_json: str | None = None
    if runner is subprocess.run:
        root_olean = (
            lean_root / ".lake/build/lib/lean" / Path(*root_module.split(".")).with_suffix(".olean")
        )
        exporter_path = lean_root / exporter
        if root_olean.is_file() and exporter_path.is_file():
            cache_hash_started = time.monotonic()
            cache_key = hashlib.sha256()
            cache_key.update(
                json.dumps(
                    {
                        "base_imports": list(base_imports),
                        "proof_base_imports": list(proof_base_imports),
                        "root_declarations": list(root_declarations),
                        "root_module": root_module,
                        "schema_id": "agentic-ai-lab.lean-declaration-closure-cache.v2",
                    },
                    ensure_ascii=False,
                    separators=(",", ":"),
                    sort_keys=True,
                ).encode()
            )
            root_olean_digest, root_olean_bytes = _artifact_digest(root_olean)
            exporter_digest = _exporter_digest
            exporter_bytes = 0
            if exporter_digest is None:
                exporter_digest, exporter_bytes = _artifact_digest(exporter_path)
            cache_key.update(root_olean_digest)
            cache_key.update(exporter_digest)
            _observe_export_phase(
                phase_observer,
                phase="artifact-hash",
                started=cache_hash_started,
                artifact_bytes=root_olean_bytes + exporter_bytes,
                exporter_digest_reused=_exporter_digest is not None,
            )
            cache_path = (
                lean_root
                / ".lake/build/agentic-ai-lab/declaration-closure-cache"
                / f"{cache_key.hexdigest()}.json"
            )
            try:
                cache_read_started = time.monotonic()
                exported_json = cache_path.read_text()
            except FileNotFoundError:
                _observe_export_phase(
                    phase_observer,
                    phase="closure-cache-read",
                    started=cache_read_started,
                    cache_state="miss",
                )
            else:
                _observe_export_phase(
                    phase_observer,
                    phase="closure-cache-read",
                    started=cache_read_started,
                    cache_state="hit",
                )

    command = [
        "lake",
        "env",
        str(exporter),
        "--root-module",
        root_module,
    ]
    for root_declaration in root_declarations:
        command.extend(("--root-declaration", root_declaration))
    for base_import in base_imports:
        if base_import != "Init":
            command.extend(("--base-import", base_import))
    for proof_base_import in proof_base_imports:
        command.extend(("--proof-base-import", proof_base_import))
    cache_miss = exported_json is None
    if exported_json is None:
        if _exported_json_provider is None:
            exported = run_export_phase(
                command,
                phase="lean-export",
            )
            if exported.returncode != 0:
                raise LeanClosureError(
                    "lean-export-failed",
                    exported.stderr.strip() or exported.stdout.strip() or root_module,
                )
            _observe_native_export_phases(phase_observer, exported.stderr)
            exported_json = exported.stdout
        else:
            exported_json = _exported_json_provider()
    parse_started = time.monotonic()
    closure = LeanDeclarationClosure.from_json(exported_json)
    _observe_export_phase(
        phase_observer,
        phase="closure-parse",
        started=parse_started,
        declaration_count=len(closure.declarations),
        proof_base_declaration_count=len(closure.proof_base_interface),
    )
    if closure.root_module != root_module:
        raise LeanClosureError(
            "root-module-mismatch",
            f"{root_module} != {closure.root_module}",
        )
    if closure.root_declarations != tuple(root_declarations):
        raise LeanClosureError(
            "root-declaration-mismatch",
            root_module,
        )
    expected_base_imports = ("Init",) + tuple(
        base_import for base_import in base_imports if base_import != "Init"
    )
    if closure.base_imports != expected_base_imports:
        raise LeanClosureError(
            "base-import-mismatch",
            root_module,
        )
    if closure.proof_base_imports != tuple(proof_base_imports):
        raise LeanClosureError(
            "proof-base-import-mismatch",
            root_module,
        )
    if cache_miss and cache_path is not None:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        temporary_cache = cache_path.with_suffix(f".tmp.{os.getpid()}")
        temporary_cache.write_text(exported_json)
        temporary_cache.replace(cache_path)
    return closure


def export_declaration_closures(
    *,
    lean_root: Path,
    requests: Sequence[LeanDeclarationClosureRequest],
    timeout_seconds: float = DEFAULT_LEAN_EXPORT_TIMEOUT_SECONDS,
    runner: Runner = subprocess.run,
    phase_observer: PhaseObserver | None = None,
) -> tuple[LeanDeclarationClosure, ...]:
    """Export several roots under one bounded Lake build generation."""

    if not requests:
        raise LeanClosureError(
            "missing-lean-export-request",
            str(lean_root),
        )
    if (
        not isinstance(timeout_seconds, (int, float))
        or isinstance(timeout_seconds, bool)
        or not math.isfinite(timeout_seconds)
        or timeout_seconds <= 0
    ):
        raise LeanClosureError(
            "invalid-lean-export-timeout",
            f"expected a positive finite number; actual={timeout_seconds!r}",
        )
    for request in requests:
        if not request.root_declarations:
            raise LeanClosureError(
                "missing-root-declaration",
                request.root_module,
            )

    deadline = time.monotonic() + timeout_seconds
    root_modules = tuple(dict.fromkeys(request.root_module for request in requests))
    build_command = [
        "lake",
        "build",
        *root_modules,
        "agenticAiLabDeclarationClosure",
    ]
    remaining_seconds = deadline - time.monotonic()
    try:
        build_started = time.monotonic()
        build = runner(
            build_command,
            cwd=lean_root,
            capture_output=True,
            check=False,
            text=True,
            timeout=remaining_seconds,
        )
    except subprocess.TimeoutExpired as error:
        raise LeanClosureError(
            "lean-declaration-closure-export-timeout",
            f"phase=generation-lake-build; budget_seconds={timeout_seconds:g}",
        ) from error
    _observe_export_phase(
        phase_observer,
        phase="generation-lake-build",
        started=build_started,
        returncode=build.returncode,
        root_count=len(root_modules),
    )
    if build.returncode != 0:
        raise LeanClosureError(
            "lake-build-failed",
            build.stderr.strip() or build.stdout.strip() or ",".join(root_modules),
        )

    exporter_digest: bytes | None = None
    if runner is subprocess.run:
        exporter_path = lean_root / ".lake/build/bin/agenticAiLabDeclarationClosure"
        if not exporter_path.is_file():
            raise LeanClosureError(
                "lean-exporter-artifact-missing",
                str(exporter_path),
            )
        hash_started = time.monotonic()
        exporter_digest, exporter_bytes = _artifact_digest(exporter_path)
        _observe_export_phase(
            phase_observer,
            phase="generation-exporter-hash",
            started=hash_started,
            artifact_bytes=exporter_bytes,
        )

    first_request = requests[0]
    batch_compatible = all(
        request.base_imports == first_request.base_imports
        and request.proof_base_imports == first_request.proof_base_imports
        and len(request.root_declarations) == 1
        for request in requests
    )
    batch_payloads: list[str] | None = None

    def native_batch_payloads() -> list[str]:
        nonlocal batch_payloads
        if batch_payloads is not None:
            return batch_payloads
        command = [
            "lake",
            "env",
            ".lake/build/bin/agenticAiLabDeclarationClosure",
        ]
        for request in requests:
            command.extend(
                (
                    "--batch-root",
                    request.root_module,
                    request.root_declarations[0],
                )
            )
        for base_import in first_request.base_imports:
            if base_import != "Init":
                command.extend(("--base-import", base_import))
        for proof_base_import in first_request.proof_base_imports:
            command.extend(("--proof-base-import", proof_base_import))
        remaining_seconds = deadline - time.monotonic()
        try:
            export_started = time.monotonic()
            exported = runner(
                command,
                cwd=lean_root,
                capture_output=True,
                check=False,
                text=True,
                timeout=remaining_seconds,
            )
        except subprocess.TimeoutExpired as error:
            raise LeanClosureError(
                "lean-declaration-closure-export-timeout",
                f"phase=generation-lean-export; budget_seconds={timeout_seconds:g}",
            ) from error
        _observe_export_phase(
            phase_observer,
            phase="generation-lean-export",
            started=export_started,
            returncode=exported.returncode,
            root_count=len(requests),
        )
        if exported.returncode != 0:
            raise LeanClosureError(
                "lean-export-failed",
                exported.stderr.strip() or exported.stdout.strip() or ",".join(root_modules),
            )
        _observe_native_export_phases(phase_observer, exported.stderr)
        try:
            payload = json.loads(exported.stdout)
        except json.JSONDecodeError as error:
            raise LeanClosureError(
                "invalid-lean-export-batch",
                str(error),
            ) from error
        if not isinstance(payload, list) or len(payload) != len(requests):
            raise LeanClosureError(
                "invalid-lean-export-batch",
                f"expected {len(requests)} closures",
            )
        if any(not isinstance(item, Mapping) for item in payload):
            raise LeanClosureError(
                "invalid-lean-export-batch",
                "expected closure objects",
            )
        batch_payloads = [
            json.dumps(
                item,
                ensure_ascii=False,
                separators=(",", ":"),
            )
            for item in payload
        ]
        return batch_payloads

    closures: list[LeanDeclarationClosure] = []
    for request_index, request in enumerate(requests):
        remaining_seconds = deadline - time.monotonic()
        if remaining_seconds <= 0:
            raise LeanClosureError(
                "lean-declaration-closure-export-timeout",
                "phase=generation-export; "
                f"root_module={request.root_module}; "
                f"budget_seconds={timeout_seconds:g}",
            )
        closures.append(
            export_declaration_closure(
                lean_root=lean_root,
                root_module=request.root_module,
                root_declarations=request.root_declarations,
                base_imports=request.base_imports,
                proof_base_imports=request.proof_base_imports,
                timeout_seconds=remaining_seconds,
                runner=runner,
                phase_observer=phase_observer,
                _build_prepared=True,
                _exporter_digest=exporter_digest,
                _exported_json_provider=(
                    (lambda index=request_index: native_batch_payloads()[index])
                    if batch_compatible
                    else None
                ),
            )
        )
    return tuple(closures)


def _source_roots(lean_root: Path, lean_path: str) -> tuple[Path, ...]:
    roots: list[Path] = [lean_root.resolve()]
    marker = Path(".lake/build/lib/lean")
    for raw_entry in lean_path.split(os.pathsep):
        if not raw_entry:
            continue
        entry = Path(raw_entry).resolve()
        entry_parts = entry.parts
        marker_parts = marker.parts
        if (
            len(entry_parts) >= len(marker_parts)
            and tuple(entry_parts[-len(marker_parts) :]) == marker_parts
        ):
            roots.append(Path(*entry_parts[: -len(marker_parts)]))
    # Lake exposes compiled module roots through LEAN_PATH.  Package build
    # roots end in `.lake/build/lib/lean` and are handled above, while the
    # active Lean toolchain contributes `<toolchain>/lib/lean`.  AXLE needs
    # the corresponding parser-owned source root for modules such as
    # `Std.Data.DHashMap.Internal.AssocList.Basic`; do not fall back to the
    # compiled `.olean` tree or copy toolchain declarations into this repo.
    toolchain_marker_parts = Path("lib/lean").parts
    for raw_entry in lean_path.split(os.pathsep):
        if not raw_entry:
            continue
        entry = Path(raw_entry).resolve()
        entry_parts = entry.parts
        if (
            len(entry_parts) < len(toolchain_marker_parts)
            or tuple(entry_parts[-len(toolchain_marker_parts) :]) != toolchain_marker_parts
        ):
            continue
        toolchain_source = Path(*entry_parts[: -len(toolchain_marker_parts)]) / "src" / "lean"
        if toolchain_source.is_dir():
            roots.append(toolchain_source.resolve())

    return tuple(dict.fromkeys(roots))


def resolve_owner_sources(
    *,
    closure: LeanDeclarationClosure,
    lean_root: Path,
    runner: Runner = subprocess.run,
) -> tuple[LeanOwnerSource, ...]:
    lean_path_receipt = runner(
        ["lake", "env", "printenv", "LEAN_PATH"],
        cwd=lean_root,
        capture_output=True,
        check=False,
        text=True,
    )
    if lean_path_receipt.returncode != 0:
        raise LeanClosureError(
            "lean-path-failed",
            lean_path_receipt.stderr.strip() or str(lean_root),
        )
    lean_root = lean_root.resolve()
    roots = _source_roots(lean_root, lean_path_receipt.stdout.strip())
    sources: list[LeanOwnerSource] = []
    for module in closure.owner_modules_in_dependency_order():
        relative = Path(*module.split(".")).with_suffix(".lean")
        matches = tuple(
            candidate for root in roots if (candidate := (root / relative).resolve()).is_file()
        )
        if len(matches) != 1:
            raise LeanClosureError(
                "owner-source-resolution-failed",
                f"{module}: matches={len(matches)}",
            )
        path = matches[0]
        try:
            owner_path = path.relative_to(lean_root).as_posix()
        except ValueError:
            owner_path = f"{module}:{path.as_posix()}"
        digest = f"sha256:{sha256(path.read_bytes()).hexdigest()}"
        sources.append(
            LeanOwnerSource(
                module=module,
                path=path,
                owner_path=owner_path,
                source_digest=digest,
            )
        )
    return tuple(sources)
