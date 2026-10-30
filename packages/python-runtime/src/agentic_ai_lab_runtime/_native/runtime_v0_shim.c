// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include <agentic_ai_lab/runtime_v0.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
typedef HMODULE agentic_ai_lab_library_handle;
#define AGENTIC_AI_LAB_LIBRARY_OPEN(path) LoadLibraryA(path)
#define AGENTIC_AI_LAB_LIBRARY_SYMBOL(handle, name) GetProcAddress(handle, name)
#define AGENTIC_AI_LAB_LIBRARY_CLOSE(handle) FreeLibrary(handle)
#else
#include <dlfcn.h>
typedef void *agentic_ai_lab_library_handle;
#define AGENTIC_AI_LAB_LIBRARY_OPEN(path) dlopen(path, RTLD_NOW | RTLD_LOCAL)
#define AGENTIC_AI_LAB_LIBRARY_SYMBOL(handle, name) dlsym(handle, name)
#define AGENTIC_AI_LAB_LIBRARY_CLOSE(handle) dlclose(handle)
#endif

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

typedef agentic_ai_lab_runtime_v0_status (*instance_create_fn)(
    agentic_ai_lab_runtime_v0_handle *);
typedef agentic_ai_lab_runtime_v0_status (*instance_release_fn)(
    agentic_ai_lab_runtime_v0_handle);
typedef agentic_ai_lab_runtime_v0_status (*negotiate_fn)(
    agentic_ai_lab_runtime_v0_handle,
    const agentic_ai_lab_runtime_v0_negotiate_request *,
    agentic_ai_lab_runtime_v0_negotiate_result *);
typedef agentic_ai_lab_runtime_v0_status (*profile_release_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle);
typedef agentic_ai_lab_runtime_v0_status (*bundle_open_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle,
    const agentic_ai_lab_runtime_v0_bundle_descriptor *, agentic_ai_lab_runtime_v0_handle *);
typedef agentic_ai_lab_runtime_v0_status (*bundle_release_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle);
typedef agentic_ai_lab_runtime_v0_status (*session_open_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle,
    const agentic_ai_lab_runtime_v0_session_descriptor *, agentic_ai_lab_runtime_v0_handle *);
typedef agentic_ai_lab_runtime_v0_status (*session_close_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle, uint32_t);
typedef agentic_ai_lab_runtime_v0_status (*session_release_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle);
typedef agentic_ai_lab_runtime_v0_status (*session_reconcile_evidence_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle,
    const agentic_ai_lab_runtime_v0_evidence_reconciliation *);
typedef agentic_ai_lab_runtime_v0_status (*arena_register_fn)(
    agentic_ai_lab_runtime_v0_handle, const agentic_ai_lab_runtime_v0_arena_descriptor *,
    agentic_ai_lab_runtime_v0_handle *);
typedef agentic_ai_lab_runtime_v0_status (*arena_release_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle);
typedef agentic_ai_lab_runtime_v0_status (*arena_recycle_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle, uint64_t, uint64_t);
typedef agentic_ai_lab_runtime_v0_status (*publish_batch_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle,
    const agentic_ai_lab_runtime_v0_publish_request *, agentic_ai_lab_runtime_v0_publish_result *);
typedef agentic_ai_lab_runtime_v0_status (*poll_batch_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle,
    const agentic_ai_lab_runtime_v0_poll_request *, agentic_ai_lab_runtime_v0_poll_result *);
typedef agentic_ai_lab_runtime_v0_status (*submit_batch_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle,
    const agentic_ai_lab_runtime_v0_submit_request *, agentic_ai_lab_runtime_v0_submit_result *);
typedef agentic_ai_lab_runtime_v0_status (*batch_ack_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle,
    agentic_ai_lab_runtime_v0_handle);
typedef agentic_ai_lab_runtime_v0_status (*strict_mediate_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle,
    const agentic_ai_lab_runtime_v0_strict_mediation_request *,
    agentic_ai_lab_runtime_v0_strict_mediation_result *);
typedef agentic_ai_lab_runtime_v0_status (*batched_flush_fn)(
    agentic_ai_lab_runtime_v0_handle, agentic_ai_lab_runtime_v0_handle,
    const agentic_ai_lab_runtime_v0_batched_flush_request *,
    agentic_ai_lab_runtime_v0_batched_flush_result *);

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

_Static_assert(sizeof(agentic_ai_lab_python_runtime_v0_event) ==
                   sizeof(agentic_ai_lab_runtime_v0_event_header),
               "Python CFFI event projection must match runtime-v0 header");

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

