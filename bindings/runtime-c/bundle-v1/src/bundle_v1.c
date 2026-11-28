// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include "agentic_ai_lab/bundle_v1.h"

#include <stddef.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

struct agentic_ai_lab_bundle_v1_arena {
  atomic_uint_least64_t reference_count;
  agentic_ai_lab_bundle_v1_descriptor descriptor;
  uint64_t arena_bytes;
  void *data;
};

static int compact_id_compare(agentic_ai_lab_bundle_v1_compact_id left,
                              agentic_ai_lab_bundle_v1_compact_id right) {
  if (left.high < right.high) {
    return -1;
  }
  if (left.high > right.high) {
    return 1;
  }
  if (left.low < right.low) {
    return -1;
  }
  if (left.low > right.low) {
    return 1;
  }
  return 0;
}

static int host_is_little_endian(void) {
  const uint16_t marker = UINT16_C(1);
  return *((const uint8_t *)&marker) == UINT8_C(1);
}

static int component_key_compare(
    const agentic_ai_lab_bundle_v1_component_entry *entry,
    agentic_ai_lab_bundle_v1_compact_id case_id,
    agentic_ai_lab_bundle_v1_compact_id component_id) {
  const int case_order = compact_id_compare(entry->case_id, case_id);
  return case_order == 0
             ? compact_id_compare(entry->component_id, component_id)
             : case_order;
}

static int is_power_of_two(uint32_t value) {
  return value != 0u && (value & (value - 1u)) == 0u;
}

static agentic_ai_lab_bundle_v1_status validate_region(
    const agentic_ai_lab_bundle_v1_region *region,
    const void *arena,
    uint64_t arena_bytes,
    uint32_t expected_stride,
    uint32_t minimum_alignment) {
  if (region->offset > arena_bytes || region->length > arena_bytes - region->offset) {
    return AGENTIC_AI_LAB_BUNDLE_V1_REGION_BOUNDS;
  }
  if (!is_power_of_two(region->alignment) ||
      region->alignment < minimum_alignment ||
      region->offset % region->alignment != 0u ||
      ((uintptr_t)arena + (uintptr_t)region->offset) % region->alignment != 0u) {
    return AGENTIC_AI_LAB_BUNDLE_V1_REGION_LAYOUT;
  }
  if (expected_stride == 0u) {
    if (region->stride != 1u) {
      return AGENTIC_AI_LAB_BUNDLE_V1_REGION_LAYOUT;
    }
  } else if (region->stride != expected_stride ||
             region->length % expected_stride != 0u) {
    return AGENTIC_AI_LAB_BUNDLE_V1_REGION_LAYOUT;
  }
  return AGENTIC_AI_LAB_BUNDLE_V1_OK;
}

static const uint8_t *region_base(const void *arena,
                                  const agentic_ai_lab_bundle_v1_region *region) {
  return (const uint8_t *)arena + region->offset;
}

static const agentic_ai_lab_bundle_v1_region *descriptor_region(
    const agentic_ai_lab_bundle_v1_descriptor *descriptor,
    agentic_ai_lab_bundle_v1_region_kind region_kind) {
  switch (region_kind) {
    case AGENTIC_AI_LAB_BUNDLE_V1_REGION_SYMBOLS:
      return &descriptor->symbols;
    case AGENTIC_AI_LAB_BUNDLE_V1_REGION_COMPONENTS:
      return &descriptor->components;
    case AGENTIC_AI_LAB_BUNDLE_V1_REGION_EDGES:
      return &descriptor->edges;
    case AGENTIC_AI_LAB_BUNDLE_V1_REGION_EVIDENCE_OBLIGATIONS:
      return &descriptor->evidence_obligations;
    case AGENTIC_AI_LAB_BUNDLE_V1_REGION_METADATA_BYTES:
      return &descriptor->metadata_bytes;
    default:
      return NULL;
  }
}

