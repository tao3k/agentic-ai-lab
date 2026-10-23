# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

from pathlib import Path

from cffi import FFI

ffibuilder = FFI()
ffibuilder.cdef(
    """
    typedef struct {
      uint64_t mediation_sequence;
      uint64_t first_sequence;
      uint64_t last_sequence;
      uint64_t nonce_high;
      uint64_t nonce_low;
      uint8_t semantic_root[32];
      uint8_t before_execution_root[32];
    } agentic_ai_lab_python_runtime_v0_evidence_reservation;

    typedef struct {
      uint32_t status;
      uint16_t abi_major;
      uint16_t abi_minor;
      uint64_t capabilities;
      uint64_t max_payload_bytes;
      char error[160];
    } agentic_ai_lab_python_runtime_v0_health;

    typedef struct agentic_ai_lab_python_runtime_v0_context
        agentic_ai_lab_python_runtime_v0_context;

    typedef struct {
      uint16_t layout_version;
      uint16_t event_kind;
      uint32_t flags;
      uint64_t sequence;
      uint64_t event_identity_high;
      uint64_t event_identity_low;
      uint64_t correlation_identity_high;
      uint64_t correlation_identity_low;
      uint64_t authorization_identity_high;
      uint64_t authorization_identity_low;
      uint64_t payload_offset;
      uint64_t payload_length;
      uint64_t deadline_mono_ns;
      uint32_t required_evidence_bits;
      uint32_t reserved0;
    } agentic_ai_lab_python_runtime_v0_event;

    typedef struct {
      uint32_t status;
      uint64_t published_count;
      uint64_t produced_count;
      uint64_t accepted_count;
      uint64_t rejected_count;
      uint64_t accepted_watermark;
      uint32_t mediation_outcome;
      uint32_t adapter_status;
      uint32_t evidence_status;
      uint32_t verification_flags;
      uint64_t mediation_sequence;
      uint8_t execution_root[32];
      uint8_t observation_digest[32];
      uint8_t evidence_digest[32];
      uint8_t attestation_digest[32];
    } agentic_ai_lab_python_runtime_v0_batch_result;

    typedef struct {
      uint32_t durability;
      uint32_t outcome;
      uint64_t bundle_epoch;
      uint64_t nonce_high;
      uint64_t nonce_low;
      uint8_t semantic_root[32];
      uint8_t before_execution_root[32];
      uint8_t after_execution_root[32];
      uint8_t input_digest[32];
      uint8_t observation_digest[32];
    } agentic_ai_lab_python_runtime_v0_mediation;

    typedef struct {
      uint32_t outcome;
      uint32_t adapter_status;
      uint64_t mediation_sequence;
      uint64_t first_sequence;
      uint64_t last_sequence;
      uint64_t nonce_high;
      uint64_t nonce_low;
      uint8_t semantic_root[32];
      uint8_t before_execution_root[32];
      uint8_t input_digest[32];
      uint8_t observation_digest[32];
    } agentic_ai_lab_python_runtime_v0_evidence_invocation;

    typedef struct {
      uint32_t verification_flags;
      uint8_t after_execution_root[32];
      uint8_t evidence_digest[32];
      uint8_t attestation_digest[32];
    } agentic_ai_lab_python_runtime_v0_evidence_result;

    typedef struct {
      uint64_t first_mediation_sequence;
      uint64_t last_mediation_sequence;
      const uint8_t *leaf_digests;
      uint64_t leaf_count;
      uint8_t before_execution_root[32];
    } agentic_ai_lab_python_runtime_v0_evidence_flush_invocation;

    typedef struct {
      uint32_t verification_flags;
      uint8_t after_execution_root[32];
      uint8_t batch_root[32];
      uint8_t evidence_digest[32];
      uint8_t attestation_digest[32];
    } agentic_ai_lab_python_runtime_v0_evidence_flush_result;

    typedef uint32_t (*agentic_ai_lab_python_runtime_v0_evidence_reserve_fn)(
        void *context,
        const agentic_ai_lab_python_runtime_v0_evidence_reservation *reservation);

    typedef uint32_t (*agentic_ai_lab_python_runtime_v0_evidence_finalize_fn)(
        void *context,
        const agentic_ai_lab_python_runtime_v0_evidence_invocation *invocation,
        agentic_ai_lab_python_runtime_v0_evidence_result *result);

    typedef uint32_t (*agentic_ai_lab_python_runtime_v0_evidence_flush_fn)(
        void *context,
        const agentic_ai_lab_python_runtime_v0_evidence_flush_invocation *invocation,
        agentic_ai_lab_python_runtime_v0_evidence_flush_result *result);

    int agentic_ai_lab_python_runtime_v0_probe(
        const char *library_path,
        const uint8_t *bundle_schema,
        size_t bundle_schema_length,
        const uint8_t *runtime_identity,
        size_t runtime_identity_length,
        agentic_ai_lab_python_runtime_v0_health *health);

    agentic_ai_lab_python_runtime_v0_context *agentic_ai_lab_python_runtime_v0_open(
        const char *library_path,
        const uint8_t *bundle_schema,
        size_t bundle_schema_length,
        const uint8_t *runtime_identity,
        size_t runtime_identity_length,
        uint32_t digest_algorithm,
        const uint8_t *bundle_digest,
        size_t bundle_digest_length,
        uint64_t bundle_epoch,
        const uint8_t *canonical_packet,
        size_t canonical_packet_length,
        uint32_t enable_batched,
        agentic_ai_lab_python_runtime_v0_health *health);

    uint32_t agentic_ai_lab_python_runtime_v0_close(
        agentic_ai_lab_python_runtime_v0_context *context);

    uint32_t agentic_ai_lab_python_runtime_v0_reconcile_evidence(
        agentic_ai_lab_python_runtime_v0_context *context,
        uint64_t mediation_sequence,
        uint64_t runtime_sequence,
        const uint64_t *nonce_high,
        const uint64_t *nonce_low,
        uint64_t nonce_count,
        const uint64_t *staged_mediation_sequences,
        const uint8_t *staged_leaf_digests,
        uint64_t staged_leaf_count,
        const uint8_t *semantic_root,
        const uint8_t *execution_root);

    uint32_t agentic_ai_lab_python_runtime_v0_flush_batched(
        agentic_ai_lab_python_runtime_v0_context *context,
        const uint8_t *expected_execution_root,
        agentic_ai_lab_python_runtime_v0_evidence_flush_fn evidence_flush,
        void *evidence_context,
        agentic_ai_lab_python_runtime_v0_evidence_flush_result *result);

    uint32_t agentic_ai_lab_python_runtime_v0_arena_register(
        agentic_ai_lab_python_runtime_v0_context *context,
        uint8_t *memory,
        uint64_t capacity,
        uint32_t alignment,
        uint64_t generation);

    uint32_t agentic_ai_lab_python_runtime_v0_arena_release(
        agentic_ai_lab_python_runtime_v0_context *context);

    uint32_t agentic_ai_lab_python_runtime_v0_arena_recycle(
        agentic_ai_lab_python_runtime_v0_context *context,
        uint64_t expected_generation,
        uint64_t next_generation);

    uint32_t agentic_ai_lab_python_runtime_v0_roundtrip(
        agentic_ai_lab_python_runtime_v0_context *context,
        agentic_ai_lab_python_runtime_v0_event *events,
        uint64_t event_count,
        uint32_t *item_statuses,
        uint64_t item_status_capacity,
        uint8_t *accepted_bitmap,
        uint64_t accepted_bitmap_bytes,
        const agentic_ai_lab_python_runtime_v0_mediation *mediation,
        agentic_ai_lab_python_runtime_v0_evidence_reserve_fn evidence_reserve,
        agentic_ai_lab_python_runtime_v0_evidence_finalize_fn evidence_finalize,
        agentic_ai_lab_python_runtime_v0_evidence_flush_fn evidence_flush,
        void *evidence_context,
        agentic_ai_lab_python_runtime_v0_batch_result *result);
    """
)

native_dir = Path(__file__).resolve().parent
runtime_c = native_dir.parents[4] / "bindings" / "runtime-c"
ffibuilder.set_source(
    "agentic_ai_lab_runtime._native._runtime_v0_cffi",
    '#include "runtime_v0_shim.c"',
    include_dirs=[str(native_dir), str(runtime_c / "include")],
)

if __name__ == "__main__":
    ffibuilder.compile(
        tmpdir=str(native_dir / "_build_temp"),
        target=str(native_dir / "_runtime_v0_cffi.abi3.so"),
        verbose=True,
    )
