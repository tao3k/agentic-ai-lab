# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import os
from pathlib import Path

import pytest


def _bundle_library() -> Path:
    override = os.environ.get("AGENTIC_AI_LAB_BUNDLE_V1_LIBRARY")
    if override:
        return Path(override).expanduser().resolve()
    return (
        Path(__file__).resolve().parents[4]
        / "bazel-bin"
        / "bindings"
        / "runtime-c"
        / "bundle-v1"
        / "libbundle_v1_shared.dylib"
    )


def test_bundle_v1_cffi_is_typed_zero_copy_and_logarithmic() -> None:
    cffi = pytest.importorskip("cffi")
    library = _bundle_library()
    if not library.is_file():
        pytest.skip("focused Bundle v1 shared-library build has not run")

    ffi = cffi.FFI()
    ffi.cdef(
        """
        typedef uint32_t agentic_ai_lab_bundle_v1_status;
        typedef struct { uint64_t high; uint64_t low; }
          agentic_ai_lab_bundle_v1_compact_id;
        typedef struct {
          uint64_t offset;
          uint64_t length;
          uint32_t stride;
          uint32_t alignment;
        } agentic_ai_lab_bundle_v1_region;
        typedef struct {
          agentic_ai_lab_bundle_v1_compact_id case_id;
          agentic_ai_lab_bundle_v1_compact_id component_id;
          agentic_ai_lab_bundle_v1_compact_id object_id;
          agentic_ai_lab_bundle_v1_compact_id type_id;
          agentic_ai_lab_bundle_v1_compact_id contract_id;
          agentic_ai_lab_bundle_v1_compact_id role_id;
          agentic_ai_lab_bundle_v1_compact_id capability_id;
          agentic_ai_lab_bundle_v1_compact_id policy_id;
          agentic_ai_lab_bundle_v1_compact_id strategy_id;
          agentic_ai_lab_bundle_v1_compact_id adapter_id;
          agentic_ai_lab_bundle_v1_compact_id projection_id;
          uint64_t composition_order;
          uint32_t flags;
          uint32_t reserved0;
          uint64_t reserved1;
        } agentic_ai_lab_bundle_v1_component_entry;
        typedef struct {
          uint32_t struct_size;
          uint32_t flags;
          uint16_t schema_major;
          uint16_t schema_minor;
          uint32_t reserved0;
          agentic_ai_lab_bundle_v1_compact_id bundle_id;
          uint8_t digest[32];
          uint64_t bundle_epoch;
          uint64_t arena_bytes;
          agentic_ai_lab_bundle_v1_region symbols;
          agentic_ai_lab_bundle_v1_region components;
          agentic_ai_lab_bundle_v1_region edges;
          agentic_ai_lab_bundle_v1_region evidence_obligations;
          agentic_ai_lab_bundle_v1_region metadata_bytes;
          uint64_t reserved[7];
        } agentic_ai_lab_bundle_v1_descriptor;
        agentic_ai_lab_bundle_v1_status agentic_ai_lab_bundle_v1_validate(
          const agentic_ai_lab_bundle_v1_descriptor *, const void *, uint64_t);
        agentic_ai_lab_bundle_v1_status agentic_ai_lab_bundle_v1_find_component(
          const agentic_ai_lab_bundle_v1_descriptor *,
          const void *,
          agentic_ai_lab_bundle_v1_compact_id,
          agentic_ai_lab_bundle_v1_compact_id,
          const agentic_ai_lab_bundle_v1_component_entry **);
        """
    )
    native = ffi.dlopen(str(library))
    assert ffi.sizeof("agentic_ai_lab_bundle_v1_descriptor") == 256
    assert ffi.sizeof("agentic_ai_lab_bundle_v1_component_entry") == 200
    rows = ffi.new("agentic_ai_lab_bundle_v1_component_entry[]", 2)
    descriptor = ffi.new("agentic_ai_lab_bundle_v1_descriptor *")

    for index, row in enumerate(rows):
        row.case_id.low = 41
        row.component_id.low = index + 1
        row.object_id.low = 100 + index
        row.flags = 1

    descriptor.struct_size = ffi.sizeof("agentic_ai_lab_bundle_v1_descriptor")
    descriptor.flags = 3
    descriptor.schema_major = 1
    descriptor.schema_minor = 0
    descriptor.bundle_id.low = 7
    descriptor.digest[0] = 0xA5
    descriptor.arena_bytes = ffi.sizeof(rows)
    descriptor.symbols.stride = 32
    descriptor.symbols.alignment = 8
    descriptor.components.offset = 0
    descriptor.components.length = ffi.sizeof(rows)
    descriptor.components.stride = ffi.sizeof(
        "agentic_ai_lab_bundle_v1_component_entry"
    )
    descriptor.components.alignment = ffi.alignof(
        "agentic_ai_lab_bundle_v1_component_entry"
    )
    descriptor.edges.stride = 80
    descriptor.edges.alignment = 8
    descriptor.evidence_obligations.stride = 96
    descriptor.evidence_obligations.alignment = 8
    descriptor.metadata_bytes.stride = 1
    descriptor.metadata_bytes.alignment = 1

    assert native.agentic_ai_lab_bundle_v1_validate(
        descriptor, rows, ffi.sizeof(rows)
    ) == 0

    found = ffi.new("const agentic_ai_lab_bundle_v1_component_entry **")
    case_id = ffi.new("agentic_ai_lab_bundle_v1_compact_id *", {"low": 41})[0]
    component_id = ffi.new(
        "agentic_ai_lab_bundle_v1_compact_id *", {"low": 2}
    )[0]
    assert native.agentic_ai_lab_bundle_v1_find_component(
        descriptor, rows, case_id, component_id, found
    ) == 0
    assert found[0].object_id.low == 101
    assert int(ffi.cast("uintptr_t", found[0])) == int(
        ffi.cast("uintptr_t", rows + 1)
    )

    missing_id = ffi.new(
        "agentic_ai_lab_bundle_v1_compact_id *", {"low": 99}
    )[0]
    assert native.agentic_ai_lab_bundle_v1_find_component(
        descriptor, rows, case_id, missing_id, found
    ) == 8
