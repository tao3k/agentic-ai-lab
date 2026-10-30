// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include <agentic_ai_lab/runtime_v0.h>

#include <stdlib.h>
#include <string.h>

#define MAX_RESOURCES 256u
#define KIND_INSTANCE 1u
#define KIND_PROFILE 2u
#define KIND_BUNDLE 3u
#define KIND_SESSION 4u
#define KIND_BYTES 5u
#define KIND_ARENA 6u
#define KIND_LEASE 7u
#define STATE_OPEN 1u
#define STATE_CANCELLED 2u
#define STATE_CLOSED 3u
#define CHECKPOINT_MAGIC UINT64_C(0x504f4f4350303031)
#define MAX_PENDING_EVENTS 1024u
#define MAX_CONSUMED_NONCES 1024u
#define NONCE_TABLE_CAPACITY 2048u
#define MAX_STAGED_LEAVES 1024u

typedef struct {
  agentic_ai_lab_runtime_v0_event_header header;
  uint64_t arena_id;
  uint64_t arena_generation;
  uint8_t polled;
  uint8_t accepted;
  uint8_t acknowledged;
  uint8_t reserved[5];
} pending_event;

typedef struct {
  uint64_t mediation_sequence;
  uint8_t digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
} staged_leaf;

typedef struct {
  uint8_t alive;
  uint8_t released;
  uint16_t reserved;
  uint32_t kind;
  uint32_t generation;
  uint32_t state;
  uint64_t instance_id;
  uint64_t parent_id;
  uint64_t epoch;
  uint64_t sequence;
  uint64_t capabilities;
  uint64_t outstanding;
  uint8_t digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t *bytes;
  uint64_t bytes_len;
  uint8_t *arena_ptr;
  uint64_t arena_capacity;
  uint64_t arena_generation;
  uint64_t inflight_count;
  pending_event *pending;
  uint64_t pending_count;
  uint64_t pending_capacity;
  uint64_t poll_cursor;
  uint64_t lease_first_sequence;
  uint64_t lease_last_sequence;
  agentic_ai_lab_runtime_v0_compact_id consumed_nonces[NONCE_TABLE_CAPACITY];
  uint8_t consumed_nonce_used[NONCE_TABLE_CAPACITY];
  uint64_t consumed_nonce_count;
  uint8_t semantic_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint8_t semantic_root_bound;
  uint8_t execution_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint64_t mediation_sequence;
  staged_leaf staged_leaves[MAX_STAGED_LEAVES];
  uint64_t staged_leaf_count;
} resource;

typedef struct {
  uint64_t magic;
  uint64_t epoch;
  uint64_t sequence;
  uint32_t state;
  uint32_t reserved;
  uint8_t digest[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES];
  uint64_t checksum;
} checkpoint_packet;

static resource resources[MAX_RESOURCES];
static uint64_t next_instance_id = 1;
static const char bundle_schema[] = AGENTIC_AI_LAB_RUNTIME_V0_BUNDLE_SCHEMA;

static agentic_ai_lab_runtime_v0_handle null_handle(void) {
  agentic_ai_lab_runtime_v0_handle value = {0, 0, 0, 0};
  return value;
}

static int bytes_equal(agentic_ai_lab_runtime_v0_bytes_view value, const char *text) {
  size_t len = strlen(text);
  return value.ptr != NULL && value.len == (uint64_t)len &&
         memcmp(value.ptr, text, len) == 0;
}

static uint64_t checksum_bytes(const uint8_t *bytes, uint64_t len) {
  uint64_t value = UINT64_C(1469598103934665603);
  for (uint64_t i = 0; i < len; ++i) {
    value ^= bytes[i];
    value *= UINT64_C(1099511628211);
  }
  return value;
}

static int power_of_two(uint32_t value) {
  return value != 0 && (value & (value - 1u)) == 0;
}

static int slice_in_bounds(uint64_t offset, uint64_t length, uint64_t capacity) {
  return offset <= capacity && length <= capacity - offset;
}

static uint64_t pending_lower_bound(resource *session, uint64_t sequence) {
  uint64_t left = 0;
  uint64_t right = session->pending_count;
  while (left < right) {
    uint64_t middle = left + (right - left) / 2;
    uint64_t observed = session->pending[middle].header.sequence;
    if (observed < sequence) left = middle + 1;
    else if (observed > sequence) right = middle;
    else return middle;
  }
  return left;
}

static int nonce_equal(agentic_ai_lab_runtime_v0_compact_id left,
                       agentic_ai_lab_runtime_v0_compact_id right) {
  return left.high == right.high && left.low == right.low;
}

static uint64_t mix64(uint64_t value) {
  value ^= value >> 30;
  value *= UINT64_C(0xbf58476d1ce4e5b9);
  value ^= value >> 27;
  value *= UINT64_C(0x94d049bb133111eb);
  return value ^ (value >> 31);
}

static uint64_t nonce_slot(resource *session,
                           agentic_ai_lab_runtime_v0_compact_id nonce,
                           int *found) {
  uint64_t index = mix64(nonce.high ^ mix64(nonce.low)) &
                   (NONCE_TABLE_CAPACITY - 1u);
  for (uint64_t probe = 0; probe < NONCE_TABLE_CAPACITY; ++probe) {
    if (!session->consumed_nonce_used[index]) {
      *found = 0;
      return index;
    }
    if (nonce_equal(session->consumed_nonces[index], nonce)) {
      *found = 1;
      return index;
    }
    index = (index + 1u) & (NONCE_TABLE_CAPACITY - 1u);
  }
  *found = 0;
  return NONCE_TABLE_CAPACITY;
}

static resource *slot(uint64_t resource_id) {
  if (resource_id == 0 || resource_id > MAX_RESOURCES) return NULL;
  return &resources[resource_id - 1];
}

