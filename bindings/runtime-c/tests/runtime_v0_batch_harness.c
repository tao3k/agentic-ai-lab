// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include <agentic_ai_lab/runtime_v0.h>

#include <assert.h>
#include <stdlib.h>
#include <string.h>

static void *runtime_aligned_alloc(size_t alignment, size_t size) {
#if defined(__APPLE__)
  void *memory = NULL;
  return posix_memalign(&memory, alignment, size) == 0 ? memory : NULL;
#else
  return aligned_alloc(alignment, size);
#endif
}

static agentic_ai_lab_runtime_v0_bytes_view view(const char *text) {
  agentic_ai_lab_runtime_v0_bytes_view value = {
      (const uint8_t *)text, (uint64_t)strlen(text)};
  return value;
}

static agentic_ai_lab_runtime_v0_event_header event(uint64_t sequence,
                                               uint64_t offset,
                                               uint64_t length) {
  agentic_ai_lab_runtime_v0_event_header header = {0};
  header.layout_version = AGENTIC_AI_LAB_RUNTIME_V0_LAYOUT_VERSION;
  header.event_kind = 1;
  header.sequence = sequence;
  header.event_identity.low = sequence;
  header.correlation_identity.low = sequence + 100;
  header.authorization_identity.low = sequence + 200;
  header.payload_offset = offset;
  header.payload_length = length;
  return header;
}

typedef struct {
  uint32_t calls;
  uint32_t outcome;
  agentic_ai_lab_runtime_v0_status status;
  uint64_t expected_first;
  uint64_t expected_last;
  uint64_t expected_count;
} adapter_fixture;

typedef struct {
  uint32_t reservation_calls;
  uint32_t calls;
  uint32_t flush_calls;
  agentic_ai_lab_runtime_v0_status reserve_status;
  agentic_ai_lab_runtime_v0_status finalize_status;
  agentic_ai_lab_runtime_v0_status flush_status;
  uint8_t after_root;
  uint64_t expected_flush_first;
  uint64_t expected_flush_last;
  uint64_t expected_flush_count;
} evidence_fixture;

static agentic_ai_lab_runtime_v0_status execute_adapter(
    void *context, const agentic_ai_lab_runtime_v0_adapter_invocation *invocation,
    agentic_ai_lab_runtime_v0_adapter_result *result) {
  adapter_fixture *fixture = context;
  assert(invocation->struct_size == sizeof(*invocation));
  assert(invocation->first_sequence == fixture->expected_first &&
         invocation->last_sequence == fixture->expected_last);
  assert(invocation->item_count == fixture->expected_count &&
         invocation->headers != NULL &&
         invocation->header_stride >= sizeof(*invocation->headers) &&
         invocation->payload != NULL && invocation->payload_capacity == 4096);
  ++fixture->calls;
  result->outcome = fixture->outcome;
  result->adapter_status = fixture->status;
  memset(result->input_digest, 0xba, sizeof(result->input_digest));
  memset(result->observation_digest, 0xbb,
         sizeof(result->observation_digest));
  return fixture->status;
}

static agentic_ai_lab_runtime_v0_status reserve_evidence(
    void *context, const agentic_ai_lab_runtime_v0_evidence_reservation *reservation) {
  evidence_fixture *fixture = context;
  assert(reservation->struct_size == sizeof(*reservation));
  ++fixture->reservation_calls;
  return fixture->reserve_status;
}