static agentic_ai_lab_bundle_v1_status validate_digest(
    const agentic_ai_lab_bundle_v1_descriptor *descriptor) {
  uint8_t aggregate = 0u;
  size_t index = 0u;
  for (; index < AGENTIC_AI_LAB_BUNDLE_V1_DIGEST_BYTES; ++index) {
    aggregate = (uint8_t)(aggregate | descriptor->digest[index]);
  }
  return aggregate == 0u ? AGENTIC_AI_LAB_BUNDLE_V1_MALFORMED_DESCRIPTOR
                         : AGENTIC_AI_LAB_BUNDLE_V1_OK;
}

static agentic_ai_lab_bundle_v1_status validate_symbols(
    const agentic_ai_lab_bundle_v1_descriptor *descriptor,
    const void *arena) {
  const agentic_ai_lab_bundle_v1_symbol_entry *entries =
      (const agentic_ai_lab_bundle_v1_symbol_entry *)region_base(
          arena, &descriptor->symbols);
  const uint64_t count = descriptor->symbols.length /
                         (uint64_t)sizeof(agentic_ai_lab_bundle_v1_symbol_entry);
  uint64_t index = 0u;
  for (; index < count; ++index) {
    const agentic_ai_lab_bundle_v1_symbol_entry *entry = &entries[index];
    if (entry->flags != 0u ||
        entry->byte_offset > descriptor->metadata_bytes.length ||
        entry->byte_length >
            descriptor->metadata_bytes.length - entry->byte_offset) {
      return AGENTIC_AI_LAB_BUNDLE_V1_REGION_BOUNDS;
    }
    if (index != 0u) {
      const int order =
          compact_id_compare(entries[index - 1u].symbol_id, entry->symbol_id);
      if (order > 0) {
        return AGENTIC_AI_LAB_BUNDLE_V1_UNSORTED_TABLE;
      }
      if (order == 0) {
        return AGENTIC_AI_LAB_BUNDLE_V1_DUPLICATE_KEY;
      }
    }
  }
  return AGENTIC_AI_LAB_BUNDLE_V1_OK;
}

static agentic_ai_lab_bundle_v1_status validate_components(
    const agentic_ai_lab_bundle_v1_descriptor *descriptor,
    const void *arena) {
  const agentic_ai_lab_bundle_v1_component_entry *entries =
      (const agentic_ai_lab_bundle_v1_component_entry *)region_base(
          arena, &descriptor->components);
  const uint64_t count = descriptor->components.length /
                         (uint64_t)sizeof(agentic_ai_lab_bundle_v1_component_entry);
  uint64_t index = 0u;
  for (; index < count; ++index) {
    const agentic_ai_lab_bundle_v1_component_entry *entry = &entries[index];
    if ((entry->flags & ~AGENTIC_AI_LAB_BUNDLE_V1_COMPONENT_KNOWN_FLAGS) != 0u ||
        entry->reserved0 != 0u || entry->reserved1 != 0u) {
      return AGENTIC_AI_LAB_BUNDLE_V1_MALFORMED_DESCRIPTOR;
    }
    if (index != 0u) {
      const agentic_ai_lab_bundle_v1_component_entry *previous =
          &entries[index - 1u];
      const int case_order =
          compact_id_compare(previous->case_id, entry->case_id);
      const int component_order = case_order == 0
                                      ? compact_id_compare(
                                            previous->component_id,
                                            entry->component_id)
                                      : case_order;
      if (component_order > 0) {
        return AGENTIC_AI_LAB_BUNDLE_V1_UNSORTED_TABLE;
      }
      if (component_order == 0) {
        return AGENTIC_AI_LAB_BUNDLE_V1_DUPLICATE_KEY;
      }
    }
  }
  return AGENTIC_AI_LAB_BUNDLE_V1_OK;
}