static agentic_ai_lab_runtime_v0_status resolve(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle handle,
    uint32_t kind, resource **out) {
  resource *entry = slot(handle.resource_id);
  if (handle.instance_id != instance.instance_id)
    return AGENTIC_AI_LAB_RUNTIME_V0_CROSS_INSTANCE_HANDLE;
  if (handle.kind != kind) return AGENTIC_AI_LAB_RUNTIME_V0_WRONG_HANDLE_KIND;
  if (entry == NULL || entry->generation != handle.generation)
    return AGENTIC_AI_LAB_RUNTIME_V0_STALE_HANDLE;
  if (entry->released) return AGENTIC_AI_LAB_RUNTIME_V0_ALREADY_RELEASED;
  if (!entry->alive) return AGENTIC_AI_LAB_RUNTIME_V0_STALE_HANDLE;
  if (entry->instance_id != instance.instance_id)
    return AGENTIC_AI_LAB_RUNTIME_V0_CROSS_INSTANCE_HANDLE;
  *out = entry;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

static agentic_ai_lab_runtime_v0_status instance_entry(
    agentic_ai_lab_runtime_v0_handle instance, resource **out) {
  return resolve(instance, instance, KIND_INSTANCE, out);
}

static agentic_ai_lab_runtime_v0_status allocate_resource(
    uint64_t instance_id, uint32_t kind, agentic_ai_lab_runtime_v0_handle *out) {
  for (uint64_t i = 0; i < MAX_RESOURCES; ++i) {
    resource *entry = &resources[i];
    if (!entry->alive) {
      uint32_t generation = entry->generation + 1u;
      if (generation == 0) generation = 1;
      memset(entry, 0, sizeof(*entry));
      entry->alive = 1;
      entry->kind = kind;
      entry->generation = generation;
      entry->instance_id = instance_id;
      out->instance_id = instance_id;
      out->resource_id = i + 1;
      out->generation = generation;
      out->kind = kind;
      return AGENTIC_AI_LAB_RUNTIME_V0_OK;
    }
  }
  return AGENTIC_AI_LAB_RUNTIME_V0_ALLOCATION_FAILURE;
}

static agentic_ai_lab_runtime_v0_status release_resource(resource *entry) {
  if (entry->bytes != NULL) free(entry->bytes);
  if (entry->pending != NULL) free(entry->pending);
  entry->bytes = NULL;
  entry->bytes_len = 0;
  entry->pending = NULL;
  entry->pending_count = 0;
  entry->pending_capacity = 0;
  entry->released = 1;
  entry->alive = 0;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_instance_create(
    agentic_ai_lab_runtime_v0_handle *instance_out) {
  if (instance_out == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  agentic_ai_lab_runtime_v0_status status =
      allocate_resource(next_instance_id++, KIND_INSTANCE, instance_out);
  return status;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_instance_release(
    agentic_ai_lab_runtime_v0_handle instance) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = instance_entry(instance, &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  for (uint64_t i = 0; i < MAX_RESOURCES; ++i)
    if (resources[i].alive && resources[i].instance_id == instance.instance_id &&
        resources[i].kind != KIND_INSTANCE)
      return AGENTIC_AI_LAB_RUNTIME_V0_OUTSTANDING_WORK;
  return release_resource(entry);
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_negotiate(
    agentic_ai_lab_runtime_v0_handle instance,
    const agentic_ai_lab_runtime_v0_negotiate_request *request,
    agentic_ai_lab_runtime_v0_negotiate_result *result) {
  resource *ignored = NULL;
  agentic_ai_lab_runtime_v0_status status = instance_entry(instance, &ignored);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (request == NULL || result == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  if (request->struct_size != sizeof(*request) ||
      result->struct_size != sizeof(*result) || request->reserved0 != 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  if (request->abi_major != AGENTIC_AI_LAB_RUNTIME_V0_ABI_MAJOR ||
      request->abi_minor > AGENTIC_AI_LAB_RUNTIME_V0_ABI_MINOR)
    return AGENTIC_AI_LAB_RUNTIME_V0_INCOMPATIBLE_ABI;
  if (!bytes_equal(request->bundle_schema, bundle_schema))
    return AGENTIC_AI_LAB_RUNTIME_V0_INCOMPATIBLE_SCHEMA;
  const uint64_t supported = AGENTIC_AI_LAB_RUNTIME_V0_CAP_CONTROL |
                             AGENTIC_AI_LAB_RUNTIME_V0_CAP_CHECKPOINT |
                             AGENTIC_AI_LAB_RUNTIME_V0_CAP_HOT_BATCH |
                             AGENTIC_AI_LAB_RUNTIME_V0_CAP_BULK_BUFFER |
                             AGENTIC_AI_LAB_RUNTIME_V0_CAP_CALLER_ARENA |
                             AGENTIC_AI_LAB_RUNTIME_V0_CAP_PARTIAL_ACCEPTANCE |
                             AGENTIC_AI_LAB_RUNTIME_V0_CAP_BATCHED_EVIDENCE;
  if ((request->required_capabilities & ~supported) != 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_UNSUPPORTED_CAPABILITY;
  agentic_ai_lab_runtime_v0_handle profile = null_handle();
  status = allocate_resource(instance.instance_id, KIND_PROFILE, &profile);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  result->abi_major = AGENTIC_AI_LAB_RUNTIME_V0_ABI_MAJOR;
  result->abi_minor = AGENTIC_AI_LAB_RUNTIME_V0_ABI_MINOR;
  result->capabilities = supported &
      (request->required_capabilities | request->optional_capabilities);
  result->concurrency_profile = 0;
  result->reserved0 = 0;
  result->max_payload_bytes = request->max_payload_bytes;
  result->profile = profile;
  slot(profile.resource_id)->capabilities = result->capabilities;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_profile_release(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle profile) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, profile, KIND_PROFILE, &entry);
  return status == AGENTIC_AI_LAB_RUNTIME_V0_OK ? release_resource(entry) : status;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_bundle_open(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle profile,
    const agentic_ai_lab_runtime_v0_bundle_descriptor *descriptor,
    agentic_ai_lab_runtime_v0_handle *bundle_out) {
  resource *profile_entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, profile, KIND_PROFILE,
                                               &profile_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (descriptor == NULL || bundle_out == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  if (descriptor->struct_size != sizeof(*descriptor) || descriptor->reserved0 != 0 ||
      descriptor->canonical_packet.ptr == NULL || descriptor->canonical_packet.len == 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  if (!bytes_equal(descriptor->schema, bundle_schema))
    return AGENTIC_AI_LAB_RUNTIME_V0_INCOMPATIBLE_SCHEMA;
  status = allocate_resource(instance.instance_id, KIND_BUNDLE, bundle_out);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  resource *entry = slot(bundle_out->resource_id);
  entry->parent_id = profile.resource_id;
  entry->capabilities = profile_entry->capabilities;
  entry->epoch = descriptor->bundle_epoch;
  memcpy(entry->digest, descriptor->digest, sizeof(entry->digest));
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_bundle_release(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle bundle) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, bundle, KIND_BUNDLE, &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  for (uint64_t i = 0; i < MAX_RESOURCES; ++i)
    if (resources[i].alive && resources[i].kind == KIND_SESSION &&
        resources[i].parent_id == bundle.resource_id)
      return AGENTIC_AI_LAB_RUNTIME_V0_OUTSTANDING_WORK;
  return release_resource(entry);
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_open(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle bundle,
    const agentic_ai_lab_runtime_v0_session_descriptor *descriptor,
    agentic_ai_lab_runtime_v0_handle *session_out) {
  resource *bundle_entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, bundle, KIND_BUNDLE,
                                               &bundle_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (descriptor == NULL || session_out == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  if (descriptor->struct_size != sizeof(*descriptor) || descriptor->reserved0 != 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  status = allocate_resource(instance.instance_id, KIND_SESSION, session_out);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  resource *entry = slot(session_out->resource_id);
  entry->pending = (pending_event *)calloc(MAX_PENDING_EVENTS,
                                           sizeof(*entry->pending));
  if (entry->pending == NULL) {
    release_resource(entry);
    return AGENTIC_AI_LAB_RUNTIME_V0_ALLOCATION_FAILURE;
  }
  entry->pending_capacity = MAX_PENDING_EVENTS;
  entry->state = STATE_OPEN;
  entry->parent_id = bundle.resource_id;
  entry->capabilities = bundle_entry->capabilities;
  entry->epoch = bundle_entry->epoch;
  entry->sequence = descriptor->initial_sequence;
  entry->outstanding = descriptor->outstanding_work;
  memcpy(entry->digest, bundle_entry->digest, sizeof(entry->digest));
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_cancel(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION, &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (entry->state == STATE_CLOSED) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE;
  entry->state = STATE_CANCELLED;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_reconcile_evidence(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_evidence_reconciliation *reconciliation) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION,
                                               &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (reconciliation == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  if (reconciliation->struct_size != sizeof(*reconciliation) ||
      reconciliation->reserved0 != 0 ||
      reconciliation->consumed_nonce_count > MAX_CONSUMED_NONCES ||
      reconciliation->staged_leaf_count > MAX_STAGED_LEAVES ||
      reconciliation->staged_leaf_count >
          reconciliation->consumed_nonce_count ||
      reconciliation->consumed_nonce_count !=
          reconciliation->mediation_sequence ||
      (reconciliation->consumed_nonce_count != 0 &&
       reconciliation->consumed_nonces == NULL) ||
      (reconciliation->staged_leaf_count != 0 &&
       (reconciliation->staged_mediation_sequences == NULL ||
        reconciliation->staged_leaf_digests == NULL ||
        reconciliation->staged_leaf_digest_stride <
            AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES)))
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  for (uint64_t i = 0; i < reconciliation->staged_leaf_count; ++i) {
    if (reconciliation->staged_mediation_sequences[i] == 0 ||
        reconciliation->staged_mediation_sequences[i] >
            reconciliation->mediation_sequence ||
        (i != 0 && reconciliation->staged_mediation_sequences[i] <=
                       reconciliation->staged_mediation_sequences[i - 1u]))
      return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  }
  uint8_t zero_root[AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES] = {0};
  if (entry->state != STATE_OPEN || entry->pending_count != 0 ||
      entry->outstanding != 0 || entry->mediation_sequence != 0 ||
      entry->consumed_nonce_count != 0 || entry->semantic_root_bound ||
      memcmp(entry->execution_root, zero_root, sizeof(zero_root)) != 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE;
  for (uint64_t i = 0; i < reconciliation->consumed_nonce_count; ++i) {
    int found = 0;
    uint64_t index = nonce_slot(entry, reconciliation->consumed_nonces[i],
                                &found);
    if (found || index == NONCE_TABLE_CAPACITY) {
      memset(entry->consumed_nonce_used, 0,
             sizeof(entry->consumed_nonce_used));
      memset(entry->consumed_nonces, 0, sizeof(entry->consumed_nonces));
      entry->consumed_nonce_count = 0;
      return AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_REPLAY;
    }
    entry->consumed_nonces[index] = reconciliation->consumed_nonces[i];
    entry->consumed_nonce_used[index] = 1;
    ++entry->consumed_nonce_count;
  }
  memcpy(entry->semantic_root, reconciliation->semantic_root,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  entry->semantic_root_bound = 1;
  memcpy(entry->execution_root, reconciliation->execution_root,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  entry->mediation_sequence = reconciliation->mediation_sequence;
  entry->sequence = reconciliation->runtime_sequence;
  for (uint64_t i = 0; i < reconciliation->staged_leaf_count; ++i) {
    staged_leaf *leaf = &entry->staged_leaves[i];
    leaf->mediation_sequence = reconciliation->staged_mediation_sequences[i];
    memcpy(leaf->digest,
           reconciliation->staged_leaf_digests +
               i * reconciliation->staged_leaf_digest_stride,
           AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
    ++entry->staged_leaf_count;
  }
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_close(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    uint32_t disposition) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION, &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (entry->state == STATE_CLOSED) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE;
  if (entry->outstanding != 0 && disposition == 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_OUTSTANDING_WORK;
  entry->outstanding = 0;
  entry->state = STATE_CLOSED;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_release(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION, &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (entry->state != STATE_CLOSED) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE;
  return release_resource(entry);
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_checkpoint(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    agentic_ai_lab_runtime_v0_owned_bytes *checkpoint_out) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION, &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (checkpoint_out == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  checkpoint_packet *packet = (checkpoint_packet *)calloc(1, sizeof(*packet));
  if (packet == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_ALLOCATION_FAILURE;
  packet->magic = CHECKPOINT_MAGIC;
  packet->epoch = entry->epoch;
  packet->sequence = entry->sequence;
  packet->state = entry->state;
  memcpy(packet->digest, entry->digest, sizeof(packet->digest));
  packet->checksum = checksum_bytes((const uint8_t *)packet,
                                    sizeof(*packet) - sizeof(packet->checksum));
  agentic_ai_lab_runtime_v0_handle owner = null_handle();
  status = allocate_resource(instance.instance_id, KIND_BYTES, &owner);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) { free(packet); return status; }
  resource *bytes_entry = slot(owner.resource_id);
  bytes_entry->bytes = (uint8_t *)packet;
  bytes_entry->bytes_len = sizeof(*packet);
  checkpoint_out->ptr = (uint8_t *)packet;
  checkpoint_out->len = sizeof(*packet);
  checkpoint_out->capacity = sizeof(*packet);
  checkpoint_out->owner = owner;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_session_restore(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle bundle,
    agentic_ai_lab_runtime_v0_bytes_view checkpoint,
    agentic_ai_lab_runtime_v0_handle *session_out) {
  resource *bundle_entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, bundle, KIND_BUNDLE,
                                               &bundle_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (checkpoint.ptr == NULL || checkpoint.len != sizeof(checkpoint_packet) ||
      session_out == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_CHECKPOINT_INCOMPATIBLE;
  checkpoint_packet packet;
  memcpy(&packet, checkpoint.ptr, sizeof(packet));
  uint64_t checksum = checksum_bytes((const uint8_t *)&packet,
                                     sizeof(packet) - sizeof(packet.checksum));
  if (packet.magic != CHECKPOINT_MAGIC || packet.reserved != 0 ||
      packet.checksum != checksum)
    return AGENTIC_AI_LAB_RUNTIME_V0_CHECKPOINT_INCOMPATIBLE;
  if (packet.epoch != bundle_entry->epoch ||
      memcmp(packet.digest, bundle_entry->digest, sizeof(packet.digest)) != 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_BUNDLE_IDENTITY_MISMATCH;
  status = allocate_resource(instance.instance_id, KIND_SESSION, session_out);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  resource *entry = slot(session_out->resource_id);
  entry->pending = (pending_event *)calloc(MAX_PENDING_EVENTS,
                                           sizeof(*entry->pending));
  if (entry->pending == NULL) {
    release_resource(entry);
    return AGENTIC_AI_LAB_RUNTIME_V0_ALLOCATION_FAILURE;
  }
  entry->pending_capacity = MAX_PENDING_EVENTS;
  entry->state = packet.state == STATE_CLOSED ? STATE_OPEN : packet.state;
  entry->parent_id = bundle.resource_id;
  entry->capabilities = bundle_entry->capabilities;
  entry->epoch = packet.epoch;
  entry->sequence = packet.sequence;
  memcpy(entry->digest, packet.digest, sizeof(entry->digest));
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_arena_register(
    agentic_ai_lab_runtime_v0_handle instance,
    const agentic_ai_lab_runtime_v0_arena_descriptor *descriptor,
    agentic_ai_lab_runtime_v0_handle *arena_out) {
  resource *ignored = NULL;
  agentic_ai_lab_runtime_v0_status status = instance_entry(instance, &ignored);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (descriptor == NULL || arena_out == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  if (descriptor->struct_size != sizeof(*descriptor) || descriptor->reserved0 != 0 ||
      descriptor->ptr == NULL || descriptor->capacity == 0 ||
      !power_of_two(descriptor->alignment) || descriptor->alignment < 16 ||
      ((uintptr_t)descriptor->ptr % descriptor->alignment) != 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  status = allocate_resource(instance.instance_id, KIND_ARENA, arena_out);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  resource *entry = slot(arena_out->resource_id);
  entry->arena_ptr = descriptor->ptr;
  entry->arena_capacity = descriptor->capacity;
  entry->arena_generation = descriptor->generation;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_arena_release(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle arena) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, arena, KIND_ARENA, &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (entry->inflight_count != 0) return AGENTIC_AI_LAB_RUNTIME_V0_ARENA_BUSY;
  entry->arena_ptr = NULL;
  entry->arena_capacity = 0;
  return release_resource(entry);
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_publish_batch(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_publish_request *request,
    agentic_ai_lab_runtime_v0_publish_result *result) {
  resource *session_entry = NULL;
  resource *arena_entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION,
                                               &session_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (request == NULL || result == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  if (request->struct_size != sizeof(*request) ||
      result->struct_size != sizeof(*result) || request->reserved0 != 0 ||
      result->reserved0 != 0 ||
      request->header_stride != sizeof(agentic_ai_lab_runtime_v0_event_header) ||
      request->item_count > SIZE_MAX / request->header_stride ||
      (request->item_count != 0 && request->headers == NULL))
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  status = resolve(instance, request->arena, KIND_ARENA, &arena_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (arena_entry->arena_generation != request->arena_generation)
    return AGENTIC_AI_LAB_RUNTIME_V0_STALE_GENERATION;
  if (request->item_count >
      session_entry->pending_capacity - session_entry->pending_count)
    return AGENTIC_AI_LAB_RUNTIME_V0_OUTSTANDING_WORK;
  uint64_t previous_sequence = session_entry->pending_count == 0
      ? 0
      : session_entry->pending[session_entry->pending_count - 1].header.sequence;
  for (uint64_t i = 0; i < request->item_count; ++i) {
    const agentic_ai_lab_runtime_v0_event_header *header =
        (const agentic_ai_lab_runtime_v0_event_header *)
            ((const uint8_t *)request->headers + i * request->header_stride);
    if (header->layout_version != AGENTIC_AI_LAB_RUNTIME_V0_LAYOUT_VERSION ||
        header->reserved0 != 0)
      return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
    if (!slice_in_bounds(header->payload_offset, header->payload_length,
                         arena_entry->arena_capacity))
      return AGENTIC_AI_LAB_RUNTIME_V0_PAYLOAD_BOUNDS;
    if ((session_entry->pending_count != 0 || i != 0) &&
        header->sequence <= previous_sequence)
      return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE;
    previous_sequence = header->sequence;
  }
  for (uint64_t i = 0; i < request->item_count; ++i) {
    const agentic_ai_lab_runtime_v0_event_header *header =
        (const agentic_ai_lab_runtime_v0_event_header *)
            ((const uint8_t *)request->headers + i * request->header_stride);
    pending_event *pending =
        &session_entry->pending[session_entry->pending_count++];
    memset(pending, 0, sizeof(*pending));
    pending->header = *header;
    pending->arena_id = request->arena.resource_id;
    pending->arena_generation = request->arena_generation;
  }
  result->published_count = request->item_count;
  result->last_sequence = request->item_count == 0 ? previous_sequence :
      ((const agentic_ai_lab_runtime_v0_event_header *)
           ((const uint8_t *)request->headers +
            (request->item_count - 1u) * request->header_stride))->sequence;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_poll_batch(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_poll_request *request,
    agentic_ai_lab_runtime_v0_poll_result *result) {
  resource *session_entry = NULL;
  resource *arena_entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION,
                                               &session_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (request == NULL || result == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  if (request->struct_size != sizeof(*request) || result->struct_size != sizeof(*result) ||
      request->reserved0 != 0 || result->reserved0 != 0 ||
      request->header_stride != sizeof(agentic_ai_lab_runtime_v0_event_header) ||
      (request->header_capacity != 0 && request->headers == NULL))
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  status = resolve(instance, request->arena, KIND_ARENA, &arena_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (arena_entry->arena_generation != request->arena_generation)
    return AGENTIC_AI_LAB_RUNTIME_V0_STALE_GENERATION;
  uint64_t ready = 0, required_payload = 0;
  for (uint64_t i = session_entry->poll_cursor;
       i < session_entry->pending_count; ++i) {
    pending_event *pending = &session_entry->pending[i];
    if (pending->polled || pending->arena_id != request->arena.resource_id ||
        pending->arena_generation != request->arena_generation)
      break;
    ++ready;
    uint64_t end = pending->header.payload_offset + pending->header.payload_length;
    if (end > required_payload) required_payload = end;
  }
  result->required_header_count = ready;
  result->required_payload_bytes = required_payload;
  result->produced_count = 0;
  result->first_sequence = 0;
  result->last_sequence = 0;
  result->arena_generation = request->arena_generation;
  result->lease = null_handle();
  if (ready == 0) return AGENTIC_AI_LAB_RUNTIME_V0_OK;
  if (request->header_capacity < ready || request->payload_capacity < required_payload)
    return AGENTIC_AI_LAB_RUNTIME_V0_OK;
  agentic_ai_lab_runtime_v0_handle lease = null_handle();
  status = allocate_resource(instance.instance_id, KIND_LEASE, &lease);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  resource *lease_entry = slot(lease.resource_id);
  lease_entry->parent_id = request->arena.resource_id;
  lease_entry->epoch = request->arena_generation;
  lease_entry->outstanding = session.resource_id;
  uint64_t produced = 0;
  for (uint64_t i = session_entry->poll_cursor;
       i < session_entry->pending_count; ++i) {
    pending_event *pending = &session_entry->pending[i];
    if (pending->polled || pending->arena_id != request->arena.resource_id ||
        pending->arena_generation != request->arena_generation)
      break;
    agentic_ai_lab_runtime_v0_event_header *header_out =
        (agentic_ai_lab_runtime_v0_event_header *)
            ((uint8_t *)request->headers + produced * request->header_stride);
    *header_out = pending->header;
    pending->polled = 1;
    if (produced == 0) result->first_sequence = pending->header.sequence;
    result->last_sequence = pending->header.sequence;
    ++produced;
  }
  session_entry->poll_cursor += produced;
  lease_entry->sequence = produced;
  lease_entry->lease_first_sequence = result->first_sequence;
  lease_entry->lease_last_sequence = result->last_sequence;
  arena_entry->inflight_count += produced;
  result->produced_count = produced;
  result->lease = lease;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_submit_batch(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_submit_request *request,
    agentic_ai_lab_runtime_v0_submit_result *result) {
  resource *session_entry = NULL;
  resource *arena_entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION,
                                               &session_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (request == NULL || result == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  uint64_t bitmap_required = request->item_count / 8u +
      (request->item_count % 8u != 0 ? 1u : 0u);
  if (request->struct_size != sizeof(*request) || result->struct_size != sizeof(*result) ||
      request->reserved0 != 0 || result->reserved0 != 0 ||
      request->header_stride != sizeof(agentic_ai_lab_runtime_v0_event_header) ||
      request->item_count > SIZE_MAX / request->header_stride ||
      (request->item_count != 0 && request->headers == NULL) ||
      request->item_status_capacity < request->item_count ||
      (request->item_count != 0 && request->item_statuses == NULL) ||
      request->accepted_bitmap_bytes < bitmap_required ||
      (bitmap_required != 0 && request->accepted_bitmap == NULL))
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  status = resolve(instance, request->arena, KIND_ARENA, &arena_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (arena_entry->arena_generation != request->arena_generation)
    return AGENTIC_AI_LAB_RUNTIME_V0_STALE_GENERATION;
  for (uint64_t i = 0; i < request->item_count; ++i) {
    const agentic_ai_lab_runtime_v0_event_header *header =
        (const agentic_ai_lab_runtime_v0_event_header *)
            ((const uint8_t *)request->headers + i * request->header_stride);
    const agentic_ai_lab_runtime_v0_event_header *previous = i == 0 ? NULL :
        (const agentic_ai_lab_runtime_v0_event_header *)
            ((const uint8_t *)request->headers +
             (i - 1u) * request->header_stride);
    if ((previous != NULL && previous->sequence >= header->sequence) ||
        header->layout_version != AGENTIC_AI_LAB_RUNTIME_V0_LAYOUT_VERSION ||
        header->reserved0 != 0 ||
        !slice_in_bounds(header->payload_offset, header->payload_length,
                         arena_entry->arena_capacity))
      return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  }
  memset(request->accepted_bitmap, 0, bitmap_required);
  result->accepted_count = 0;
  result->rejected_count = 0;
  result->accepted_watermark = session_entry->sequence;
  uint64_t pending_index = request->item_count == 0
      ? session_entry->pending_count
      : pending_lower_bound(session_entry, request->headers->sequence);
  for (uint64_t i = 0; i < request->item_count; ++i) {
    const agentic_ai_lab_runtime_v0_event_header *header =
        (const agentic_ai_lab_runtime_v0_event_header *)
            ((const uint8_t *)request->headers + i * request->header_stride);
    while (pending_index < session_entry->pending_count &&
           session_entry->pending[pending_index].header.sequence < header->sequence)
      ++pending_index;
    pending_event *pending =
        pending_index < session_entry->pending_count &&
        session_entry->pending[pending_index].header.sequence == header->sequence
            ? &session_entry->pending[pending_index]
            : NULL;
    uint32_t item_status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
    if (pending == NULL || !pending->polled ||
        pending->arena_id != request->arena.resource_id ||
        pending->arena_generation != request->arena_generation ||
        pending->header.correlation_identity.high !=
            header->correlation_identity.high ||
        pending->header.correlation_identity.low !=
            header->correlation_identity.low) {
      item_status = AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
    } else if (pending->accepted) {
      item_status = AGENTIC_AI_LAB_RUNTIME_V0_DUPLICATE_ACCEPTED;
    } else {
      pending->accepted = 1;
      request->accepted_bitmap[i / 8u] |= (uint8_t)(1u << (i % 8u));
      ++result->accepted_count;
    }
    request->item_statuses[i] = item_status;
    if (item_status != AGENTIC_AI_LAB_RUNTIME_V0_OK) ++result->rejected_count;
    if (pending != NULL) ++pending_index;
  }
  uint64_t watermark = session_entry->sequence;
  for (uint64_t i = 0; i < session_entry->pending_count; ++i) {
    pending_event *pending = &session_entry->pending[i];
    if (!pending->accepted) break;
    if (pending->header.sequence > watermark) watermark = pending->header.sequence;
  }
  session_entry->sequence = watermark;
  result->accepted_watermark = watermark;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_batch_ack(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    agentic_ai_lab_runtime_v0_handle lease) {
  resource *session_entry = NULL;
  resource *lease_entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION,
                                               &session_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  status = resolve(instance, lease, KIND_LEASE, &lease_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (lease_entry->outstanding != session.resource_id)
    return AGENTIC_AI_LAB_RUNTIME_V0_WRONG_HANDLE_KIND;
  resource *arena_entry = slot(lease_entry->parent_id);
  if (arena_entry == NULL || !arena_entry->alive || arena_entry->kind != KIND_ARENA)
    return AGENTIC_AI_LAB_RUNTIME_V0_STALE_HANDLE;
  if (arena_entry->inflight_count < lease_entry->sequence)
    return AGENTIC_AI_LAB_RUNTIME_V0_INTERNAL_INVARIANT;
  arena_entry->inflight_count -= lease_entry->sequence;
  for (uint64_t i = 0; i < session_entry->pending_count; ++i)
    if (session_entry->pending[i].accepted && !session_entry->pending[i].acknowledged &&
        session_entry->pending[i].arena_id == lease_entry->parent_id &&
        session_entry->pending[i].header.sequence >=
            lease_entry->lease_first_sequence &&
        session_entry->pending[i].header.sequence <=
            lease_entry->lease_last_sequence)
      session_entry->pending[i].acknowledged = 1;
  uint64_t consumed = 0;
  while (consumed < session_entry->pending_count &&
         session_entry->pending[consumed].acknowledged)
    ++consumed;
  if (consumed != 0) {
    memmove(session_entry->pending, session_entry->pending + consumed,
            (session_entry->pending_count - consumed) *
                sizeof(*session_entry->pending));
    session_entry->pending_count -= consumed;
    session_entry->poll_cursor = session_entry->poll_cursor >= consumed
        ? session_entry->poll_cursor - consumed
        : 0;
  }
  return release_resource(lease_entry);
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_strict_mediate(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_strict_mediation_request *request,
    agentic_ai_lab_runtime_v0_strict_mediation_result *result) {
  resource *session_entry = NULL;
  resource *arena_entry = NULL;
  resource *lease_entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION,
                                               &session_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (request == NULL || result == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  if (request->struct_size != sizeof(*request) ||
      result->struct_size != sizeof(*result) || request->reserved0 != 0 ||
      request->reserved1 != 0 || result->reserved0 != 0 ||
      request->adapter == NULL ||
      request->adapter->struct_size != sizeof(*request->adapter) ||
      request->adapter->reserved0 != 0 || request->adapter->execute == NULL ||
      request->evidence == NULL ||
      request->evidence->struct_size != sizeof(*request->evidence) ||
      request->evidence->reserved0 != 0 ||
      request->evidence->reserve == NULL ||
      request->evidence->finalize == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  if (request->durability == AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_DIAGNOSTIC)
    return AGENTIC_AI_LAB_RUNTIME_V0_DIAGNOSTIC_CANNOT_EXECUTE;
  if (request->durability != AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_STRICT &&
      request->durability != AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_BATCHED)
    return AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_BINDING_MISMATCH;
  if (request->durability == AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_BATCHED &&
      (session_entry->capabilities &
       AGENTIC_AI_LAB_RUNTIME_V0_CAP_BATCHED_EVIDENCE) == 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_UNSUPPORTED_CAPABILITY;
  if (request->durability == AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_BATCHED &&
      request->evidence->flush == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  if (request->durability == AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_BATCHED &&
      session_entry->staged_leaf_count >= MAX_STAGED_LEAVES)
    return AGENTIC_AI_LAB_RUNTIME_V0_OUTSTANDING_WORK;
  status = resolve(instance, request->arena, KIND_ARENA, &arena_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  status = resolve(instance, request->lease, KIND_LEASE, &lease_entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (arena_entry->arena_generation != request->arena_generation ||
      lease_entry->parent_id != request->arena.resource_id ||
      lease_entry->outstanding != session.resource_id ||
      lease_entry->epoch != request->arena_generation ||
      session_entry->epoch != request->bundle_epoch ||
      request->first_sequence > request->last_sequence ||
      lease_entry->lease_first_sequence != request->first_sequence ||
      lease_entry->lease_last_sequence != request->last_sequence)
    return AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_BINDING_MISMATCH;
  uint64_t first_event = pending_lower_bound(session_entry,
                                              request->first_sequence);
  uint64_t last_event = pending_lower_bound(session_entry,
                                             request->last_sequence);
  if (first_event >= session_entry->pending_count ||
      last_event >= session_entry->pending_count ||
      session_entry->pending[first_event].header.sequence !=
          request->first_sequence ||
      session_entry->pending[last_event].header.sequence !=
          request->last_sequence ||
      last_event - first_event != request->last_sequence -
                                    request->first_sequence)
    return AGENTIC_AI_LAB_RUNTIME_V0_INTERNAL_INVARIANT;
  if (memcmp(session_entry->execution_root, request->before_execution_root,
             AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES) != 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_EXECUTION_ROOT_FORK;
  if (session_entry->semantic_root_bound &&
      memcmp(session_entry->semantic_root, request->semantic_root,
             AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES) != 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_BINDING_MISMATCH;
  int nonce_found = 0;
  uint64_t nonce_index = nonce_slot(session_entry, request->nonce, &nonce_found);
  if (nonce_found)
    return AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_REPLAY;
  if (session_entry->consumed_nonce_count >= MAX_CONSUMED_NONCES ||
      nonce_index == NONCE_TABLE_CAPACITY)
    return AGENTIC_AI_LAB_RUNTIME_V0_OUTSTANDING_WORK;
  agentic_ai_lab_runtime_v0_evidence_reservation reservation = {0};
  reservation.struct_size = sizeof(reservation);
  reservation.session = session;
  reservation.mediation_sequence = session_entry->mediation_sequence + 1u;
  reservation.first_sequence = request->first_sequence;
  reservation.last_sequence = request->last_sequence;
  reservation.nonce = request->nonce;
  memcpy(reservation.semantic_root, request->semantic_root,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  memcpy(reservation.before_execution_root, request->before_execution_root,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  status = request->evidence->reserve(request->evidence->context, &reservation);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (!session_entry->semantic_root_bound) {
    memcpy(session_entry->semantic_root, request->semantic_root,
           AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
    session_entry->semantic_root_bound = 1;
  }
  session_entry->consumed_nonces[nonce_index] = request->nonce;
  session_entry->consumed_nonce_used[nonce_index] = 1;
  ++session_entry->consumed_nonce_count;
  agentic_ai_lab_runtime_v0_adapter_invocation invocation = {0};
  invocation.struct_size = sizeof(invocation);
  invocation.arena = request->arena;
  invocation.lease = request->lease;
  invocation.arena_generation = request->arena_generation;
  invocation.first_sequence = request->first_sequence;
  invocation.last_sequence = request->last_sequence;
  invocation.headers = &session_entry->pending[first_event].header;
  invocation.header_stride = sizeof(*session_entry->pending);
  invocation.item_count = request->last_sequence - request->first_sequence + 1u;
  invocation.payload = arena_entry->arena_ptr;
  invocation.payload_capacity = arena_entry->arena_capacity;
  agentic_ai_lab_runtime_v0_adapter_result adapter_result = {0};
  adapter_result.struct_size = sizeof(adapter_result);
  agentic_ai_lab_runtime_v0_status adapter_status = request->adapter->execute(
      request->adapter->context, &invocation, &adapter_result);
  uint32_t outcome = AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_INDETERMINATE;
  if (adapter_status == AGENTIC_AI_LAB_RUNTIME_V0_OK &&
      adapter_result.struct_size == sizeof(adapter_result) &&
      adapter_result.reserved0 == 0 &&
      adapter_result.adapter_status == AGENTIC_AI_LAB_RUNTIME_V0_OK &&
      adapter_result.outcome == AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_COMMITTED) {
    outcome = AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_COMMITTED;
    adapter_status = adapter_result.adapter_status;
  } else if (adapter_status == AGENTIC_AI_LAB_RUNTIME_V0_OK &&
             (adapter_result.struct_size != sizeof(adapter_result) ||
              adapter_result.reserved0 != 0 ||
              adapter_result.adapter_status != AGENTIC_AI_LAB_RUNTIME_V0_OK ||
              adapter_result.outcome !=
                  AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_INDETERMINATE)) {
    adapter_status = AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  } else if (adapter_status == AGENTIC_AI_LAB_RUNTIME_V0_OK) {
    adapter_status = adapter_result.adapter_status;
  }
  if (outcome == AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_COMMITTED &&
      request->durability == AGENTIC_AI_LAB_RUNTIME_V0_DURABILITY_BATCHED)
    outcome = AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_BUFFERED;
  agentic_ai_lab_runtime_v0_evidence_invocation evidence_invocation = {0};
  evidence_invocation.struct_size = sizeof(evidence_invocation);
  evidence_invocation.outcome = outcome;
  evidence_invocation.adapter_status = adapter_status;
  evidence_invocation.session = session;
  evidence_invocation.mediation_sequence = session_entry->mediation_sequence + 1u;
  evidence_invocation.first_sequence = request->first_sequence;
  evidence_invocation.last_sequence = request->last_sequence;
  evidence_invocation.nonce = request->nonce;
  memcpy(evidence_invocation.semantic_root, request->semantic_root,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  memcpy(evidence_invocation.before_execution_root,
         request->before_execution_root, AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  memcpy(evidence_invocation.input_digest, adapter_result.input_digest,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  memcpy(evidence_invocation.observation_digest,
         adapter_result.observation_digest, AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  agentic_ai_lab_runtime_v0_evidence_result evidence_result = {0};
  evidence_result.struct_size = sizeof(evidence_result);
  agentic_ai_lab_runtime_v0_status evidence_status = request->evidence->finalize(
      request->evidence->context, &evidence_invocation, &evidence_result);
  int evidence_valid = evidence_status == AGENTIC_AI_LAB_RUNTIME_V0_OK &&
      evidence_result.struct_size == sizeof(evidence_result) &&
      evidence_result.reserved0 == 0 && evidence_result.reserved1 == 0 &&
      (evidence_result.verification_flags &
       ~(AGENTIC_AI_LAB_RUNTIME_V0_EVIDENCE_SIGNATURE_VERIFIED |
         AGENTIC_AI_LAB_RUNTIME_V0_EVIDENCE_INCLUSION_VERIFIED)) == 0;
  if (evidence_valid &&
      (outcome == AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_INDETERMINATE ||
       outcome == AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_BUFFERED) &&
      memcmp(evidence_result.after_execution_root,
             request->before_execution_root,
             AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES) != 0) {
    evidence_valid = 0;
    evidence_status = AGENTIC_AI_LAB_RUNTIME_V0_TOKEN_BINDING_MISMATCH;
  }
  if (!evidence_valid) {
    outcome = AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_INDETERMINATE;
    if (evidence_status == AGENTIC_AI_LAB_RUNTIME_V0_OK)
      evidence_status = AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  } else if (outcome == AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_COMMITTED) {
    memcpy(session_entry->execution_root,
           evidence_result.after_execution_root,
           AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  } else if (outcome == AGENTIC_AI_LAB_RUNTIME_V0_MEDIATION_BUFFERED) {
    staged_leaf *leaf =
        &session_entry->staged_leaves[session_entry->staged_leaf_count++];
    leaf->mediation_sequence = evidence_invocation.mediation_sequence;
    memcpy(leaf->digest, evidence_result.evidence_digest,
           AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  }
  ++session_entry->mediation_sequence;
  result->outcome = outcome;
  result->adapter_status = adapter_status;
  result->evidence_status = evidence_status;
  result->verification_flags = evidence_valid
      ? evidence_result.verification_flags : 0;
  result->mediation_sequence = session_entry->mediation_sequence;
  memcpy(result->execution_root, session_entry->execution_root,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  memcpy(result->observation_digest, adapter_result.observation_digest,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  if (evidence_valid) {
    memcpy(result->evidence_digest, evidence_result.evidence_digest,
           AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
    memcpy(result->attestation_digest, evidence_result.attestation_digest,
           AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  }
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_batched_flush(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle session,
    const agentic_ai_lab_runtime_v0_batched_flush_request *request,
    agentic_ai_lab_runtime_v0_batched_flush_result *result) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, session, KIND_SESSION,
                                               &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (request == NULL || result == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  if (request->struct_size != sizeof(*request) || request->reserved0 != 0 ||
      result->struct_size != sizeof(*result) || result->reserved0 != 0 ||
      request->evidence == NULL ||
      request->evidence->struct_size != sizeof(*request->evidence) ||
      request->evidence->reserved0 != 0 || request->evidence->flush == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  if ((entry->capabilities & AGENTIC_AI_LAB_RUNTIME_V0_CAP_BATCHED_EVIDENCE) == 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_UNSUPPORTED_CAPABILITY;
  if (entry->state != STATE_OPEN) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE;
  if (entry->staged_leaf_count == 0) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_STATE;
  if (memcmp(entry->execution_root, request->expected_execution_root,
             AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES) != 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_EXECUTION_ROOT_FORK;
  agentic_ai_lab_runtime_v0_evidence_flush_invocation invocation = {0};
  invocation.struct_size = sizeof(invocation);
  invocation.session = session;
  invocation.first_mediation_sequence =
      entry->staged_leaves[0].mediation_sequence;
  invocation.last_mediation_sequence =
      entry->staged_leaves[entry->staged_leaf_count - 1u].mediation_sequence;
  invocation.leaf_digests = entry->staged_leaves[0].digest;
  invocation.leaf_digest_stride = sizeof(staged_leaf);
  invocation.leaf_count = entry->staged_leaf_count;
  memcpy(invocation.before_execution_root, entry->execution_root,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  agentic_ai_lab_runtime_v0_evidence_flush_result flushed = {0};
  flushed.struct_size = sizeof(flushed);
  status = request->evidence->flush(request->evidence->context, &invocation,
                                    &flushed);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (flushed.struct_size != sizeof(flushed) || flushed.reserved0 != 0 ||
      flushed.reserved1 != 0 ||
      (flushed.verification_flags &
       ~(AGENTIC_AI_LAB_RUNTIME_V0_EVIDENCE_SIGNATURE_VERIFIED |
         AGENTIC_AI_LAB_RUNTIME_V0_EVIDENCE_INCLUSION_VERIFIED)) != 0)
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  result->leaf_count = entry->staged_leaf_count;
  result->first_mediation_sequence = invocation.first_mediation_sequence;
  result->last_mediation_sequence = invocation.last_mediation_sequence;
  result->evidence_status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  result->verification_flags = flushed.verification_flags;
  memcpy(entry->execution_root, flushed.after_execution_root,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  memcpy(result->execution_root, entry->execution_root,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  memcpy(result->batch_root, flushed.batch_root,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  memcpy(result->evidence_digest, flushed.evidence_digest,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  memcpy(result->attestation_digest, flushed.attestation_digest,
         AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  memset(entry->staged_leaves, 0, sizeof(entry->staged_leaves));
  entry->staged_leaf_count = 0;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_arena_recycle(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_handle arena,
    uint64_t expected_generation, uint64_t next_generation) {
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, arena, KIND_ARENA, &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  if (entry->arena_generation != expected_generation)
    return AGENTIC_AI_LAB_RUNTIME_V0_STALE_GENERATION;
  if (next_generation <= expected_generation)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  if (entry->inflight_count != 0) return AGENTIC_AI_LAB_RUNTIME_V0_ARENA_BUSY;
  entry->arena_generation = next_generation;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_owned_bytes_release(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_owned_bytes *value) {
  if (value == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  resource *entry = NULL;
  agentic_ai_lab_runtime_v0_status status = resolve(instance, value->owner, KIND_BYTES, &entry);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  release_resource(entry);
  value->ptr = NULL; value->len = 0; value->capacity = 0;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

agentic_ai_lab_runtime_v0_status agentic_ai_lab_runtime_v0_error_message(
    agentic_ai_lab_runtime_v0_handle instance, agentic_ai_lab_runtime_v0_status status,
    agentic_ai_lab_runtime_v0_owned_bytes *message_out) {
  resource *ignored = NULL;
  agentic_ai_lab_runtime_v0_status resolved = instance_entry(instance, &ignored);
  if (resolved != AGENTIC_AI_LAB_RUNTIME_V0_OK) return resolved;
  if (message_out == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  const char *name = agentic_ai_lab_runtime_v0_status_name(status);
  size_t len = strlen(name);
  uint8_t *bytes = (uint8_t *)malloc(len);
  if (bytes == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_ALLOCATION_FAILURE;
  memcpy(bytes, name, len);
  agentic_ai_lab_runtime_v0_handle owner = null_handle();
  resolved = allocate_resource(instance.instance_id, KIND_BYTES, &owner);
  if (resolved != AGENTIC_AI_LAB_RUNTIME_V0_OK) { free(bytes); return resolved; }
  resource *entry = slot(owner.resource_id);
  entry->bytes = bytes; entry->bytes_len = len;
  message_out->ptr = bytes; message_out->len = len; message_out->capacity = len;
  message_out->owner = owner;
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

const char *agentic_ai_lab_runtime_v0_status_name(agentic_ai_lab_runtime_v0_status status) {
  static const char *names[] = {
    "ok", "invalid-argument", "incompatible-abi", "incompatible-schema",
    "unsupported-capability", "malformed-descriptor", "wrong-handle-kind",
    "stale-handle", "cross-instance-handle", "already-released",
    "invalid-state", "bundle-identity-mismatch", "checkpoint-incompatible",
    "cancelled", "outstanding-work", "allocation-failure", "internal-invariant",
    "duplicate-accepted", "payload-bounds", "stale-generation", "arena-busy",
    "token-replay", "execution-root-fork", "token-binding-mismatch",
    "diagnostic-cannot-execute"
  };
  return status <= AGENTIC_AI_LAB_RUNTIME_V0_DIAGNOSTIC_CANNOT_EXECUTE
      ? names[status] : "unknown";
}