typedef uint32_t (*agentic_ai_lab_python_runtime_v0_evidence_reserve_fn)(
    void *context,
    const agentic_ai_lab_python_runtime_v0_evidence_reservation *reservation);

typedef uint32_t (*agentic_ai_lab_python_runtime_v0_evidence_finalize_fn)(
    void *context,
    const agentic_ai_lab_python_runtime_v0_evidence_invocation *invocation,
    agentic_ai_lab_python_runtime_v0_evidence_result *result);

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

typedef uint32_t (*agentic_ai_lab_python_runtime_v0_evidence_flush_fn)(
    void *context,
    const agentic_ai_lab_python_runtime_v0_evidence_flush_invocation *invocation,
    agentic_ai_lab_python_runtime_v0_evidence_flush_result *result);

typedef struct agentic_ai_lab_python_runtime_v0_context {
  agentic_ai_lab_library_handle library;
  instance_release_fn instance_release;
  profile_release_fn profile_release;
  bundle_release_fn bundle_release;
  session_close_fn session_close;
  session_release_fn session_release;
  session_reconcile_evidence_fn session_reconcile_evidence;
  arena_register_fn arena_register;
  arena_release_fn arena_release;
  arena_recycle_fn arena_recycle;
  publish_batch_fn publish_batch;
  poll_batch_fn poll_batch;
  submit_batch_fn submit_batch;
  batch_ack_fn batch_ack;
  strict_mediate_fn strict_mediate;
  batched_flush_fn batched_flush;
  agentic_ai_lab_runtime_v0_handle instance;
  agentic_ai_lab_runtime_v0_handle profile;
  agentic_ai_lab_runtime_v0_handle bundle;
  agentic_ai_lab_runtime_v0_handle session;
  agentic_ai_lab_runtime_v0_handle arena;
  uint64_t arena_capacity;
  uint64_t arena_generation;
  int arena_alive;
} agentic_ai_lab_python_runtime_v0_context;

typedef struct {
  agentic_ai_lab_python_runtime_v0_context *runtime;
  const agentic_ai_lab_runtime_v0_submit_request *request;
  agentic_ai_lab_runtime_v0_submit_result *submitted;
  const agentic_ai_lab_python_runtime_v0_mediation *mediation;
  agentic_ai_lab_python_runtime_v0_batch_result *batch;
} agentic_ai_lab_python_runtime_v0_adapter_context;

typedef struct {
  agentic_ai_lab_python_runtime_v0_evidence_reserve_fn reserve;
  agentic_ai_lab_python_runtime_v0_evidence_finalize_fn finalize;
  agentic_ai_lab_python_runtime_v0_evidence_flush_fn flush;
  void *context;
} agentic_ai_lab_python_runtime_v0_evidence_context;