static agentic_ai_lab_bundle_v1_status validate_edges(
    const agentic_ai_lab_bundle_v1_descriptor *descriptor,
    const void *arena) {
  const agentic_ai_lab_bundle_v1_edge_entry *entries =
      (const agentic_ai_lab_bundle_v1_edge_entry *)region_base(arena,
                                                         &descriptor->edges);
  const uint64_t count = descriptor->edges.length /
                         (uint64_t)sizeof(agentic_ai_lab_bundle_v1_edge_entry);
  uint64_t index = 0u;
  for (; index < count; ++index) {
    const agentic_ai_lab_bundle_v1_edge_entry *entry = &entries[index];
    if (entry->flags != 0u || entry->reserved0 != 0u) {
      return AGENTIC_AI_LAB_BUNDLE_V1_MALFORMED_DESCRIPTOR;
    }
    if (index != 0u) {
      const agentic_ai_lab_bundle_v1_edge_entry *previous = &entries[index - 1u];
      int order = compact_id_compare(previous->case_id, entry->case_id);
      if (order == 0) {
        order = compact_id_compare(previous->source_component_id,
                                   entry->source_component_id);
      }
      if (order == 0 && previous->composition_order < entry->composition_order) {
        order = -1;
      } else if (order == 0 &&
                 previous->composition_order > entry->composition_order) {
        order = 1;
      }
      if (order == 0) {
        order = compact_id_compare(previous->target_component_id,
                                   entry->target_component_id);
      }
      if (order == 0) {
        order = compact_id_compare(previous->relation_id, entry->relation_id);
      }
      if (order > 0) {
        return AGENTIC_AI_LAB_BUNDLE_V1_UNSORTED_TABLE;
      }
      if (order == 0) {
        return AGENTIC_AI_LAB_BUNDLE_V1_DUPLICATE_KEY;
      }
    }
  }
  return AGENTIC_AI_LAB_BUNDLE_V1_OK;
}

static agentic_ai_lab_bundle_v1_status validate_evidence(
    const agentic_ai_lab_bundle_v1_descriptor *descriptor,
    const void *arena) {
  const agentic_ai_lab_bundle_v1_evidence_entry *entries =
      (const agentic_ai_lab_bundle_v1_evidence_entry *)region_base(
          arena, &descriptor->evidence_obligations);
  const uint64_t count = descriptor->evidence_obligations.length /
                         (uint64_t)sizeof(agentic_ai_lab_bundle_v1_evidence_entry);
  uint64_t index = 0u;
  for (; index < count; ++index) {
    const agentic_ai_lab_bundle_v1_evidence_entry *entry = &entries[index];
    if (entry->flags != 0u || entry->reserved0 != 0u) {
      return AGENTIC_AI_LAB_BUNDLE_V1_MALFORMED_DESCRIPTOR;
    }
    if (index != 0u) {
      const agentic_ai_lab_bundle_v1_evidence_entry *previous = &entries[index - 1u];
      int order = compact_id_compare(previous->case_id, entry->case_id);
      if (order == 0) {
        order = compact_id_compare(previous->obligation_id,
                                   entry->obligation_id);
      }
      if (order > 0) {
        return AGENTIC_AI_LAB_BUNDLE_V1_UNSORTED_TABLE;
      }
      if (order == 0) {
        return AGENTIC_AI_LAB_BUNDLE_V1_DUPLICATE_KEY;
      }
    }
  }
  return AGENTIC_AI_LAB_BUNDLE_V1_OK;
}

agentic_ai_lab_bundle_v1_status agentic_ai_lab_bundle_v1_validate(
    const agentic_ai_lab_bundle_v1_descriptor *descriptor,
    const void *arena,
    uint64_t arena_bytes) {
  agentic_ai_lab_bundle_v1_status status = AGENTIC_AI_LAB_BUNDLE_V1_OK;
  if (descriptor == NULL || (arena == NULL && arena_bytes != 0u)) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  if (arena == NULL || arena_bytes > (uint64_t)SIZE_MAX) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  if (descriptor->struct_size < sizeof(*descriptor) ||
      descriptor->schema_major != AGENTIC_AI_LAB_BUNDLE_V1_SCHEMA_MAJOR ||
      descriptor->schema_minor > AGENTIC_AI_LAB_BUNDLE_V1_SCHEMA_MINOR) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INCOMPATIBLE_SCHEMA;
  }
  if ((descriptor->flags & AGENTIC_AI_LAB_BUNDLE_V1_DESCRIPTOR_KNOWN_FLAGS) !=
          AGENTIC_AI_LAB_BUNDLE_V1_DESCRIPTOR_KNOWN_FLAGS ||
      descriptor->reserved0 != 0u ||
      descriptor->arena_bytes != arena_bytes) {
    return AGENTIC_AI_LAB_BUNDLE_V1_MALFORMED_DESCRIPTOR;
  }
  {
    size_t reserved_index = 0u;
    for (; reserved_index < 7u; ++reserved_index) {
      if (descriptor->reserved[reserved_index] != 0u) {
        return AGENTIC_AI_LAB_BUNDLE_V1_MALFORMED_DESCRIPTOR;
      }
    }
  }
  status = validate_digest(descriptor);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK) {
    return status;
  }

