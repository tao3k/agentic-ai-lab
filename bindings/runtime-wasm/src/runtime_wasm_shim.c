// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include "agentic_ai_lab/runtime_wasm.h"

#include <stddef.h>
#include <string.h>

#define PFW_HANDLE_CAPACITY UINT32_C(1024)

typedef struct {
  agentic_ai_lab_runtime_v0_handle value;
  uint8_t occupied;
} pfw_handle_slot;

static pfw_handle_slot pfw_handles[PFW_HANDLE_CAPACITY];
static agentic_ai_lab_bundle_v1_arena *pfw_topologies[PFW_HANDLE_CAPACITY];

static agentic_ai_lab_runtime_v0_handle *pfw_handle_get(uint32_t slot) {
  if (slot == 0 || slot >= PFW_HANDLE_CAPACITY || !pfw_handles[slot].occupied) {
    return NULL;
  }
  return &pfw_handles[slot].value;
}

static uint32_t pfw_handle_store(
    agentic_ai_lab_runtime_v0_handle value,
    uint32_t *slot_out) {
  uint32_t slot;
  if (slot_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  for (slot = 1; slot < PFW_HANDLE_CAPACITY; slot += 1) {
    if (!pfw_handles[slot].occupied) {
      pfw_handles[slot].value = value;
      pfw_handles[slot].occupied = 1;
      *slot_out = slot;
      return 0;
    }
  }
  return PFW_WASM_STATUS_SLOT_EXHAUSTED;
}

static void pfw_handle_clear(uint32_t slot) {
  if (slot > 0 && slot < PFW_HANDLE_CAPACITY) {
    memset(&pfw_handles[slot], 0, sizeof(pfw_handles[slot]));
  }
}

uint32_t pfw_handle_capacity(void) {
  return PFW_HANDLE_CAPACITY - 1;
}

uint32_t pfw_instance_create(uint32_t *instance_slot_out) {
  agentic_ai_lab_runtime_v0_handle instance;
  uint32_t status;
  memset(&instance, 0, sizeof(instance));
  status = agentic_ai_lab_runtime_v0_instance_create(&instance);
  return status == 0 ? pfw_handle_store(instance, instance_slot_out) : status;
}

uint32_t pfw_instance_release(uint32_t instance_slot) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  uint32_t status;
  if (instance == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  status = agentic_ai_lab_runtime_v0_instance_release(*instance);
  if (status == 0) {
    pfw_handle_clear(instance_slot);
  }
  return status;
}

uint32_t pfw_negotiate(
    uint32_t instance_slot,
    const agentic_ai_lab_runtime_v0_negotiate_request *request,
    agentic_ai_lab_runtime_v0_negotiate_result *result,
    uint32_t *profile_slot_out) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  uint32_t status;
  if (instance == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  if (request == NULL || result == NULL || profile_slot_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  status = agentic_ai_lab_runtime_v0_negotiate(*instance, request, result);
  return status == 0 ? pfw_handle_store(result->profile, profile_slot_out) : status;
}

uint32_t pfw_profile_release(uint32_t instance_slot, uint32_t profile_slot) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *profile = pfw_handle_get(profile_slot);
  uint32_t status;
  if (instance == NULL || profile == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  status = agentic_ai_lab_runtime_v0_profile_release(*instance, *profile);
  if (status == 0) {
    pfw_handle_clear(profile_slot);
  }
  return status;
}

uint32_t pfw_bundle_open(
    uint32_t instance_slot,
    uint32_t profile_slot,
    const agentic_ai_lab_runtime_v0_bundle_descriptor *descriptor,
    uint32_t *bundle_slot_out) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *profile = pfw_handle_get(profile_slot);
  agentic_ai_lab_runtime_v0_handle bundle;
  uint32_t status;
  if (instance == NULL || profile == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  if (descriptor == NULL || bundle_slot_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  memset(&bundle, 0, sizeof(bundle));
  status = agentic_ai_lab_runtime_v0_bundle_open(*instance, *profile, descriptor, &bundle);
  return status == 0 ? pfw_handle_store(bundle, bundle_slot_out) : status;
}

uint32_t pfw_bundle_release(uint32_t instance_slot, uint32_t bundle_slot) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *bundle = pfw_handle_get(bundle_slot);
  uint32_t status;
  if (instance == NULL || bundle == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  status = agentic_ai_lab_runtime_v0_bundle_release(*instance, *bundle);
  if (status == 0) {
    pfw_handle_clear(bundle_slot);
  }
  return status;
}

uint32_t pfw_session_open(
    uint32_t instance_slot,
    uint32_t bundle_slot,
    const agentic_ai_lab_runtime_v0_session_descriptor *descriptor,
    uint32_t *session_slot_out) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *bundle = pfw_handle_get(bundle_slot);
  agentic_ai_lab_runtime_v0_handle session;
  uint32_t status;
  if (instance == NULL || bundle == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  if (descriptor == NULL || session_slot_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  memset(&session, 0, sizeof(session));
  status = agentic_ai_lab_runtime_v0_session_open(*instance, *bundle, descriptor, &session);
  return status == 0 ? pfw_handle_store(session, session_slot_out) : status;
}

uint32_t pfw_session_cancel(uint32_t instance_slot, uint32_t session_slot) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *session = pfw_handle_get(session_slot);
  return instance == NULL || session == NULL
      ? PFW_WASM_STATUS_INVALID_SLOT
      : agentic_ai_lab_runtime_v0_session_cancel(*instance, *session);
}

uint32_t pfw_session_close(
    uint32_t instance_slot,
    uint32_t session_slot,
    uint32_t disposition) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *session = pfw_handle_get(session_slot);
  return instance == NULL || session == NULL
      ? PFW_WASM_STATUS_INVALID_SLOT
      : agentic_ai_lab_runtime_v0_session_close(*instance, *session, disposition);
}

uint32_t pfw_session_release(uint32_t instance_slot, uint32_t session_slot) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *session = pfw_handle_get(session_slot);
  uint32_t status;
  if (instance == NULL || session == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  status = agentic_ai_lab_runtime_v0_session_release(*instance, *session);
  if (status == 0) {
    pfw_handle_clear(session_slot);
  }
  return status;
}

uint32_t pfw_arena_register(
    uint32_t instance_slot,
    const agentic_ai_lab_runtime_v0_arena_descriptor *descriptor,
    uint32_t *arena_slot_out) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle arena;
  uint32_t status;
  if (instance == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  if (descriptor == NULL || arena_slot_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  memset(&arena, 0, sizeof(arena));
  status = agentic_ai_lab_runtime_v0_arena_register(*instance, descriptor, &arena);
  return status == 0 ? pfw_handle_store(arena, arena_slot_out) : status;
}

uint32_t pfw_arena_recycle(
    uint32_t instance_slot,
    uint32_t arena_slot,
    uint64_t expected_generation,
    uint64_t next_generation) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *arena = pfw_handle_get(arena_slot);
  return instance == NULL || arena == NULL
      ? PFW_WASM_STATUS_INVALID_SLOT
      : agentic_ai_lab_runtime_v0_arena_recycle(
            *instance, *arena, expected_generation, next_generation);
}

uint32_t pfw_arena_release(uint32_t instance_slot, uint32_t arena_slot) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *arena = pfw_handle_get(arena_slot);
  uint32_t status;
  if (instance == NULL || arena == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  status = agentic_ai_lab_runtime_v0_arena_release(*instance, *arena);
  if (status == 0) {
    pfw_handle_clear(arena_slot);
  }
  return status;
}

uint32_t pfw_publish_batch(
    uint32_t instance_slot,
    uint32_t session_slot,
    uint32_t arena_slot,
    const agentic_ai_lab_runtime_v0_publish_request *request,
    agentic_ai_lab_runtime_v0_publish_result *result) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *session = pfw_handle_get(session_slot);
  agentic_ai_lab_runtime_v0_handle *arena = pfw_handle_get(arena_slot);
  agentic_ai_lab_runtime_v0_publish_request bridged;
  if (instance == NULL || session == NULL || arena == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  if (request == NULL || result == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  bridged = *request;
  bridged.arena = *arena;
  return agentic_ai_lab_runtime_v0_publish_batch(*instance, *session, &bridged, result);
}

uint32_t pfw_poll_batch(
    uint32_t instance_slot,
    uint32_t session_slot,
    uint32_t arena_slot,
    const agentic_ai_lab_runtime_v0_poll_request *request,
    agentic_ai_lab_runtime_v0_poll_result *result,
    uint32_t *lease_slot_out) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *session = pfw_handle_get(session_slot);
  agentic_ai_lab_runtime_v0_handle *arena = pfw_handle_get(arena_slot);
  agentic_ai_lab_runtime_v0_poll_request bridged;
  uint32_t status;
  if (instance == NULL || session == NULL || arena == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  if (request == NULL || result == NULL || lease_slot_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  bridged = *request;
  bridged.arena = *arena;
  status = agentic_ai_lab_runtime_v0_poll_batch(*instance, *session, &bridged, result);
  return status == 0 ? pfw_handle_store(result->lease, lease_slot_out) : status;
}

uint32_t pfw_submit_batch(
    uint32_t instance_slot,
    uint32_t session_slot,
    uint32_t arena_slot,
    const agentic_ai_lab_runtime_v0_submit_request *request,
    agentic_ai_lab_runtime_v0_submit_result *result) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *session = pfw_handle_get(session_slot);
  agentic_ai_lab_runtime_v0_handle *arena = pfw_handle_get(arena_slot);
  agentic_ai_lab_runtime_v0_submit_request bridged;
  if (instance == NULL || session == NULL || arena == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  if (request == NULL || result == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  bridged = *request;
  bridged.arena = *arena;
  return agentic_ai_lab_runtime_v0_submit_batch(*instance, *session, &bridged, result);
}

uint32_t pfw_batch_ack(
    uint32_t instance_slot,
    uint32_t session_slot,
    uint32_t lease_slot) {
  agentic_ai_lab_runtime_v0_handle *instance = pfw_handle_get(instance_slot);
  agentic_ai_lab_runtime_v0_handle *session = pfw_handle_get(session_slot);
  agentic_ai_lab_runtime_v0_handle *lease = pfw_handle_get(lease_slot);
  uint32_t status;
  if (instance == NULL || session == NULL || lease == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  status = agentic_ai_lab_runtime_v0_batch_ack(*instance, *session, *lease);
  if (status == 0) {
    pfw_handle_clear(lease_slot);
  }
  return status;
}

static agentic_ai_lab_bundle_v1_arena *pfw_topology_get(uint32_t slot) {
  if (slot == 0u || slot >= PFW_HANDLE_CAPACITY) {
    return NULL;
  }
  return pfw_topologies[slot];
}

static uint32_t pfw_topology_store(
    agentic_ai_lab_bundle_v1_arena *arena,
    uint32_t *slot_out) {
  uint32_t slot;
  if (arena == NULL || slot_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  for (slot = 1u; slot < PFW_HANDLE_CAPACITY; slot += 1u) {
    if (pfw_topologies[slot] == NULL) {
      pfw_topologies[slot] = arena;
      *slot_out = slot;
      return 0u;
    }
  }
  return PFW_WASM_STATUS_SLOT_EXHAUSTED;
}

static uint32_t pfw_topology_slice(
    uint32_t topology_slot,
    uint32_t region_kind,
    agentic_ai_lab_bundle_v1_slice *slice_out) {
  agentic_ai_lab_bundle_v1_arena *arena = pfw_topology_get(topology_slot);
  if (arena == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  if (slice_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  return agentic_ai_lab_bundle_v1_arena_slice(arena, region_kind, slice_out);
}

static uint32_t pfw_topology_count(
    uint32_t topology_slot,
    uint32_t region_kind,
    uint32_t *count_out) {
  agentic_ai_lab_bundle_v1_slice slice;
  uint32_t status;
  if (count_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  status = pfw_topology_slice(topology_slot, region_kind, &slice);
  if (status != 0u) {
    return status;
  }
  if (slice.stride == 0u || slice.length % slice.stride != 0u ||
      slice.length / slice.stride > UINT32_MAX) {
    return AGENTIC_AI_LAB_BUNDLE_V1_REGION_LAYOUT;
  }
  *count_out = (uint32_t)(slice.length / slice.stride);
  return 0u;
}

static uint32_t pfw_topology_row_at(
    uint32_t topology_slot,
    uint32_t region_kind,
    uint32_t index,
    uint32_t expected_stride,
    void *entry_out) {
  agentic_ai_lab_bundle_v1_slice slice;
  uint64_t offset;
  uint32_t status;
  if (entry_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  status = pfw_topology_slice(topology_slot, region_kind, &slice);
  if (status != 0u) {
    return status;
  }
  if (slice.stride != expected_stride) {
    return AGENTIC_AI_LAB_BUNDLE_V1_REGION_LAYOUT;
  }
  offset = (uint64_t)index * slice.stride;
  if (offset > slice.length || slice.length - offset < slice.stride) {
    return AGENTIC_AI_LAB_BUNDLE_V1_NOT_FOUND;
  }
  memcpy(entry_out, (const uint8_t *)slice.data + offset, slice.stride);
  return 0u;
}

uint32_t pfw_topology_open_packed(
    const void *descriptor_bytes,
    uint32_t descriptor_length,
    const void *arena_bytes,
    uint32_t arena_length,
    uint32_t *topology_slot_out) {
  agentic_ai_lab_bundle_v1_arena *arena = NULL;
  uint32_t status;
  if (descriptor_bytes == NULL || arena_bytes == NULL ||
      topology_slot_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  status = agentic_ai_lab_bundle_v1_arena_create_packed(
      descriptor_bytes, descriptor_length, arena_bytes, arena_length, &arena);
  if (status != 0u) {
    return status;
  }
  status = pfw_topology_store(arena, topology_slot_out);
  if (status != 0u) {
    agentic_ai_lab_bundle_v1_arena_release(arena);
  }
  return status;
}

uint32_t pfw_topology_component_count(
    uint32_t topology_slot,
    uint32_t *count_out) {
  return pfw_topology_count(
      topology_slot, AGENTIC_AI_LAB_BUNDLE_V1_REGION_COMPONENTS, count_out);
}

uint32_t pfw_topology_edge_count(
    uint32_t topology_slot,
    uint32_t *count_out) {
  return pfw_topology_count(
      topology_slot, AGENTIC_AI_LAB_BUNDLE_V1_REGION_EDGES, count_out);
}

uint32_t pfw_topology_symbol_count(
    uint32_t topology_slot,
    uint32_t *count_out) {
  return pfw_topology_count(
      topology_slot, AGENTIC_AI_LAB_BUNDLE_V1_REGION_SYMBOLS, count_out);
}

uint32_t pfw_topology_component_at(
    uint32_t topology_slot,
    uint32_t index,
    agentic_ai_lab_bundle_v1_component_entry *entry_out) {
  return pfw_topology_row_at(
      topology_slot, AGENTIC_AI_LAB_BUNDLE_V1_REGION_COMPONENTS, index,
      sizeof(*entry_out), entry_out);
}

uint32_t pfw_topology_edge_at(
    uint32_t topology_slot,
    uint32_t index,
    agentic_ai_lab_bundle_v1_edge_entry *entry_out) {
  return pfw_topology_row_at(
      topology_slot, AGENTIC_AI_LAB_BUNDLE_V1_REGION_EDGES, index,
      sizeof(*entry_out), entry_out);
}

uint32_t pfw_topology_symbol_at(
    uint32_t topology_slot,
    uint32_t index,
    agentic_ai_lab_bundle_v1_symbol_entry *entry_out) {
  return pfw_topology_row_at(
      topology_slot, AGENTIC_AI_LAB_BUNDLE_V1_REGION_SYMBOLS, index,
      sizeof(*entry_out), entry_out);
}

uint32_t pfw_topology_metadata_copy(
    uint32_t topology_slot,
    uint32_t offset,
    uint32_t length,
    void *bytes_out) {
  agentic_ai_lab_bundle_v1_slice slice;
  uint32_t status;
  if (bytes_out == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  status = pfw_topology_slice(
      topology_slot, AGENTIC_AI_LAB_BUNDLE_V1_REGION_METADATA_BYTES, &slice);
  if (status != 0u) {
    return status;
  }
  if ((uint64_t)offset > slice.length ||
      slice.length - (uint64_t)offset < (uint64_t)length) {
    return AGENTIC_AI_LAB_BUNDLE_V1_REGION_BOUNDS;
  }
  memcpy(bytes_out, (const uint8_t *)slice.data + offset, length);
  return 0u;
}

uint32_t pfw_topology_release(uint32_t topology_slot) {
  agentic_ai_lab_bundle_v1_arena *arena = pfw_topology_get(topology_slot);
  if (arena == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  agentic_ai_lab_bundle_v1_arena_release(arena);
  pfw_topologies[topology_slot] = NULL;
  return 0u;
}