static agentic_ai_lab_runtime_v0_status python_runtime_adapter_execute(
    void *opaque, const agentic_ai_lab_runtime_v0_adapter_invocation *invocation,
    agentic_ai_lab_runtime_v0_adapter_result *result) {
  agentic_ai_lab_python_runtime_v0_adapter_context *context = opaque;
  if (invocation == NULL || result == NULL ||
      invocation->struct_size != sizeof(*invocation))
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  agentic_ai_lab_runtime_v0_status status = context->runtime->submit_batch(
      context->runtime->instance, context->runtime->session, context->request,
      context->submitted);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  context->batch->accepted_count = context->submitted->accepted_count;
  context->batch->rejected_count = context->submitted->rejected_count;
  context->batch->accepted_watermark = context->submitted->accepted_watermark;
  result->outcome = context->mediation->outcome;
  result->adapter_status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  memcpy(result->input_digest, context->mediation->input_digest, 32);
  memcpy(result->observation_digest, context->mediation->observation_digest, 32);
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

static agentic_ai_lab_runtime_v0_status python_runtime_evidence_reserve(
    void *opaque, const agentic_ai_lab_runtime_v0_evidence_reservation *reservation) {
  agentic_ai_lab_python_runtime_v0_evidence_context *context = opaque;
  agentic_ai_lab_python_runtime_v0_evidence_reservation projected = {0};
  projected.mediation_sequence = reservation->mediation_sequence;
  projected.first_sequence = reservation->first_sequence;
  projected.last_sequence = reservation->last_sequence;
  projected.nonce_high = reservation->nonce.high;
  projected.nonce_low = reservation->nonce.low;
  memcpy(projected.semantic_root, reservation->semantic_root, 32);
  memcpy(projected.before_execution_root,
         reservation->before_execution_root, 32);
  return context->reserve(context->context, &projected);
}

static agentic_ai_lab_runtime_v0_status python_runtime_evidence_finalize(
    void *opaque, const agentic_ai_lab_runtime_v0_evidence_invocation *invocation,
    agentic_ai_lab_runtime_v0_evidence_result *result) {
  agentic_ai_lab_python_runtime_v0_evidence_context *context = opaque;
  agentic_ai_lab_python_runtime_v0_evidence_invocation projected = {0};
  agentic_ai_lab_python_runtime_v0_evidence_result committed = {0};
  projected.outcome = invocation->outcome;
  projected.adapter_status = invocation->adapter_status;
  projected.mediation_sequence = invocation->mediation_sequence;
  projected.first_sequence = invocation->first_sequence;
  projected.last_sequence = invocation->last_sequence;
  projected.nonce_high = invocation->nonce.high;
  projected.nonce_low = invocation->nonce.low;
  memcpy(projected.semantic_root, invocation->semantic_root, 32);
  memcpy(projected.before_execution_root,
         invocation->before_execution_root, 32);
  memcpy(projected.input_digest, invocation->input_digest, 32);
  memcpy(projected.observation_digest, invocation->observation_digest, 32);
  agentic_ai_lab_runtime_v0_status status = context->finalize(
      context->context, &projected, &committed);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  result->verification_flags = committed.verification_flags;
  memcpy(result->after_execution_root, committed.after_execution_root, 32);
  memcpy(result->evidence_digest, committed.evidence_digest, 32);
  memcpy(result->attestation_digest, committed.attestation_digest, 32);
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

static agentic_ai_lab_runtime_v0_status python_runtime_evidence_flush(
    void *opaque, const agentic_ai_lab_runtime_v0_evidence_flush_invocation *invocation,
    agentic_ai_lab_runtime_v0_evidence_flush_result *result) {
  agentic_ai_lab_python_runtime_v0_evidence_context *context = opaque;
  if (context->flush == NULL || invocation->leaf_count > SIZE_MAX / 32u)
    return AGENTIC_AI_LAB_RUNTIME_V0_MALFORMED_DESCRIPTOR;
  size_t bytes = (size_t)invocation->leaf_count * 32u;
  uint8_t *digests = malloc(bytes);
  if (digests == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_ALLOCATION_FAILURE;
  for (uint64_t i = 0; i < invocation->leaf_count; ++i)
    memcpy(digests + i * 32u,
           invocation->leaf_digests + i * invocation->leaf_digest_stride, 32);
  agentic_ai_lab_python_runtime_v0_evidence_flush_invocation projected = {0};
  projected.first_mediation_sequence = invocation->first_mediation_sequence;
  projected.last_mediation_sequence = invocation->last_mediation_sequence;
  projected.leaf_digests = digests;
  projected.leaf_count = invocation->leaf_count;
  memcpy(projected.before_execution_root, invocation->before_execution_root, 32);
  agentic_ai_lab_python_runtime_v0_evidence_flush_result committed = {0};
  agentic_ai_lab_runtime_v0_status status = context->flush(
      context->context, &projected, &committed);
  free(digests);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  result->verification_flags = committed.verification_flags;
  memcpy(result->after_execution_root, committed.after_execution_root, 32);
  memcpy(result->batch_root, committed.batch_root, 32);
  memcpy(result->evidence_digest, committed.evidence_digest, 32);
  memcpy(result->attestation_digest, committed.attestation_digest, 32);
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

static void health_error(agentic_ai_lab_python_runtime_v0_health *health,
                         const char *message) {
  snprintf(health->error, sizeof(health->error), "%s", message);
}

static int load_symbol(agentic_ai_lab_library_handle library, const char *name,
                       void *target, size_t target_size,
                       agentic_ai_lab_python_runtime_v0_health *health) {
  void *symbol = (void *)AGENTIC_AI_LAB_LIBRARY_SYMBOL(library, name);
  if (symbol == NULL || target_size != sizeof(symbol)) {
    health_error(health, name);
    return 0;
  }
  memcpy(target, &symbol, target_size);
  return 1;
}

int agentic_ai_lab_python_runtime_v0_probe(
    const char *library_path, const uint8_t *bundle_schema,
    size_t bundle_schema_length, const uint8_t *runtime_identity,
    size_t runtime_identity_length, agentic_ai_lab_python_runtime_v0_health *health) {
  if (library_path == NULL || bundle_schema == NULL || runtime_identity == NULL ||
      health == NULL) return 0;
  memset(health, 0, sizeof(*health));
  agentic_ai_lab_library_handle library = AGENTIC_AI_LAB_LIBRARY_OPEN(library_path);
  if (library == NULL) {
    health_error(health, "native-library-load-failed");
    return 0;
  }
  instance_create_fn instance_create = NULL;
  instance_release_fn instance_release = NULL;
  negotiate_fn negotiate = NULL;
  profile_release_fn profile_release = NULL;
  if (!load_symbol(library, "agentic_ai_lab_runtime_v0_instance_create",
                   &instance_create, sizeof(instance_create), health) ||
      !load_symbol(library, "agentic_ai_lab_runtime_v0_instance_release",
                   &instance_release, sizeof(instance_release), health) ||
      !load_symbol(library, "agentic_ai_lab_runtime_v0_negotiate", &negotiate,
                   sizeof(negotiate), health) ||
      !load_symbol(library, "agentic_ai_lab_runtime_v0_profile_release",
                   &profile_release, sizeof(profile_release), health)) {
    AGENTIC_AI_LAB_LIBRARY_CLOSE(library);
    return 0;
  }
  agentic_ai_lab_runtime_v0_handle instance = {0};
  agentic_ai_lab_runtime_v0_status status = instance_create(&instance);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) {
    health->status = status;
    health_error(health, "instance-create-failed");
    AGENTIC_AI_LAB_LIBRARY_CLOSE(library);
    return 0;
  }
  agentic_ai_lab_runtime_v0_negotiate_request request = {0};
  request.struct_size = sizeof(request);
  request.abi_major = AGENTIC_AI_LAB_RUNTIME_V0_ABI_MAJOR;
  request.abi_minor = AGENTIC_AI_LAB_RUNTIME_V0_ABI_MINOR;
  request.required_capabilities = AGENTIC_AI_LAB_RUNTIME_V0_CAP_CONTROL;
  request.bundle_schema.ptr = bundle_schema;
  request.bundle_schema.len = bundle_schema_length;
  request.runtime_identity.ptr = runtime_identity;
  request.runtime_identity.len = runtime_identity_length;
  agentic_ai_lab_runtime_v0_negotiate_result result = {0};
  result.struct_size = sizeof(result);
  status = negotiate(instance, &request, &result);
  health->status = status;
  health->abi_major = result.abi_major;
  health->abi_minor = result.abi_minor;
  health->capabilities = result.capabilities;
  health->max_payload_bytes = result.max_payload_bytes;
  if (status == AGENTIC_AI_LAB_RUNTIME_V0_OK)
    profile_release(instance, result.profile);
  instance_release(instance);
  AGENTIC_AI_LAB_LIBRARY_CLOSE(library);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) {
    health_error(health, "native-negotiation-failed");
    return 0;
  }
  return 1;
}

uint32_t agentic_ai_lab_python_runtime_v0_close(
    agentic_ai_lab_python_runtime_v0_context *context) {
  if (context == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_OK;
  agentic_ai_lab_runtime_v0_status first = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  agentic_ai_lab_runtime_v0_status status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  if (context->arena_alive) {
    status = context->arena_release(context->instance, context->arena);
    if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) first = status;
  }
  status = context->session_close(
      context->instance, context->session, 1);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) first = status;
  status = context->session_release(context->instance, context->session);
  if (first == AGENTIC_AI_LAB_RUNTIME_V0_OK && status != AGENTIC_AI_LAB_RUNTIME_V0_OK)
    first = status;
  status = context->bundle_release(context->instance, context->bundle);
  if (first == AGENTIC_AI_LAB_RUNTIME_V0_OK && status != AGENTIC_AI_LAB_RUNTIME_V0_OK)
    first = status;
  status = context->profile_release(context->instance, context->profile);
  if (first == AGENTIC_AI_LAB_RUNTIME_V0_OK && status != AGENTIC_AI_LAB_RUNTIME_V0_OK)
    first = status;
  status = context->instance_release(context->instance);
  if (first == AGENTIC_AI_LAB_RUNTIME_V0_OK && status != AGENTIC_AI_LAB_RUNTIME_V0_OK)
    first = status;
  AGENTIC_AI_LAB_LIBRARY_CLOSE(context->library);
  free(context);
  return first;
}

agentic_ai_lab_python_runtime_v0_context *agentic_ai_lab_python_runtime_v0_open(
    const char *library_path, const uint8_t *bundle_schema,
    size_t bundle_schema_length, const uint8_t *runtime_identity,
    size_t runtime_identity_length, uint32_t digest_algorithm,
    const uint8_t *bundle_digest, size_t bundle_digest_length,
    uint64_t bundle_epoch, const uint8_t *canonical_packet,
    size_t canonical_packet_length, uint32_t enable_batched,
    agentic_ai_lab_python_runtime_v0_health *health) {
  if (library_path == NULL || bundle_schema == NULL || runtime_identity == NULL ||
      bundle_digest == NULL || bundle_digest_length != AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES ||
      canonical_packet == NULL || health == NULL) return NULL;
  memset(health, 0, sizeof(*health));
  agentic_ai_lab_python_runtime_v0_context *context =
      (agentic_ai_lab_python_runtime_v0_context *)calloc(1, sizeof(*context));
  if (context == NULL) {
    health->status = AGENTIC_AI_LAB_RUNTIME_V0_ALLOCATION_FAILURE;
    health_error(health, "context-allocation-failed");
    return NULL;
  }
  context->library = AGENTIC_AI_LAB_LIBRARY_OPEN(library_path);
  if (context->library == NULL) {
    health_error(health, "native-library-load-failed");
    free(context);
    return NULL;
  }
  instance_create_fn instance_create = NULL;
  negotiate_fn negotiate = NULL;
  bundle_open_fn bundle_open = NULL;
  session_open_fn session_open = NULL;
#define LOAD_CONTEXT_SYMBOL(name)                                             \
  load_symbol(context->library, "agentic_ai_lab_runtime_v0_" #name, &name,          \
              sizeof(name), health)
#define LOAD_CONTEXT_FIELD(name)                                              \
  load_symbol(context->library, "agentic_ai_lab_runtime_v0_" #name,                 \
              &context->name, sizeof(context->name), health)
  if (!LOAD_CONTEXT_SYMBOL(instance_create) || !LOAD_CONTEXT_SYMBOL(negotiate) ||
      !LOAD_CONTEXT_SYMBOL(bundle_open) || !LOAD_CONTEXT_SYMBOL(session_open) ||
      !LOAD_CONTEXT_FIELD(instance_release) ||
      !LOAD_CONTEXT_FIELD(profile_release) ||
      !LOAD_CONTEXT_FIELD(bundle_release) ||
      !LOAD_CONTEXT_FIELD(session_close) ||
      !LOAD_CONTEXT_FIELD(session_release) ||
      !LOAD_CONTEXT_FIELD(session_reconcile_evidence) ||
      !LOAD_CONTEXT_FIELD(arena_register) ||
      !LOAD_CONTEXT_FIELD(arena_release) ||
      !LOAD_CONTEXT_FIELD(arena_recycle) ||
      !LOAD_CONTEXT_FIELD(publish_batch) ||
      !LOAD_CONTEXT_FIELD(poll_batch) ||
      !LOAD_CONTEXT_FIELD(submit_batch) ||
      !LOAD_CONTEXT_FIELD(batch_ack) ||
      !LOAD_CONTEXT_FIELD(strict_mediate) ||
      !LOAD_CONTEXT_FIELD(batched_flush)) {
    AGENTIC_AI_LAB_LIBRARY_CLOSE(context->library);
    free(context);
    return NULL;
  }
#undef LOAD_CONTEXT_SYMBOL
#undef LOAD_CONTEXT_FIELD
  agentic_ai_lab_runtime_v0_status status = instance_create(&context->instance);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) goto fail_instance;
  agentic_ai_lab_runtime_v0_negotiate_request request = {0};
  request.struct_size = sizeof(request);
  request.abi_major = AGENTIC_AI_LAB_RUNTIME_V0_ABI_MAJOR;
  request.abi_minor = AGENTIC_AI_LAB_RUNTIME_V0_ABI_MINOR;
  request.required_capabilities = AGENTIC_AI_LAB_RUNTIME_V0_CAP_CONTROL |
      AGENTIC_AI_LAB_RUNTIME_V0_CAP_HOT_BATCH | AGENTIC_AI_LAB_RUNTIME_V0_CAP_CALLER_ARENA;
  if (enable_batched)
    request.required_capabilities |= AGENTIC_AI_LAB_RUNTIME_V0_CAP_BATCHED_EVIDENCE;
  request.bundle_schema.ptr = bundle_schema;
  request.bundle_schema.len = bundle_schema_length;
  request.runtime_identity.ptr = runtime_identity;
  request.runtime_identity.len = runtime_identity_length;
  agentic_ai_lab_runtime_v0_negotiate_result negotiated = {0};
  negotiated.struct_size = sizeof(negotiated);
  status = negotiate(context->instance, &request, &negotiated);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) goto fail_instance;
  context->profile = negotiated.profile;
  health->abi_major = negotiated.abi_major;
  health->abi_minor = negotiated.abi_minor;
  health->capabilities = negotiated.capabilities;
  health->max_payload_bytes = negotiated.max_payload_bytes;
  agentic_ai_lab_runtime_v0_bundle_descriptor bundle_descriptor = {0};
  bundle_descriptor.struct_size = sizeof(bundle_descriptor);
  bundle_descriptor.digest_algorithm = digest_algorithm;
  memcpy(bundle_descriptor.digest, bundle_digest, AGENTIC_AI_LAB_RUNTIME_V0_DIGEST_BYTES);
  bundle_descriptor.bundle_epoch = bundle_epoch;
  bundle_descriptor.schema.ptr = bundle_schema;
  bundle_descriptor.schema.len = bundle_schema_length;
  bundle_descriptor.canonical_packet.ptr = canonical_packet;
  bundle_descriptor.canonical_packet.len = canonical_packet_length;
  status = bundle_open(context->instance, context->profile, &bundle_descriptor,
                       &context->bundle);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) goto fail_profile;
  agentic_ai_lab_runtime_v0_session_descriptor session_descriptor = {0};
  session_descriptor.struct_size = sizeof(session_descriptor);
  status = session_open(context->instance, context->bundle, &session_descriptor,
                        &context->session);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) goto fail_bundle;
  health->status = AGENTIC_AI_LAB_RUNTIME_V0_OK;
  return context;