#define VALIDATE_TYPED_REGION(field, type)                                    \
  status = validate_region(&descriptor->field, arena, arena_bytes,            \
                           (uint32_t)sizeof(type), (uint32_t)_Alignof(type));  \
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK) {                                      \
    return status;                                                            \
  }

  VALIDATE_TYPED_REGION(symbols, agentic_ai_lab_bundle_v1_symbol_entry)
  VALIDATE_TYPED_REGION(components, agentic_ai_lab_bundle_v1_component_entry)
  VALIDATE_TYPED_REGION(edges, agentic_ai_lab_bundle_v1_edge_entry)
  VALIDATE_TYPED_REGION(evidence_obligations, agentic_ai_lab_bundle_v1_evidence_entry)
  status = validate_region(&descriptor->metadata_bytes, arena, arena_bytes, 0u,
                           1u);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK) {
    return status;
  }
#undef VALIDATE_TYPED_REGION

  status = validate_symbols(descriptor, arena);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK) {
    return status;
  }
  status = validate_components(descriptor, arena);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK) {
    return status;
  }
  status = validate_edges(descriptor, arena);
  return status == AGENTIC_AI_LAB_BUNDLE_V1_OK
             ? validate_evidence(descriptor, arena)
             : status;
}

agentic_ai_lab_bundle_v1_status agentic_ai_lab_bundle_v1_find_component(
    const agentic_ai_lab_bundle_v1_descriptor *descriptor,
    const void *arena,
    agentic_ai_lab_bundle_v1_compact_id case_id,
    agentic_ai_lab_bundle_v1_compact_id component_id,
    const agentic_ai_lab_bundle_v1_component_entry **out_component) {
  const agentic_ai_lab_bundle_v1_component_entry *entries = NULL;
  uint64_t low = 0u;
  uint64_t high = 0u;
  if (descriptor == NULL || arena == NULL || out_component == NULL) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  *out_component = NULL;
  if (descriptor->components.stride != sizeof(*entries) ||
      descriptor->components.length % sizeof(*entries) != 0u ||
      descriptor->components.offset > descriptor->arena_bytes ||
      descriptor->components.length >
          descriptor->arena_bytes - descriptor->components.offset) {
    return AGENTIC_AI_LAB_BUNDLE_V1_MALFORMED_DESCRIPTOR;
  }
  entries = (const agentic_ai_lab_bundle_v1_component_entry *)region_base(
      arena, &descriptor->components);
  high = descriptor->components.length / (uint64_t)sizeof(*entries);
  while (low < high) {
    const uint64_t middle = low + (high - low) / 2u;
    const int order =
        component_key_compare(&entries[middle], case_id, component_id);
    if (order < 0) {
      low = middle + 1u;
    } else {
      high = middle;
    }
  }
  if (low < descriptor->components.length / (uint64_t)sizeof(*entries) &&
      component_key_compare(&entries[low], case_id, component_id) == 0) {
    *out_component = &entries[low];
    return AGENTIC_AI_LAB_BUNDLE_V1_OK;
  }
  return AGENTIC_AI_LAB_BUNDLE_V1_NOT_FOUND;
}

