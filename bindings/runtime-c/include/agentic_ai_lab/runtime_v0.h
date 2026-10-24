// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#ifndef AGENTIC_AI_LAB_RUNTIME_V0_H
#define AGENTIC_AI_LAB_RUNTIME_V0_H

#include <stdint.h>
#include "agentic_ai_lab/runtime_v0_contract.h"

#ifdef __cplusplus
extern "C" {
#endif

#define AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES 32u
typedef struct {
  uint64_t high;
  uint64_t low;
} agentic_ai_lab_runtime_v0_compact_id;

typedef struct {
  uint16_t layout_version;
  uint16_t event_kind;
  uint32_t flags;
  uint64_t sequence;
  agentic_ai_lab_runtime_v0_compact_id event_identity;
  agentic_ai_lab_runtime_v0_compact_id correlation_identity;
  agentic_ai_lab_runtime_v0_compact_id authorization_identity;
  uint64_t payload_offset;
  uint64_t payload_length;
  uint64_t deadline_mono_ns;
  uint32_t required_evidence_bits;
  uint32_t reserved0;
} agentic_ai_lab_runtime_v0_event_header;

_Static_assert(sizeof(agentic_ai_lab_runtime_v0_event_header) ==
                   AGENTIC_AI_LAB_RUNTIME_V0_EVENT_HEADER_BYTES,
               "runtime v0 event header must remain 96 bytes");

typedef uint32_t agentic_ai_lab_runtime_v0_status;
enum {
  AGENTIC_AI_LAB_RUNTIME_V0_OK = 0,
  AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT = 1,
  AGENTIC_AI_LAB_RUNTIME_V0_INCOMPATIBLE_ABI = 2,
  AGENTIC_AI_LAB_RUNTIME_V0_INCOMPATIBLE_SCHEMA = 3,
  AGENTIC_AI_LAB_RUNTIME_V0_UNSUPPORTED_CAPABILITY = 4,
  AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR = 5,
  AGENTIC_AI_LAB_RUNTIME_V0_WRONG_HANDLE_KIND = 6,
  AGENTIC_AI_LAB_RUNTIME_V0_STALE_HANDLE = 7,
  AGENTIC_AI_LAB_RUNTIME_V0_CROSS_INSTANCE_HANDLE = 8,
  AGENTIC_AI_LAB_RUNTIME_V0_ALREADY_RELEASED = 9,
  AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE = 10,
  AGENTIC_AI_LAB_RUNTIME_V0_BUNDLE_IDENTITY_MISMATCH = 11,
  AGENTIC_AI_LAB_RUNTIME_V0_CHECKPOINT_INCOMPATIBLE = 12,
  AGENTIC_AI_LAB_RUNTIME_V0_CANCELLED = 13,
  AGENTIC_AI_LAB_RUNTIME_V0_OUTSTANDING_WORK = 14,
  AGENTIC_AI_LAB_RUNTIME_V0_ALLOCATION_FAILURE = 15,
  AGENTIC_AI_LAB_RUNTIME_V0_INTERNAL_INVARIANT = 16,
  AGENTIC_AI_LAB_RUNTIME_V0_DUPLICATE_ACCEPTED = 17,
  AGENTIC_AI_LAB_RUNTIME_V0_PAYLOAD_BOUNDS = 18,
  AGENTIC_AI_LAB_RUNTIME_V0_STALE_GENERATION = 19,
  AGENTIC_AI_LAB_RUNTIME_V0_ARENA_BUSY = 20,
  AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_REPLAY = 21,
  AGENTIC_AI_LAB_RUNTIME_V0_EXECUTION_ROOT_FORK = 22,
  AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_BINDING_MISMATCH = 23,
  AGENTIC_AI_LAB_RUNTIME_V0_DIAGNOSTIC_CANNOT_EXECUTE = 24
};

typedef struct {
  uint64_t instance_id;
  uint64_t resource_id;
  uint32_t generation;
  uint32_t kind;
} agentic_ai_lab_runtime_v0_handle;

typedef struct {
  const uint8_t *ptr;
  uint64_t len;
} agentic_ai_lab_runtime_v0_bytes_view;

typedef struct {
  uint8_t *ptr;
  uint64_t len;
  uint64_t capacity;
  agentic_ai_lab_runtime_v0_handle owner;
} agentic_ai_lab_runtime_v0_owned_bytes;

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  agentic_ai_lab_runtime_v0_handle session;
  uint64_t mediation_sequence;
  uint64_t first_sequence;
  uint64_t last_sequence;
  agentic_ai_lab_runtime_v0_compact_id nonce;
  uint8_t semantic_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t before_execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} agentic_ai_lab_runtime_v0_evidence_reservation;