fail_bundle:
  context->bundle_release(context->instance, context->bundle);
fail_profile:
  context->profile_release(context->instance, context->profile);
fail_instance:
  health->status = status;
  health_error(health, "native-context-open-failed");
  if (context->instance.instance_id != 0)
    context->instance_release(context->instance);
  AGENTIC_AI_LAB_LIBRARY_CLOSE(context->library);
  free(context);
  return NULL;
}

uint32_t agentic_ai_lab_python_runtime_v0_reconcile_evidence(
    agentic_ai_lab_python_runtime_v0_context *context,
    uint64_t mediation_sequence, uint64_t runtime_sequence,
    const uint64_t *nonce_high, const uint64_t *nonce_low,
    uint64_t nonce_count, const uint64_t *staged_mediation_sequences,
    const uint8_t *staged_leaf_digests, uint64_t staged_leaf_count,
    const uint8_t *semantic_root,
    const uint8_t *execution_root) {
  if (context == NULL || semantic_root == NULL || execution_root == NULL ||
      (nonce_count != 0 && (nonce_high == NULL || nonce_low == NULL)))
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  agentic_ai_lab_runtime_v0_compact_id *nonces = NULL;
  if (nonce_count != 0) {
    nonces = calloc((size_t)nonce_count, sizeof(*nonces));
    if (nonces == NULL) return AGENTIC_AI_LAB_RUNTIME_V0_ALLOCATION_FAILURE;
    for (uint64_t i = 0; i < nonce_count; ++i) {
      nonces[i].high = nonce_high[i];
      nonces[i].low = nonce_low[i];
    }
  }
  agentic_ai_lab_runtime_v0_evidence_reconciliation reconciliation = {0};
  reconciliation.struct_size = sizeof(reconciliation);
  reconciliation.mediation_sequence = mediation_sequence;
  reconciliation.runtime_sequence = runtime_sequence;
  reconciliation.consumed_nonces = nonces;
  reconciliation.consumed_nonce_count = nonce_count;
  reconciliation.staged_mediation_sequences = staged_mediation_sequences;
  reconciliation.staged_leaf_digests = staged_leaf_digests;
  reconciliation.staged_leaf_digest_stride = 32;
  reconciliation.staged_leaf_count = staged_leaf_count;
  memcpy(reconciliation.semantic_root, semantic_root, 32);
  memcpy(reconciliation.execution_root, execution_root, 32);
  agentic_ai_lab_runtime_v0_status status = context->session_reconcile_evidence(
      context->instance, context->session, &reconciliation);
  free(nonces);
  return status;
}

