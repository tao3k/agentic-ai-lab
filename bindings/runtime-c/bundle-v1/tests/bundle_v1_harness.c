// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include "agentic_ai_lab/bundle_v1.h"

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef union aligned_arena {
  max_align_t alignment;
  uint8_t bytes[4096];
} aligned_arena;

static int failures = 0;

static void expect_status(const char *name,
                          agentic_ai_lab_bundle_v1_status actual,
                          agentic_ai_lab_bundle_v1_status expected) {
  if (actual != expected) {
    fprintf(stderr, "%s: expected %s, got %s\n", name,
            agentic_ai_lab_bundle_v1_status_name(expected),
            agentic_ai_lab_bundle_v1_status_name(actual));
    failures += 1;
  }
}

static agentic_ai_lab_bundle_v1_compact_id compact_id(uint64_t value) {
  agentic_ai_lab_bundle_v1_compact_id result = {0u, value};
  return result;
}

static agentic_ai_lab_bundle_v1_region region(uint64_t offset,
                                        uint64_t length,
                                        uint32_t stride,
                                        uint32_t alignment) {
  agentic_ai_lab_bundle_v1_region result = {offset, length, stride, alignment};
  return result;
}

static agentic_ai_lab_bundle_v1_descriptor make_descriptor(
    const agentic_ai_lab_bundle_v1_component_entry *components,
    size_t component_count,
    aligned_arena *arena) {
  agentic_ai_lab_bundle_v1_descriptor descriptor;
  const uint64_t component_offset = 64u;
  memset(&descriptor, 0, sizeof(descriptor));
  memset(arena, 0, sizeof(*arena));
  memcpy(&arena->bytes[component_offset], components,
         component_count * sizeof(*components));
  descriptor.struct_size = (uint32_t)sizeof(descriptor);
  descriptor.flags = AGENTIC_AI_LAB_BUNDLE_V1_DESCRIPTOR_F_SORTED |
                     AGENTIC_AI_LAB_BUNDLE_V1_DESCRIPTOR_F_ZERO_COPY;
  descriptor.schema_major = AGENTIC_AI_LAB_BUNDLE_V1_SCHEMA_MAJOR;
  descriptor.schema_minor = AGENTIC_AI_LAB_BUNDLE_V1_SCHEMA_MINOR;
  descriptor.bundle_id = compact_id(1u);
  descriptor.digest[0] = 0x7fu;
  descriptor.bundle_epoch = 9u;
  descriptor.arena_bytes = sizeof(arena->bytes);
  descriptor.symbols = region(0u, 0u,
                              (uint32_t)sizeof(agentic_ai_lab_bundle_v1_symbol_entry),
                              (uint32_t)_Alignof(agentic_ai_lab_bundle_v1_symbol_entry));
  descriptor.components = region(
      component_offset, component_count * sizeof(*components),
      (uint32_t)sizeof(*components),
      (uint32_t)_Alignof(agentic_ai_lab_bundle_v1_component_entry));
  descriptor.edges = region(
      0u, 0u, (uint32_t)sizeof(agentic_ai_lab_bundle_v1_edge_entry),
      (uint32_t)_Alignof(agentic_ai_lab_bundle_v1_edge_entry));
  descriptor.evidence_obligations = region(
      0u, 0u, (uint32_t)sizeof(agentic_ai_lab_bundle_v1_evidence_entry),
      (uint32_t)_Alignof(agentic_ai_lab_bundle_v1_evidence_entry));
  descriptor.metadata_bytes = region(0u, 0u, 1u, 1u);
  return descriptor;
}