typedef struct {
  uint32_t struct_size;
  uint16_t abi_major;
  uint16_t abi_minor;
  uint64_t required_capabilities;
  uint64_t optional_capabilities;
  uint32_t concurrency_profile;
  uint32_t reserved0;
  uint64_t max_payload_bytes;
  agentic_ai_lab_runtime_v0_bytes_view bundle_schema;
  agentic_ai_lab_runtime_v0_bytes_view runtime_identity;
} agentic_ai_lab_runtime_v0_negotiate_request;

typedef struct {
  uint32_t struct_size;
  uint16_t abi_major;
  uint16_t abi_minor;
  uint64_t capabilities;
  uint32_t concurrency_profile;
  uint32_t reserved0;
  uint64_t max_payload_bytes;
  agentic_ai_lab_runtime_v0_handle profile;
} agentic_ai_lab_runtime_v0_negotiate_result;

typedef struct {
  uint32_t struct_size;
  uint32_t digest_algorithm;
  uint8_t digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint64_t bundle_epoch;
  agentic_ai_lab_runtime_v0_bytes_view schema;
  agentic_ai_lab_runtime_v0_bytes_view canonical_packet;
  uint64_t reserved0;
} agentic_ai_lab_runtime_v0_bundle_descriptor;

typedef struct {
  uint32_t struct_size;
  uint32_t close_disposition;
  uint64_t initial_sequence;
  uint64_t outstanding_work;
  uint64_t reserved0;
} agentic_ai_lab_runtime_v0_session_descriptor;

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  uint64_t mediation_sequence;
  uint64_t runtime_sequence;
  const agentic_ai_lab_runtime_v0_compact_id *consumed_nonces;
  uint64_t consumed_nonce_count;
  const uint64_t *staged_mediation_sequences;
  const uint8_t *staged_leaf_digests;
  uint64_t staged_leaf_digest_stride;
  uint64_t staged_leaf_count;
  uint8_t semantic_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} agentic_ai_lab_runtime_v0_evidence_reconciliation;

typedef struct {
  uint32_t struct_size;
  uint32_t alignment;
  uint8_t *ptr;
  uint64_t capacity;
  uint64_t generation;
  uint64_t reserved0;
} agentic_ai_lab_runtime_v0_arena_descriptor;

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  agentic_ai_lab_runtime_v0_handle arena;
  uint64_t arena_generation;
  const agentic_ai_lab_runtime_v0_event_header *headers;
  uint64_t header_stride;
  uint64_t item_count;
} agentic_ai_lab_runtime_v0_publish_request;

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  uint64_t published_count;
  uint64_t last_sequence;
} agentic_ai_lab_runtime_v0_publish_result;

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  agentic_ai_lab_runtime_v0_handle arena;
  uint64_t arena_generation;
  agentic_ai_lab_runtime_v0_event_header *headers;
  uint64_t header_stride;
  uint64_t header_capacity;
  uint64_t payload_capacity;
} agentic_ai_lab_runtime_v0_poll_request;

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  agentic_ai_lab_runtime_v0_handle lease;
  uint64_t arena_generation;
  uint64_t produced_count;
  uint64_t required_header_count;
  uint64_t required_payload_bytes;
  uint64_t first_sequence;
  uint64_t last_sequence;
} agentic_ai_lab_runtime_v0_poll_result;

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  agentic_ai_lab_runtime_v0_handle arena;
  uint64_t arena_generation;
  const agentic_ai_lab_runtime_v0_event_header *headers;
  uint64_t header_stride;
  uint64_t item_count;
  uint32_t *item_statuses;
  uint64_t item_status_capacity;
  uint8_t *accepted_bitmap;
  uint64_t accepted_bitmap_bytes;
} agentic_ai_lab_runtime_v0_submit_request;

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  uint64_t accepted_count;
  uint64_t rejected_count;
  uint64_t accepted_watermark;
} agentic_ai_lab_runtime_v0_submit_result;