uint32_t agentic_ai_lab_python_runtime_v0_flush_batched(
    agentic_ai_lab_python_runtime_v0_context *context,
    const uint8_t *expected_execution_root,
    agentic_ai_lab_python_runtime_v0_evidence_flush_fn evidence_flush,
    void *evidence_context,
    agentic_ai_lab_python_runtime_v0_evidence_flush_result *result) {
  if (context == NULL || expected_execution_root == NULL ||
      evidence_flush == NULL || result == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  agentic_ai_lab_python_runtime_v0_evidence_context sink_context = {
      NULL, NULL, evidence_flush, evidence_context};
  agentic_ai_lab_runtime_v0_evidence_vtable evidence = {
      sizeof(evidence), 0, &sink_context, NULL, NULL,
      python_runtime_evidence_flush};
  agentic_ai_lab_runtime_v0_batched_flush_request request = {0};
  request.struct_size = sizeof(request);
  request.evidence = &evidence;
  memcpy(request.expected_execution_root, expected_execution_root, 32);
  agentic_ai_lab_runtime_v0_batched_flush_result flushed = {0};
  flushed.struct_size = sizeof(flushed);
  agentic_ai_lab_runtime_v0_status status = context->batched_flush(
      context->instance, context->session, &request, &flushed);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) return status;
  result->verification_flags = flushed.verification_flags;
  memcpy(result->after_execution_root, flushed.execution_root, 32);
  memcpy(result->batch_root, flushed.batch_root, 32);
  memcpy(result->evidence_digest, flushed.evidence_digest, 32);
  memcpy(result->attestation_digest, flushed.attestation_digest, 32);
  return AGENTIC_AI_LAB_RUNTIME_V0_OK;
}