agentic_ai_lab_bundle_v1_status agentic_ai_lab_bundle_v1_arena_create(
    const agentic_ai_lab_bundle_v1_descriptor *descriptor,
    const void *arena,
    uint64_t arena_bytes,
    agentic_ai_lab_bundle_v1_arena **out_arena) {
  agentic_ai_lab_bundle_v1_arena *owned = NULL;
  void *owned_data = NULL;
  size_t allocation_bytes = 0u;
  agentic_ai_lab_bundle_v1_status status = AGENTIC_AI_LAB_BUNDLE_V1_OK;
  if (out_arena == NULL) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  *out_arena = NULL;
  if (descriptor == NULL || arena == NULL) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  if (arena_bytes > (uint64_t)SIZE_MAX -
                        (AGENTIC_AI_LAB_BUNDLE_V1_RECOMMENDED_ARENA_ALIGNMENT - 1u)) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  status = agentic_ai_lab_bundle_v1_validate(descriptor, arena, arena_bytes);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK) {
    return status;
  }
  allocation_bytes =
      (size_t)((arena_bytes +
                (AGENTIC_AI_LAB_BUNDLE_V1_RECOMMENDED_ARENA_ALIGNMENT - 1u)) &
               ~(uint64_t)(AGENTIC_AI_LAB_BUNDLE_V1_RECOMMENDED_ARENA_ALIGNMENT -
                           1u));
  if (allocation_bytes == 0u) {
    allocation_bytes = AGENTIC_AI_LAB_BUNDLE_V1_RECOMMENDED_ARENA_ALIGNMENT;
  }
  owned = (agentic_ai_lab_bundle_v1_arena *)malloc(sizeof(*owned));
  if (owned == NULL) {
    return AGENTIC_AI_LAB_BUNDLE_V1_OUT_OF_MEMORY;
  }
  owned_data =
      aligned_alloc(AGENTIC_AI_LAB_BUNDLE_V1_RECOMMENDED_ARENA_ALIGNMENT,
                    allocation_bytes);
  if (owned_data == NULL) {
    free(owned);
    return AGENTIC_AI_LAB_BUNDLE_V1_OUT_OF_MEMORY;
  }
  memcpy(owned_data, arena, (size_t)arena_bytes);
  atomic_init(&owned->reference_count, UINT64_C(1));
  owned->descriptor = *descriptor;
  owned->arena_bytes = arena_bytes;
  owned->data = owned_data;
  status = agentic_ai_lab_bundle_v1_validate(&owned->descriptor, owned->data,
                                       owned->arena_bytes);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK) {
    free(owned_data);
    free(owned);
    return status;
  }
  *out_arena = owned;
  return AGENTIC_AI_LAB_BUNDLE_V1_OK;
}

agentic_ai_lab_bundle_v1_status agentic_ai_lab_bundle_v1_arena_create_packed(
    const void *descriptor_bytes,
    uint64_t descriptor_length,
    const void *arena,
    uint64_t arena_bytes,
    agentic_ai_lab_bundle_v1_arena **out_arena) {
  agentic_ai_lab_bundle_v1_descriptor descriptor;
  if (out_arena == NULL) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  *out_arena = NULL;
  if (!host_is_little_endian()) {
    return AGENTIC_AI_LAB_BUNDLE_V1_UNSUPPORTED_ENDIAN;
  }
  if (descriptor_bytes == NULL ||
      descriptor_length != (uint64_t)sizeof(descriptor)) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  memcpy(&descriptor, descriptor_bytes, sizeof(descriptor));
  return agentic_ai_lab_bundle_v1_arena_create(&descriptor, arena, arena_bytes,
                                         out_arena);
}

agentic_ai_lab_bundle_v1_status agentic_ai_lab_bundle_v1_arena_retain(
    agentic_ai_lab_bundle_v1_arena *arena) {
  uint_least64_t references = 0u;
  if (arena == NULL) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  references = atomic_load(&arena->reference_count);
  for (;;) {
    if (references == UINT64_MAX) {
      return AGENTIC_AI_LAB_BUNDLE_V1_REFERENCE_LIMIT;
    }
    if (atomic_compare_exchange_weak(&arena->reference_count, &references,
                                     references + 1u)) {
      return AGENTIC_AI_LAB_BUNDLE_V1_OK;
    }
  }
}