static agentic_ai_lab_runtime_v0_status finalize_evidence(
    void *context, const agentic_ai_lab_runtime_v0_evidence_invocation *invocation,
    agentic_ai_lab_runtime_v0_evidence_result *result) {
  evidence_fixture *fixture = context;
  assert(invocation->struct_size == sizeof(*invocation));
  assert(invocation->mediation_sequence == fixture->calls + 1u);
  assert(invocation->input_digest[0] == 0xba);
  ++fixture->calls;
  if (fixture->finalize_status != AGENTIC_AI_LAB_RUNTIME_V0_OK)
    return fixture->finalize_status;
  memset(result->after_execution_root, fixture->after_root,
         sizeof(result->after_execution_root));
  memset(result->evidence_digest, 0xcc, sizeof(result->evidence_digest));
  memset(result->attestation_digest, 0xdd,
         sizeof(result->attestation_digest));
  result->verification_flags =
      AGENTIC_AI_LAB_RUNTIME_V0_EVIDENCE_SIGNATURE_VERIFIED |
      AGENTIC_AI_LAB_RUNTIME_V0_EVIDENCE_INCLUSION_VERIFIED;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

static agentic_ai_lab_runtime_v0_status flush_evidence(
    void *context,
    const agentic_ai_lab_runtime_v0_evidence_flush_invocation *invocation,
    agentic_ai_lab_runtime_v0_evidence_flush_result *result) {
  evidence_fixture *fixture = context;
  ++fixture->flush_calls;
  if (fixture->flush_status != AGENTIC_AI_LAB_RUNTIME_V0_OK)
    return fixture->flush_status;
  assert(invocation->struct_size == sizeof(*invocation));
  assert(invocation->leaf_count != 0 && invocation->leaf_digests != NULL &&
         invocation->leaf_digest_stride >= AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  assert(invocation->first_mediation_sequence == fixture->expected_flush_first &&
         invocation->last_mediation_sequence == fixture->expected_flush_last &&
         invocation->leaf_count == fixture->expected_flush_count);
  memset(result->after_execution_root, 0xee,
         sizeof(result->after_execution_root));
  memset(result->batch_root, 0xff, sizeof(result->batch_root));
  memset(result->evidence_digest, 0xab, sizeof(result->evidence_digest));
  memset(result->attestation_digest, 0xcd,
         sizeof(result->attestation_digest));
  result->verification_flags = AGENTIC_AI_LAB_RUNTIME_V0_EVIDENCE_INCLUSION_VERIFIED;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

int main(void) {
  const char *schema = AGENTIC_AI_LAB_RUNTIME_V0_BUNDLE_SCHEMA;
  agentic_ai_lab_runtime_v0_handle instance = {0};
  assert(agentic_ai_lab_runtime_v0_instance_create(&instance) == AGENTIC_AI_LAB_RUNTIME_V0_OK);
  agentic_ai_lab_runtime_v0_negotiate_request negotiate = {0};
  negotiate.struct_size = sizeof(negotiate);
  negotiate.abi_minor = AGENTIC_AI_LAB_RUNTIME_V0_ABI_MINOR;
  negotiate.required_capabilities = AGENTIC_AI_LAB_RUNTIME_V0_CAP_CONTROL |
      AGENTIC_AI_LAB_RUNTIME_V0_CAP_HOT_BATCH |
      AGENTIC_AI_LAB_RUNTIME_V0_CAP_BULK_BUFFER |
      AGENTIC_AI_LAB_RUNTIME_V0_CAP_CALLER_ARENA |
      AGENTIC_AI_LAB_RUNTIME_V0_CAP_PARTIAL_ACCEPTANCE |
      AGENTIC_AI_LAB_RUNTIME_V0_CAP_BATCHED_EVIDENCE;
  negotiate.bundle_schema = view(schema);
  negotiate.runtime_identity = view("batch-harness");
  agentic_ai_lab_runtime_v0_negotiate_result negotiated = {0};
  negotiated.struct_size = sizeof(negotiated);
  assert(agentic_ai_lab_runtime_v0_negotiate(instance, &negotiate, &negotiated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);

  agentic_ai_lab_runtime_v0_bundle_descriptor bundle_desc = {0};
  bundle_desc.struct_size = sizeof(bundle_desc);
  memset(bundle_desc.digest, 0x44, sizeof(bundle_desc.digest));
  bundle_desc.bundle_epoch = 3;
  bundle_desc.schema = view(schema);
  bundle_desc.canonical_packet = view("bundle");
  agentic_ai_lab_runtime_v0_handle bundle = {0};
  assert(agentic_ai_lab_runtime_v0_bundle_open(instance, negotiated.profile,
                                         &bundle_desc, &bundle) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  agentic_ai_lab_runtime_v0_session_descriptor session_desc = {0};
  session_desc.struct_size = sizeof(session_desc);
  agentic_ai_lab_runtime_v0_handle session = {0};
  assert(agentic_ai_lab_runtime_v0_session_open(instance, bundle, &session_desc,
                                          &session) == AGENTIC_AI_LAB_RUNTIME_V0_OK);

  uint8_t *memory = runtime_aligned_alloc(16, 4096);
  assert(memory != NULL);
  memset(memory, 0x5a, 4096);
  agentic_ai_lab_runtime_v0_arena_descriptor arena_desc = {0};
  arena_desc.struct_size = sizeof(arena_desc);
  arena_desc.alignment = 16;
  arena_desc.ptr = memory;
  arena_desc.capacity = 4096;
  arena_desc.generation = 1;
  agentic_ai_lab_runtime_v0_handle arena = {0};
  assert(agentic_ai_lab_runtime_v0_arena_register(instance, &arena_desc, &arena) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);

  agentic_ai_lab_runtime_v0_event_header first = event(1, 0, 16);
  agentic_ai_lab_runtime_v0_event_header second = event(2, 64, 32);
  agentic_ai_lab_runtime_v0_event_header overflow = event(3, UINT64_MAX - 7u, 16);
  agentic_ai_lab_runtime_v0_publish_request publish = {0};
  publish.struct_size = sizeof(publish);
  publish.arena = arena;
  publish.arena_generation = 1;
  publish.headers = &overflow;
  publish.header_stride = sizeof(overflow);
  publish.item_count = 1;
  agentic_ai_lab_runtime_v0_publish_result published = {0};
  published.struct_size = sizeof(published);
  assert(agentic_ai_lab_runtime_v0_publish_batch(instance, session, &publish,
                                           &published) ==
         AGENTIC_AI_LAB_RUNTIME_V0_PAYLOAD_BOUNDS);
  agentic_ai_lab_runtime_v0_event_header inputs[2] = {first, second};
  publish.headers = inputs;
  publish.item_count = 2;
  publish.header_stride = sizeof(inputs[0]) - 1u;
  assert(agentic_ai_lab_runtime_v0_publish_batch(instance, session, &publish,
                                           &published) ==
         AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR);
  publish.header_stride = sizeof(inputs[0]);
  publish.item_count = UINT64_MAX;
  assert(agentic_ai_lab_runtime_v0_publish_batch(instance, session, &publish,
                                           &published) ==
         AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR);
  publish.item_count = 1025;
  assert(agentic_ai_lab_runtime_v0_publish_batch(instance, session, &publish,
                                           &published) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OUTSTANDING_WORK);
  publish.item_count = 2;
  inputs[1].sequence = 1;
  assert(agentic_ai_lab_runtime_v0_publish_batch(instance, session, &publish,
                                           &published) ==
         AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE);
  inputs[1] = second;
  assert(agentic_ai_lab_runtime_v0_publish_batch(instance, session, &publish,
                                           &published) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(published.published_count == 2 && published.last_sequence == 2);
  agentic_ai_lab_runtime_v0_event_header out[2] = {{0}};
  agentic_ai_lab_runtime_v0_poll_request poll = {0};
  poll.struct_size = sizeof(poll);
  poll.arena = arena;
  poll.arena_generation = 1;
  poll.headers = out;
  poll.header_stride = sizeof(*out);
  poll.header_capacity = 1;
  poll.payload_capacity = 4096;
  agentic_ai_lab_runtime_v0_poll_result polled = {0};
  polled.struct_size = sizeof(polled);
  poll.header_stride = sizeof(*out) - 1u;
  assert(agentic_ai_lab_runtime_v0_poll_batch(instance, session, &poll, &polled) ==
         AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR);
  poll.header_stride = sizeof(*out);
  assert(agentic_ai_lab_runtime_v0_poll_batch(instance, session, &poll, &polled) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(polled.produced_count == 0 && polled.required_header_count == 2);
  poll.header_capacity = 2;
  assert(agentic_ai_lab_runtime_v0_poll_batch(instance, session, &poll, &polled) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(polled.produced_count == 2 && out[1].sequence == 2);
  assert(agentic_ai_lab_runtime_v0_arena_recycle(instance, arena, 1, 2) ==
         AGENTIC_AI_LAB_RUNTIME_V0_ARENA_BUSY);

  uint32_t statuses[2] = {0};
  uint8_t bitmap[1] = {0};
  agentic_ai_lab_runtime_v0_submit_request submit = {0};
  submit.struct_size = sizeof(submit);
  submit.arena = arena;
  submit.arena_generation = 1;
  submit.headers = out;
  submit.header_stride = sizeof(*out);
  submit.item_count = 2;
  submit.item_statuses = statuses;
  submit.item_status_capacity = 2;
  submit.accepted_bitmap = bitmap;
  submit.accepted_bitmap_bytes = 1;
  agentic_ai_lab_runtime_v0_submit_result submitted = {0};
  submitted.struct_size = sizeof(submitted);
  submit.header_stride = sizeof(*out) - 1u;
  assert(agentic_ai_lab_runtime_v0_submit_batch(instance, session, &submit,
                                          &submitted) ==
         AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR);
  submit.header_stride = sizeof(*out);
  submit.accepted_bitmap_bytes = 0;
  assert(agentic_ai_lab_runtime_v0_submit_batch(instance, session, &submit,
                                          &submitted) ==
         AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR);
  submit.accepted_bitmap_bytes = 1;
  submit.item_count = UINT64_MAX;
  submit.item_status_capacity = UINT64_MAX;
  submit.accepted_bitmap_bytes = UINT64_MAX;
  assert(agentic_ai_lab_runtime_v0_submit_batch(instance, session, &submit,
                                          &submitted) ==
         AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR);
  submit.item_count = 2;
  submit.item_status_capacity = 2;
  submit.accepted_bitmap_bytes = 1;
  assert(agentic_ai_lab_runtime_v0_submit_batch(instance, session, &submit, &submitted) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(submitted.accepted_count == 2 && bitmap[0] == 3);
  agentic_ai_lab_runtime_v0_strict_mediation_request mediation = {0};
  mediation.struct_size = sizeof(mediation);
  mediation.durability = AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_STRICT;
  mediation.arena = arena;
  mediation.lease = polled.lease;
  mediation.arena_generation = 1;
  mediation.bundle_epoch = 3;
  mediation.first_sequence = 1;
  mediation.last_sequence = 2;
  mediation.nonce.low = 77;
  memset(mediation.semantic_root, 0x55, sizeof(mediation.semantic_root));
  adapter_fixture adapter_state = {
      0, AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_COMMITTED, AGENTIC_AI_LAB_RUNTIME_V0_OK,
      1, 2, 2};
  agentic_ai_lab_runtime_v0_adapter_vtable adapter = {
      sizeof(adapter), 0, &adapter_state, execute_adapter};
  evidence_fixture evidence_state = {
      0, 0, 0, AGENTIC_AI_LAB_RUNTIME_V0_OK, AGENTIC_AI_LAB_RUNTIME_V0_OK,
      AGENTIC_AI_LAB_RUNTIME_V0_OK, 0xaa, 0, 0, 0};
  agentic_ai_lab_runtime_v0_evidence_vtable evidence = {
      sizeof(evidence), 0, &evidence_state, reserve_evidence, finalize_evidence,
      flush_evidence};
  mediation.adapter = &adapter;
  mediation.evidence = &evidence;
  agentic_ai_lab_runtime_v0_strict_mediation_result mediated = {0};
  mediated.struct_size = sizeof(mediated);
  assert(agentic_ai_lab_runtime_v0_strict_mediate(instance, session, &mediation,
                                            &mediated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(adapter_state.calls == 1 && mediated.mediation_sequence == 1 &&
         mediated.outcome == AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_COMMITTED &&
         mediated.evidence_status == AGENTIC_AI_LAB_RUNTIME_V0_OK &&
         evidence_state.reservation_calls == 1 &&
         evidence_state.calls == 1 &&
         mediated.execution_root[0] == 0xaa);
  assert(agentic_ai_lab_runtime_v0_strict_mediate(instance, session, &mediation,
                                            &mediated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_EXECUTION_ROOT_FORK);
  memset(mediation.before_execution_root, 0xaa,
         sizeof(mediation.before_execution_root));
  assert(agentic_ai_lab_runtime_v0_strict_mediate(instance, session, &mediation,
                                            &mediated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_REPLAY);
  assert(adapter_state.calls == 1);
  mediation.nonce.low = 78;
  mediation.semantic_root[0] ^= 0xff;
  assert(agentic_ai_lab_runtime_v0_strict_mediate(instance, session, &mediation,
                                            &mediated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_BINDING_MISMATCH);
  mediation.semantic_root[0] ^= 0xff;
  adapter_state.status = AGENTIC_AI_LAB_RUNTIME_V0_INTERNAL_INVARIANT;
  assert(agentic_ai_lab_runtime_v0_strict_mediate(instance, session, &mediation,
                                            &mediated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(adapter_state.calls == 2 &&
         evidence_state.calls == 2 &&
         mediated.outcome == AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_INDETERMINATE &&
         mediated.adapter_status == AGENTIC_AI_LAB_RUNTIME_V0_INTERNAL_INVARIANT &&
         mediated.execution_root[0] == 0xaa);
  assert(agentic_ai_lab_runtime_v0_strict_mediate(instance, session, &mediation,
                                            &mediated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_REPLAY);
  mediation.nonce.low = 79;
  adapter_state.status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  adapter_state.outcome = AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_COMMITTED;
  evidence_state.finalize_status = AGENTIC_AI_LAB_RUNTIME_V0_INTERNAL_INVARIANT;
  assert(agentic_ai_lab_runtime_v0_strict_mediate(instance, session, &mediation,
                                            &mediated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(adapter_state.calls == 3 && evidence_state.calls == 3 &&
         mediated.outcome == AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_INDETERMINATE &&
         mediated.evidence_status == AGENTIC_AI_LAB_RUNTIME_V0_INTERNAL_INVARIANT &&
         mediated.execution_root[0] == 0xaa);
  mediation.nonce.low = 80;
  evidence_state.finalize_status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  evidence_state.reserve_status = AGENTIC_AI_LAB_RUNTIME_V0_INTERNAL_INVARIANT;
  assert(agentic_ai_lab_runtime_v0_strict_mediate(instance, session, &mediation,
                                            &mediated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_INTERNAL_INVARIANT);
  assert(adapter_state.calls == 3 && evidence_state.calls == 3 &&
         evidence_state.reservation_calls == 4);
  mediation.nonce.low = 81;
  mediation.durability = AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_DIAGNOSTIC;
  assert(agentic_ai_lab_runtime_v0_strict_mediate(instance, session, &mediation,
                                            &mediated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_DIAGNOSTIC_CANNOT_EXECUTE);
  submit.item_count = 1;
  assert(agentic_ai_lab_runtime_v0_submit_batch(instance, session, &submit, &submitted) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(statuses[0] == AGENTIC_AI_LAB_RUNTIME_V0_DUPLICATE_ACCEPTED);
  assert(agentic_ai_lab_runtime_v0_batch_ack(instance, session, polled.lease) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_arena_recycle(instance, arena, 1, 2) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  publish.headers = &first;
  publish.item_count = 1;
  assert(agentic_ai_lab_runtime_v0_publish_batch(instance, session, &publish,
                                           &published) ==
         AGENTIC_AI_LAB_RUNTIME_V0_STALE_GENERATION);

  assert(agentic_ai_lab_runtime_v0_arena_release(instance, arena) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  free(memory);
  assert(agentic_ai_lab_runtime_v0_session_close(instance, session, 1) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_session_release(instance, session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  agentic_ai_lab_runtime_v0_handle reconciled_session = {0};
  assert(agentic_ai_lab_runtime_v0_session_open(instance, bundle, &session_desc,
                                          &reconciled_session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  agentic_ai_lab_runtime_v0_compact_id reconciled_nonces[3] = {
      {0, 77}, {0, 78}, {0, 79}};
  agentic_ai_lab_runtime_v0_evidence_reconciliation reconciliation = {0};
  reconciliation.struct_size = sizeof(reconciliation);
  reconciliation.mediation_sequence = 3;
  reconciliation.runtime_sequence = 2;
  reconciliation.consumed_nonces = reconciled_nonces;
  reconciliation.consumed_nonce_count = 3;
  memset(reconciliation.semantic_root, 0x55,
         sizeof(reconciliation.semantic_root));
  memset(reconciliation.execution_root, 0xaa,
         sizeof(reconciliation.execution_root));
  assert(agentic_ai_lab_runtime_v0_session_reconcile_evidence(
             instance, reconciled_session, &reconciliation) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_session_reconcile_evidence(
             instance, reconciled_session, &reconciliation) ==
         AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE);
  assert(agentic_ai_lab_runtime_v0_session_close(instance, reconciled_session, 1) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_session_release(instance, reconciled_session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  agentic_ai_lab_runtime_v0_handle duplicate_session = {0};
  assert(agentic_ai_lab_runtime_v0_session_open(instance, bundle, &session_desc,
                                          &duplicate_session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  reconciled_nonces[2] = reconciled_nonces[1];
  assert(agentic_ai_lab_runtime_v0_session_reconcile_evidence(
             instance, duplicate_session, &reconciliation) ==
         AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_REPLAY);
  reconciled_nonces[2].low = 79;
  uint64_t staged_sequences[2] = {3, 2};
  uint8_t staged_digests[2][AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES] = {{0}};
  memset(staged_digests[0], 0xc1, sizeof(staged_digests[0]));
  memset(staged_digests[1], 0xc2, sizeof(staged_digests[1]));
  reconciliation.staged_mediation_sequences = staged_sequences;
  reconciliation.staged_leaf_digests = &staged_digests[0][0];
  reconciliation.staged_leaf_digest_stride = sizeof(staged_digests[0]);
  reconciliation.staged_leaf_count = 2;
  assert(agentic_ai_lab_runtime_v0_session_reconcile_evidence(
             instance, duplicate_session, &reconciliation) ==
         AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR);
  staged_sequences[0] = 2;
  staged_sequences[1] = 3;
  assert(agentic_ai_lab_runtime_v0_session_reconcile_evidence(
             instance, duplicate_session, &reconciliation) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  evidence_state.flush_calls = 0;
  evidence_state.flush_status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  evidence_state.expected_flush_first = 2;
  evidence_state.expected_flush_last = 3;
  evidence_state.expected_flush_count = 2;
  agentic_ai_lab_runtime_v0_batched_flush_request recovered_flush_request = {0};
  recovered_flush_request.struct_size = sizeof(recovered_flush_request);
  recovered_flush_request.evidence = &evidence;
  memset(recovered_flush_request.expected_execution_root, 0xaa,
         sizeof(recovered_flush_request.expected_execution_root));
  agentic_ai_lab_runtime_v0_batched_flush_result recovered_flush_result = {0};
  recovered_flush_result.struct_size = sizeof(recovered_flush_result);
  assert(agentic_ai_lab_runtime_v0_batched_flush(
             instance, duplicate_session, &recovered_flush_request,
             &recovered_flush_result) == AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(recovered_flush_result.leaf_count == 2 &&
         recovered_flush_result.first_mediation_sequence == 2 &&
         recovered_flush_result.last_mediation_sequence == 3 &&
         recovered_flush_result.execution_root[0] == 0xee &&
         evidence_state.flush_calls == 1);
  assert(agentic_ai_lab_runtime_v0_session_close(instance, duplicate_session, 1) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_session_release(instance, duplicate_session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  agentic_ai_lab_runtime_v0_handle batched_session = {0};
  assert(agentic_ai_lab_runtime_v0_session_open(instance, bundle, &session_desc,
                                          &batched_session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  uint8_t *batched_memory = runtime_aligned_alloc(16, 4096);
  assert(batched_memory != NULL);
  agentic_ai_lab_runtime_v0_arena_descriptor batched_arena_desc = {0};
  batched_arena_desc.struct_size = sizeof(batched_arena_desc);
  batched_arena_desc.alignment = 16;
  batched_arena_desc.ptr = batched_memory;
  batched_arena_desc.capacity = 4096;
  batched_arena_desc.generation = 1;
  agentic_ai_lab_runtime_v0_handle batched_arena = {0};
  assert(agentic_ai_lab_runtime_v0_arena_register(instance, &batched_arena_desc,
                                            &batched_arena) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  agentic_ai_lab_runtime_v0_event_header batched_event = event(1, 0, 0);
  agentic_ai_lab_runtime_v0_publish_request batched_publish = {0};
  batched_publish.struct_size = sizeof(batched_publish);
  batched_publish.arena = batched_arena;
  batched_publish.arena_generation = 1;
  batched_publish.headers = &batched_event;
  batched_publish.header_stride = sizeof(batched_event);
  batched_publish.item_count = 1;
  agentic_ai_lab_runtime_v0_publish_result batched_published = {0};
  batched_published.struct_size = sizeof(batched_published);
  assert(agentic_ai_lab_runtime_v0_publish_batch(instance, batched_session,
                                           &batched_publish,
                                           &batched_published) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  agentic_ai_lab_runtime_v0_event_header batched_output = {0};
  agentic_ai_lab_runtime_v0_poll_request batched_poll = {0};
  batched_poll.struct_size = sizeof(batched_poll);
  batched_poll.arena = batched_arena;
  batched_poll.arena_generation = 1;
  batched_poll.headers = &batched_output;
  batched_poll.header_stride = sizeof(batched_output);
  batched_poll.header_capacity = 1;
  batched_poll.payload_capacity = 4096;
  agentic_ai_lab_runtime_v0_poll_result batched_polled = {0};
  batched_polled.struct_size = sizeof(batched_polled);
  assert(agentic_ai_lab_runtime_v0_poll_batch(instance, batched_session,
                                        &batched_poll, &batched_polled) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  adapter_state.calls = 0;
  adapter_state.status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  adapter_state.outcome = AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_COMMITTED;
  adapter_state.expected_first = 1;
  adapter_state.expected_last = 1;
  adapter_state.expected_count = 1;
  evidence_state.reservation_calls = 0;
  evidence_state.calls = 0;
  evidence_state.flush_calls = 0;
  evidence_state.reserve_status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  evidence_state.finalize_status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  evidence_state.flush_status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  evidence_state.after_root = 0;
  evidence_state.expected_flush_first = 1;
  evidence_state.expected_flush_last = 1;
  evidence_state.expected_flush_count = 1;
  agentic_ai_lab_runtime_v0_strict_mediation_request batched_mediation = {0};
  batched_mediation.struct_size = sizeof(batched_mediation);
  batched_mediation.durability = AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_BATCHED;
  batched_mediation.arena = batched_arena;
  batched_mediation.lease = batched_polled.lease;
  batched_mediation.arena_generation = 1;
  batched_mediation.bundle_epoch = 3;
  batched_mediation.first_sequence = 1;
  batched_mediation.last_sequence = 1;
  batched_mediation.nonce.low = 100;
  memset(batched_mediation.semantic_root, 0x66,
         sizeof(batched_mediation.semantic_root));
  batched_mediation.adapter = &adapter;
  batched_mediation.evidence = &evidence;
  agentic_ai_lab_runtime_v0_strict_mediation_result buffered = {0};
  buffered.struct_size = sizeof(buffered);
  assert(agentic_ai_lab_runtime_v0_strict_mediate(
             instance, batched_session, &batched_mediation, &buffered) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(buffered.outcome == AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_BUFFERED &&
         buffered.execution_root[0] == 0 && adapter_state.calls == 1 &&
         evidence_state.calls == 1);
  agentic_ai_lab_runtime_v0_batched_flush_request flush_request = {0};
  flush_request.struct_size = sizeof(flush_request);
  flush_request.evidence = &evidence;
  agentic_ai_lab_runtime_v0_batched_flush_result flush_result = {0};
  flush_result.struct_size = sizeof(flush_result);
  assert(agentic_ai_lab_runtime_v0_batched_flush(
             instance, batched_session, &flush_request, &flush_result) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(flush_result.leaf_count == 1 && flush_result.execution_root[0] == 0xee &&
         flush_result.batch_root[0] == 0xff && evidence_state.flush_calls == 1);
  assert(agentic_ai_lab_runtime_v0_batched_flush(
             instance, batched_session, &flush_request, &flush_result) ==
         AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE);
  assert(agentic_ai_lab_runtime_v0_batch_ack(instance, batched_session,
                                       batched_polled.lease) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_arena_release(instance, batched_arena) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  free(batched_memory);
  assert(agentic_ai_lab_runtime_v0_session_close(instance, batched_session, 1) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_session_release(instance, batched_session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_bundle_release(instance, bundle) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_profile_release(instance, negotiated.profile) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_instance_release(instance) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  return 0;
}