uint32_t agentic_ai_lab_python_runtime_v0_arena_register(
    agentic_ai_lab_python_runtime_v0_context *context, uint8_t *memory,
    uint64_t capacity, uint32_t alignment, uint64_t generation) {
  if (context == NULL || memory == NULL || capacity == 0 || context->arena_alive)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  agentic_ai_lab_runtime_v0_arena_descriptor descriptor = {0};
  descriptor.struct_size = sizeof(descriptor);
  descriptor.alignment = alignment;
  descriptor.ptr = memory;
  descriptor.capacity = capacity;
  descriptor.generation = generation;
  agentic_ai_lab_runtime_v0_status status = context->arena_register(
      context->instance, &descriptor, &context->arena);
  if (status == AGENTIC_AI_LAB_RUNTIME_V0_OK) {
    context->arena_capacity = capacity;
    context->arena_generation = generation;
    context->arena_alive = 1;
  }
  return status;
}

uint32_t agentic_ai_lab_python_runtime_v0_arena_release(
    agentic_ai_lab_python_runtime_v0_context *context) {
  if (context == NULL || !context->arena_alive)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  agentic_ai_lab_runtime_v0_status status = context->arena_release(
      context->instance, context->arena);
  if (status == AGENTIC_AI_LAB_RUNTIME_V0_OK) context->arena_alive = 0;
  return status;
}