int main(void) {
  aligned_arena arena;
  agentic_ai_lab_bundle_v1_component_entry components[4];
  agentic_ai_lab_bundle_v1_edge_entry edges[2];
  agentic_ai_lab_bundle_v1_evidence_entry evidence[2];
  agentic_ai_lab_bundle_v1_descriptor descriptor;
  uint8_t packed_descriptor[sizeof(agentic_ai_lab_bundle_v1_descriptor) +
                            _Alignof(agentic_ai_lab_bundle_v1_descriptor)];
  uint8_t *unaligned_descriptor = packed_descriptor;
  uint8_t original_arena_byte = 0u;
  uint32_t original_descriptor_flags = 0u;
  agentic_ai_lab_bundle_v1_arena *owned_arena = NULL;
  const agentic_ai_lab_bundle_v1_descriptor *owned_descriptor = NULL;
  const void *owned_data = NULL;
  uint64_t owned_bytes = 0u;
  agentic_ai_lab_bundle_v1_slice component_slice;
  const agentic_ai_lab_bundle_v1_component_entry *found = NULL;
  size_t index = 0u;

  memset(components, 0, sizeof(components));
  for (; index < 4u; ++index) {
    components[index].case_id = compact_id(index < 2u ? 10u : 20u);
    components[index].component_id = compact_id((uint64_t)(index % 2u) + 1u);
    components[index].object_id = compact_id(100u + (uint64_t)index);
    components[index].type_id = compact_id(200u);
    components[index].contract_id = compact_id(300u);
    components[index].role_id = compact_id(400u);
    components[index].capability_id = compact_id(500u);
    components[index].policy_id = compact_id(600u);
    components[index].strategy_id = compact_id(700u);
    components[index].adapter_id = compact_id(800u);
    components[index].projection_id = compact_id(900u);
    components[index].composition_order = (uint64_t)index;
    components[index].flags = AGENTIC_AI_LAB_BUNDLE_V1_COMPONENT_F_ENABLED;
  }

  descriptor = make_descriptor(components, 4u, &arena);
  if (((uintptr_t)unaligned_descriptor %
       _Alignof(agentic_ai_lab_bundle_v1_descriptor)) == 0u) {
    unaligned_descriptor += 1u;
  }
  memcpy(unaligned_descriptor, &descriptor, sizeof(descriptor));
  expect_status("valid descriptor",
                agentic_ai_lab_bundle_v1_validate(&descriptor, arena.bytes,
                                            sizeof(arena.bytes)),
                AGENTIC_AI_LAB_BUNDLE_V1_OK);
  expect_status("binary lookup",
                agentic_ai_lab_bundle_v1_find_component(
                    &descriptor, arena.bytes, compact_id(20u), compact_id(2u),
                    &found),
                AGENTIC_AI_LAB_BUNDLE_V1_OK);
  if (found == NULL || found->object_id.low != 103u ||
      (const uint8_t *)found < arena.bytes ||
      (const uint8_t *)found >= arena.bytes + sizeof(arena.bytes)) {
    fprintf(stderr, "binary lookup did not return an arena-backed row\n");
    failures += 1;
  }

  expect_status("packed descriptor length rejected",
                agentic_ai_lab_bundle_v1_arena_create_packed(
                    unaligned_descriptor, sizeof(descriptor) - 1u, arena.bytes,
                    sizeof(arena.bytes), &owned_arena),
                AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT);
  expect_status("packed descriptor null output rejected",
                agentic_ai_lab_bundle_v1_arena_create_packed(
                    unaligned_descriptor, sizeof(descriptor), arena.bytes,
                    sizeof(arena.bytes), NULL),
                AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT);
  expect_status("owned arena created",
                agentic_ai_lab_bundle_v1_arena_create_packed(
                    unaligned_descriptor, sizeof(descriptor), arena.bytes,
                    sizeof(arena.bytes), &owned_arena),
                AGENTIC_AI_LAB_BUNDLE_V1_OK);
  expect_status("owned arena view",
                agentic_ai_lab_bundle_v1_arena_view(
                    owned_arena, &owned_descriptor, &owned_data, &owned_bytes),
                AGENTIC_AI_LAB_BUNDLE_V1_OK);
  if (owned_descriptor == NULL || owned_data == NULL ||
      owned_data == arena.bytes || owned_bytes != sizeof(arena.bytes) ||
      ((uintptr_t)owned_data %
       AGENTIC_AI_LAB_BUNDLE_V1_RECOMMENDED_ARENA_ALIGNMENT) != 0u) {
    fprintf(stderr, "owned arena view did not preserve aligned ownership\n");
    failures += 1;
  }
  if (owned_descriptor != NULL && owned_data != NULL) {
    if (memcmp(owned_descriptor, &descriptor, sizeof(descriptor)) != 0) {
      fprintf(stderr, "owned descriptor did not preserve packed input\n");
      failures += 1;
    }
    original_descriptor_flags = owned_descriptor->flags;
    original_arena_byte = ((const uint8_t *)owned_data)[0];
    unaligned_descriptor[4] ^= UINT8_C(0xff);
    arena.bytes[0] ^= UINT8_C(0xff);
    if (owned_descriptor->flags != original_descriptor_flags ||
        ((const uint8_t *)owned_data)[0] != original_arena_byte) {
      fprintf(stderr, "owned arena changed with producer buffers\n");
      failures += 1;
    }
    arena.bytes[0] = original_arena_byte;
  }
  expect_status("owned arena incomplete view rejected",
                agentic_ai_lab_bundle_v1_arena_view(
                    owned_arena, NULL, &owned_data, &owned_bytes),
                AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT);
  memset(&component_slice, 0, sizeof(component_slice));
  expect_status("owned component slice",
                agentic_ai_lab_bundle_v1_arena_slice(
                    owned_arena, AGENTIC_AI_LAB_BUNDLE_V1_REGION_COMPONENTS,
                    &component_slice),
                AGENTIC_AI_LAB_BUNDLE_V1_OK);
  if (component_slice.data == NULL ||
      component_slice.length != sizeof(components) ||
      component_slice.stride != sizeof(components[0]) ||
      ((uintptr_t)component_slice.data % component_slice.alignment) != 0u) {
    fprintf(stderr, "owned component slice did not preserve region layout\n");
    failures += 1;
  }
  expect_status("unknown owned slice rejected",
                agentic_ai_lab_bundle_v1_arena_slice(owned_arena, UINT32_MAX,
                                               &component_slice),
                AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT);
  found = NULL;
  expect_status("owned binary lookup",
                agentic_ai_lab_bundle_v1_arena_find_component(
                    owned_arena, compact_id(20u), compact_id(2u), &found),
                AGENTIC_AI_LAB_BUNDLE_V1_OK);
  if (found == NULL || found->object_id.low != 103u ||
      (const uint8_t *)found < (const uint8_t *)owned_data ||
      (const uint8_t *)found >=
          (const uint8_t *)owned_data + owned_bytes) {
    fprintf(stderr, "owned lookup did not return a handle-backed row\n");
    failures += 1;
  }
  expect_status("owned arena retained",
                agentic_ai_lab_bundle_v1_arena_retain(owned_arena),
                AGENTIC_AI_LAB_BUNDLE_V1_OK);
  expect_status("null arena retain rejected",
                agentic_ai_lab_bundle_v1_arena_retain(NULL),
                AGENTIC_AI_LAB_BUNDLE_V1_INVALID_ARGUMENT);
  agentic_ai_lab_bundle_v1_arena_release(NULL);
  agentic_ai_lab_bundle_v1_arena_release(owned_arena);
  agentic_ai_lab_bundle_v1_arena_release(owned_arena);
  owned_arena = NULL;

  found = NULL;
  expect_status("missing component",
                agentic_ai_lab_bundle_v1_find_component(
                    &descriptor, arena.bytes, compact_id(20u), compact_id(99u),
                    &found),
                AGENTIC_AI_LAB_BUNDLE_V1_NOT_FOUND);

  descriptor.schema_major = 0u;
  expect_status("draft schema rejected",
                agentic_ai_lab_bundle_v1_validate(&descriptor, arena.bytes,
                                            sizeof(arena.bytes)),
                AGENTIC_AI_LAB_BUNDLE_V1_INCOMPATIBLE_SCHEMA);
  descriptor.schema_major = AGENTIC_AI_LAB_BUNDLE_V1_SCHEMA_MAJOR;

  descriptor.components.length = sizeof(arena.bytes);
  expect_status("out of bounds rejected",
                agentic_ai_lab_bundle_v1_validate(&descriptor, arena.bytes,
                                            sizeof(arena.bytes)),
                AGENTIC_AI_LAB_BUNDLE_V1_REGION_BOUNDS);
  descriptor = make_descriptor(components, 4u, &arena);

  components[1].component_id = compact_id(0u);
  descriptor = make_descriptor(components, 4u, &arena);
  expect_status("unsorted table rejected",
                agentic_ai_lab_bundle_v1_validate(&descriptor, arena.bytes,
                                            sizeof(arena.bytes)),
                AGENTIC_AI_LAB_BUNDLE_V1_UNSORTED_TABLE);

  components[1].component_id = compact_id(2u);
  descriptor = make_descriptor(components, 4u, &arena);
  descriptor.reserved[3] = 1u;
  expect_status("reserved data rejected",
                agentic_ai_lab_bundle_v1_validate(&descriptor, arena.bytes,
                                            sizeof(arena.bytes)),
                AGENTIC_AI_LAB_BUNDLE_V1_MALFORMED_DESCRIPTOR);

  descriptor = make_descriptor(components, 4u, &arena);
  memset(edges, 0, sizeof(edges));
  edges[0].case_id = compact_id(10u);
  edges[0].source_component_id = compact_id(1u);
  edges[0].target_component_id = compact_id(2u);
  edges[0].relation_id = compact_id(3u);
  edges[1] = edges[0];
  memcpy(&arena.bytes[1024], edges, sizeof(edges));
  descriptor.edges = region(
      1024u, sizeof(edges), (uint32_t)sizeof(agentic_ai_lab_bundle_v1_edge_entry),
      (uint32_t)_Alignof(agentic_ai_lab_bundle_v1_edge_entry));
  expect_status("duplicate edge rejected",
                agentic_ai_lab_bundle_v1_validate(&descriptor, arena.bytes,
                                            sizeof(arena.bytes)),
                AGENTIC_AI_LAB_BUNDLE_V1_DUPLICATE_KEY);

  descriptor = make_descriptor(components, 4u, &arena);
  memset(evidence, 0, sizeof(evidence));
  evidence[0].case_id = compact_id(10u);
  evidence[0].obligation_id = compact_id(2u);
  evidence[1].case_id = compact_id(10u);
  evidence[1].obligation_id = compact_id(1u);
  memcpy(&arena.bytes[1280], evidence, sizeof(evidence));
  descriptor.evidence_obligations = region(
      1280u, sizeof(evidence),
      (uint32_t)sizeof(agentic_ai_lab_bundle_v1_evidence_entry),
      (uint32_t)_Alignof(agentic_ai_lab_bundle_v1_evidence_entry));
  expect_status("unsorted evidence rejected",
                agentic_ai_lab_bundle_v1_validate(&descriptor, arena.bytes,
                                            sizeof(arena.bytes)),
                AGENTIC_AI_LAB_BUNDLE_V1_UNSORTED_TABLE);

  if (failures != 0) {
    return 1;
  }
  printf("schema=agentic-ai-lab.bundle-v1.harness.1\n");
  printf("layout=typed-native-regions\n");
  printf("lookup=binary-search\n");
  printf("payload-zero-copy=true\n");
  printf("arena-lifetime=reference-counted\n");
  printf("slice-view=immutable\n");
  printf("packed-byte-order=little-endian\n");
  printf("json-in-hot-path=false\n");
  return 0;
}