enum {
  AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_STRICT = 1,
  AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_BATCHED = 2,
  AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_DIAGNOSTIC = 3,
  AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_COMMITTED = 1,
  AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_BUFFERED = 2,
  AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_INDETERMINATE = 4,
  AGENTIC_AI_LAB_RUNTIME_V0_EVIDENCE_SIGNATURE_VERIFIED = 1u << 0,
  AGENTIC_AI_LAB_RUNTIME_V0_EVIDENCE_INCLUSION_VERIFIED = 1u << 1
};

typedef struct {
  uint32_t struct_size;
  uint32_t outcome;
  agentic_ai_lab_runtime_v0_status adapter_status;
  uint32_t reserved0;
  uint8_t input_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t observation_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} agentic_ai_lab_runtime_v0_adapter_result;

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  agentic_ai_lab_runtime_v0_handle arena;
  agentic_ai_lab_runtime_v0_handle lease;
  uint64_t arena_generation;
  uint64_t first_sequence;
  uint64_t last_sequence;
  const agentic_ai_lab_runtime_v0_event_header *headers;
  uint64_t header_stride;
  uint64_t item_count;
  const uint8_t *payload;
  uint64_t payload_capacity;
} agentic_ai_lab_runtime_v0_adapter_invocation;

/*
 * The kernel calls execute synchronously after consuming the one-shot nonce.
 * Invocation views are borrowed and valid only for the duration of the call.
 * Implementations must not retain the pointers or re-enter strict_mediate.
 * A non-OK return produces an Indeterminate receipt and never restores nonce.
 */
typedef agentic_ai_lab_runtime_v0_status (*agentic_ai_lab_runtime_v0_adapter_execute_fn)(
    void *context, const agentic_ai_lab_runtime_v0_adapter_invocation *invocation,
    agentic_ai_lab_runtime_v0_adapter_result *result);

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  void *context;
  agentic_ai_lab_runtime_v0_adapter_execute_fn execute;
} agentic_ai_lab_runtime_v0_adapter_vtable;

typedef struct {
  uint32_t struct_size;
  uint32_t outcome;
  agentic_ai_lab_runtime_v0_status adapter_status;
  uint32_t reserved0;
  agentic_ai_lab_runtime_v0_handle session;
  uint64_t mediation_sequence;
  uint64_t first_sequence;
  uint64_t last_sequence;
  agentic_ai_lab_runtime_v0_compact_id nonce;
  uint8_t semantic_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t before_execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t input_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t observation_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} agentic_ai_lab_runtime_v0_evidence_invocation;

typedef struct {
  uint32_t struct_size;
  uint32_t verification_flags;
  uint32_t reserved0;
  uint32_t reserved1;
  uint8_t after_execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t evidence_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t attestation_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} agentic_ai_lab_runtime_v0_evidence_result;

typedef agentic_ai_lab_runtime_v0_status (*agentic_ai_lab_runtime_v0_evidence_finalize_fn)(
    void *context, const agentic_ai_lab_runtime_v0_evidence_invocation *invocation,
    agentic_ai_lab_runtime_v0_evidence_result *result);

typedef agentic_ai_lab_runtime_v0_status (*agentic_ai_lab_runtime_v0_evidence_reserve_fn)(
    void *context, const agentic_ai_lab_runtime_v0_evidence_reservation *reservation);

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  agentic_ai_lab_runtime_v0_handle session;
  uint64_t first_mediation_sequence;
  uint64_t last_mediation_sequence;
  const uint8_t *leaf_digests;
  uint64_t leaf_digest_stride;
  uint64_t leaf_count;
  uint8_t before_execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} agentic_ai_lab_runtime_v0_evidence_flush_invocation;

typedef struct {
  uint32_t struct_size;
  uint32_t verification_flags;
  uint32_t reserved0;
  uint32_t reserved1;
  uint8_t after_execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t batch_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t evidence_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t attestation_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} agentic_ai_lab_runtime_v0_evidence_flush_result;

typedef agentic_ai_lab_runtime_v0_status (*agentic_ai_lab_runtime_v0_evidence_flush_fn)(
    void *context,
    const agentic_ai_lab_runtime_v0_evidence_flush_invocation *invocation,
    agentic_ai_lab_runtime_v0_evidence_flush_result *result);

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  void *context;
  agentic_ai_lab_runtime_v0_evidence_reserve_fn reserve;
  agentic_ai_lab_runtime_v0_evidence_finalize_fn finalize;
  agentic_ai_lab_runtime_v0_evidence_flush_fn flush;
} agentic_ai_lab_runtime_v0_evidence_vtable;