uint32_t agentic_ai_lab_python_runtime_v0_arena_recycle(
    agentic_ai_lab_python_runtime_v0_context *context, uint64_t expected_generation,
    uint64_t next_generation) {
  if (context == NULL || !context->arena_alive)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  agentic_ai_lab_runtime_v0_status status = context->arena_recycle(
      context->instance, context->arena, expected_generation, next_generation);
  if (status == AGENTIC_AI_LAB_RUNTIME_V0_OK)
    context->arena_generation = next_generation;
  return status;
}

uint32_t agentic_ai_lab_python_runtime_v0_roundtrip(
    agentic_ai_lab_python_runtime_v0_context *context,
    agentic_ai_lab_python_runtime_v0_event *events, uint64_t event_count,
    uint32_t *item_statuses, uint64_t item_status_capacity,
    uint8_t *accepted_bitmap, uint64_t accepted_bitmap_bytes,
    const agentic_ai_lab_python_runtime_v0_mediation *mediation,
    agentic_ai_lab_python_runtime_v0_evidence_reserve_fn evidence_reserve,
    agentic_ai_lab_python_runtime_v0_evidence_finalize_fn evidence_finalize,
    agentic_ai_lab_python_runtime_v0_evidence_flush_fn evidence_flush,
    void *evidence_context,
    agentic_ai_lab_python_runtime_v0_batch_result *result) {
  if (context == NULL || !context->arena_alive || events == NULL ||
      mediation == NULL || evidence_reserve == NULL ||
      evidence_finalize == NULL || result == NULL)
    return AGENTIC_AI_LAB_RUNTIME_V0_INVALID_ARGUMENT;
  memset(result, 0, sizeof(*result));
  agentic_ai_lab_runtime_v0_event_header *headers =
      (agentic_ai_lab_runtime_v0_event_header *)events;
  agentic_ai_lab_runtime_v0_publish_request publish = {0};
  publish.struct_size = sizeof(publish);
  publish.arena = context->arena;
  publish.arena_generation = context->arena_generation;
  publish.headers = headers;
  publish.header_stride = sizeof(*headers);
  publish.item_count = event_count;
  agentic_ai_lab_runtime_v0_publish_result published = {0};
  published.struct_size = sizeof(published);
  agentic_ai_lab_runtime_v0_status status = context->publish_batch(
      context->instance, context->session, &publish, &published);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) goto done;
  result->published_count = published.published_count;
  agentic_ai_lab_runtime_v0_poll_request poll = {0};
  poll.struct_size = sizeof(poll);
  poll.arena = context->arena;
  poll.arena_generation = context->arena_generation;
  poll.headers = headers;
  poll.header_stride = sizeof(*headers);
  poll.header_capacity = event_count;
  poll.payload_capacity = context->arena_capacity;
  agentic_ai_lab_runtime_v0_poll_result polled = {0};
  polled.struct_size = sizeof(polled);
  status = context->poll_batch(context->instance, context->session, &poll, &polled);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) goto done;
  result->produced_count = polled.produced_count;
  if (polled.produced_count != event_count) {
    status = AGENTIC_AI_LAB_RUNTIME_V0_INTERNAL_INVARIANT;
    goto done;
  }
  agentic_ai_lab_runtime_v0_submit_request submit = {0};
  submit.struct_size = sizeof(submit);
  submit.arena = context->arena;
  submit.arena_generation = context->arena_generation;
  submit.headers = headers;
  submit.header_stride = sizeof(*headers);
  submit.item_count = event_count;
  submit.item_statuses = item_statuses;
  submit.item_status_capacity = item_status_capacity;
  submit.accepted_bitmap = accepted_bitmap;
  submit.accepted_bitmap_bytes = accepted_bitmap_bytes;
  agentic_ai_lab_runtime_v0_submit_result submitted = {0};
  submitted.struct_size = sizeof(submitted);
  agentic_ai_lab_runtime_v0_strict_mediation_request mediation_request = {0};
  mediation_request.struct_size = sizeof(mediation_request);
  mediation_request.durability = mediation->durability;
  mediation_request.arena = context->arena;
  mediation_request.lease = polled.lease;
  mediation_request.arena_generation = context->arena_generation;
  mediation_request.bundle_epoch = mediation->bundle_epoch;
  mediation_request.first_sequence = polled.first_sequence;
  mediation_request.last_sequence = polled.last_sequence;
  mediation_request.nonce.high = mediation->nonce_high;
  mediation_request.nonce.low = mediation->nonce_low;
  memcpy(mediation_request.semantic_root, mediation->semantic_root, 32);
  memcpy(mediation_request.before_execution_root,
         mediation->before_execution_root, 32);
  agentic_ai_lab_python_runtime_v0_adapter_context adapter_context = {
      context, &submit, &submitted, mediation, result};
  agentic_ai_lab_runtime_v0_adapter_vtable adapter = {
      sizeof(adapter), 0, &adapter_context, python_runtime_adapter_execute};
  mediation_request.adapter = &adapter;
  agentic_ai_lab_python_runtime_v0_evidence_context sink_context = {
      evidence_reserve, evidence_finalize, evidence_flush, evidence_context};
  agentic_ai_lab_runtime_v0_evidence_vtable evidence = {
      sizeof(evidence), 0, &sink_context, python_runtime_evidence_reserve,
      python_runtime_evidence_finalize, python_runtime_evidence_flush};
  mediation_request.evidence = &evidence;
  agentic_ai_lab_runtime_v0_strict_mediation_result mediation_result = {0};
  mediation_result.struct_size = sizeof(mediation_result);
  status = context->strict_mediate(context->instance, context->session,
                                   &mediation_request, &mediation_result);
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) {
    context->batch_ack(context->instance, context->session, polled.lease);
    goto done;
  }
  result->mediation_sequence = mediation_result.mediation_sequence;
  result->mediation_outcome = mediation_result.outcome;
  result->adapter_status = mediation_result.adapter_status;
  result->evidence_status = mediation_result.evidence_status;
  result->verification_flags = mediation_result.verification_flags;
  memcpy(result->execution_root, mediation_result.execution_root, 32);
  memcpy(result->observation_digest, mediation_result.observation_digest, 32);
  memcpy(result->evidence_digest, mediation_result.evidence_digest, 32);
  memcpy(result->attestation_digest, mediation_result.attestation_digest, 32);
  status = context->batch_ack(context->instance, context->session, polled.lease);
done:
  result->status = status;
  return status;
}