void agentic_ai_lab_bundle_v1_arena_release(agentic_ai_lab_bundle_v1_arena *arena) {
  if (arena != NULL &&
      atomic_fetch_sub(&arena->reference_count, UINT64_C(1)) == UINT64_C(1)) {
    free(arena->data);
    arena->data = NULL;
    free(arena);
  }
}

agentic_ai_lab_bundle_v1_status agentic_ai_lab_bundle_v1_arena_view(
    const agentic_ai_lab_bundle_v1_arena *arena,
    const agentic_ai_lab_bundle_v1_descriptor **out_descriptor,
    const void **out_data,
    uint64_t *out_bytes) {
  if (arena == NULL || out_descriptor == NULL || out_data == NULL ||
      out_bytes == NULL) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  *out_descriptor = &arena->descriptor;
  *out_data = arena->data;
  *out_bytes = arena->arena_bytes;
  return AGENTIC_AI_LAB_BUNDLE_V1_OK;
}

agentic_ai_lab_bundle_v1_status agentic_ai_lab_bundle_v1_arena_slice(
    const agentic_ai_lab_bundle_v1_arena *arena,
    agentic_ai_lab_bundle_v1_region_kind region_kind,
    agentic_ai_lab_bundle_v1_slice *out_slice) {
  const agentic_ai_lab_bundle_v1_region *region = NULL;
  if (arena == NULL || out_slice == NULL) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  region = descriptor_region(&arena->descriptor, region_kind);
  if (region == NULL) {
    memset(out_slice, 0, sizeof(*out_slice));
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  out_slice->data = region_base(arena->data, region);
  out_slice->length = region->length;
  out_slice->stride = region->stride;
  out_slice->alignment = region->alignment;
  return AGENTIC_AI_LAB_BUNDLE_V1_OK;
}

agentic_ai_lab_bundle_v1_status agentic_ai_lab_bundle_v1_arena_find_component(
    const agentic_ai_lab_bundle_v1_arena *arena,
    agentic_ai_lab_bundle_v1_compact_id case_id,
    agentic_ai_lab_bundle_v1_compact_id component_id,
    const agentic_ai_lab_bundle_v1_component_entry **out_component) {
  if (arena == NULL) {
    return AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT;
  }
  return agentic_ai_lab_bundle_v1_find_component(&arena->descriptor, arena->data,
                                           case_id, component_id,
                                           out_component);
}

const char *agentic_ai_lab_bundle_v1_status_name(agentic_ai_lab_bundle_v1_status status) {
  switch (status) {
    case AGENTIC_AI_LAB_BUNDLE_V1_OK:
      return "ok";
    case AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT:
      return "invalid-argument";
    case AGENTIC_AI_LAB_BUNDLE_V1_INCOMPATIBLE_SCHEMA:
      return "incompatible-schema";
    case AGENTIC_AI_LAB_BUNDLE_V1_MALFORMED_DESCRIPTOR:
      return "malformed-descriptor";
    case AGENTIC_AI_LAB_BUNDLE_V1_REGION_BOUNDS:
      return "region-bounds";
    case AGENTIC_AI_LAB_BUNDLE_V1_REGION_LAYOUT:
      return "region-layout";
    case AGENTIC_AI_LAB_BUNDLE_V1_UNSORTED_TABLE:
      return "unsorted-table";
    case AGENTIC_AI_LAB_BUNDLE_V1_DUPLICATE_KEY:
      return "duplicate-key";
    case AGENTIC_AI_LAB_BUNDLE_V1_NOT_FOUND:
      return "not-found";
    case AGENTIC_AI_LAB_BUNDLE_V1_OUT_OF_MEMORY:
      return "out-of-memory";
    case AGENTIC_AI_LAB_BUNDLE_V1_REFERENCE_LIMIT:
      return "reference-limit";
    case AGENTIC_AI_LAB_BUNDLE_V1_UNSUPPORTED_ENDIAN:
      return "unsupported-endian";
    default:
      return "unknown";
  }
}