typedef struct {
  uint32_t struct_size;
  uint32_t durability;
  uint32_t reserved0;
  uint32_t reserved1;
  agentic_ai_lab_runtime_v0_handle arena;
  agentic_ai_lab_runtime_v0_handle lease;
  uint64_t arena_generation;
  uint64_t bundle_epoch;
  uint64_t first_sequence;
  uint64_t last_sequence;
  agentic_ai_lab_runtime_v0_compact_id nonce;
  uint8_t semantic_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t before_execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  const agentic_ai_lab_runtime_v0_adapter_vtable *adapter;
  const agentic_ai_lab_runtime_v0_evidence_vtable *evidence;
} agentic_ai_lab_runtime_v0_strict_mediation_request;

typedef struct {
  uint32_t struct_size;
  uint32_t outcome;
  agentic_ai_lab_runtime_v0_status adapter_status;
  agentic_ai_lab_runtime_v0_status evidence_status;
  uint32_t verification_flags;
  uint32_t reserved0;
  uint64_t mediation_sequence;
  uint8_t execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t observation_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t evidence_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t attestation_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} agentic_ai_lab_runtime_v0_strict_mediation_result;

typedef struct {
  uint32_t struct_size;
  uint32_t reserved0;
  const agentic_ai_lab_runtime_v0_evidence_vtable *evidence;
  uint8_t expected_execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} agentic_ai_lab_runtime_v0_batched_flush_request;

typedef struct {
  uint32_t struct_size;
  uint32_t verification_flags;
  agentic_ai_lab_runtime_v0_status evidence_status;
  uint32_t reserved0;
  uint64_t leaf_count;
  uint64_t first_mediation_sequence;
  uint64_t last_mediation_sequence;
  uint8_t execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t batch_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t evidence_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t attestation_digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} agentic_ai_lab_runtime_v0_batched_flush_result;

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_instance_create(
    agentic_ai_lab_runtime_v0_handle *instance_out);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_instance_release(
    agentic_ai_lab_runtime_v0_handle instance);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_negotiate(
    agentic_ai_lab_runtime_v0_handle instance,
    const agentic_ai_lab_runtime_v0_negotiate_request *request,
    agentic_ai_lab_runtime_v0_negotiate_result *result);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_profile_release(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle profile);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_bundle_open(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle profile,
    const agentic_ai_lab_runtime_v0_bundle_descriptor *descriptor,
    agentic_ai_lab_runtime_v0_handle *bundle_out);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_bundle_release(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle bundle);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_open(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle bundle,
    const agentic_ai_lab_runtime_v0_session_descriptor *descriptor,
    agentic_ai_lab_runtime_v0_handle *session_out);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_cancel(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_close(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    uint32_t disposition);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_release(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_reconcile_evidence(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_evidence_reconciliation *reconciliation);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_checkpoint(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    agentic_ai_lab_runtime_v0_owned_bytes *checkpoint_out);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_restore(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle bundle,
    agentic_ai_lab_runtime_v0_bytes_view checkpoint,
    agentic_ai_lab_runtime_v0_handle *session_out);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_arena_register(
    agentic_ai_lab_runtime_v0_handle instance,
    const agentic_ai_lab_runtime_v0_arena_descriptor *descriptor,
    agentic_ai_lab_runtime_v0_handle *arena_out);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_arena_release(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle arena);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_publish_batch(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_publish_request *request,
    agentic_ai_lab_runtime_v0_publish_result *result);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_poll_batch(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_poll_request *request,
    agentic_ai_lab_runtime_v0_poll_result *result);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_submit_batch(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_submit_request *request,
    agentic_ai_lab_runtime_v0_submit_result *result);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_strict_mediate(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_strict_mediation_request *request,
    agentic_ai_lab_runtime_v0_strict_mediation_result *result);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_batched_flush(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_batched_flush_request *request,
    agentic_ai_lab_runtime_v0_batched_flush_result *result);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_batch_ack(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    agentic_ai_lab_runtime_v0_handle lease);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_arena_recycle(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle arena,
    uint64_t expected_generation, uint64_t next_generation);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_owned_bytes_release(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_owned_bytes *value);
agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_error_message(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_status status,
    agentic_ai_lab_runtime_v0_owned_bytes *message_out);
const char *agentic_ai_lab_runtime_v0_status_name(agentic_ai_lab_runtime_v0_status status);

#ifdef __cplusplus
}
#endif

#endif
