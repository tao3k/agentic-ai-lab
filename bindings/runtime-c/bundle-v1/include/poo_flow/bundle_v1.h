// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#ifndef POO_FLOW_BUNDLE_V1_H
#define POO_FLOW_BUNDLE_V1_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define POO_FLOW_BUNDLE_V1_SCHEMA "yuanxu.bundle.1"
#define POO_FLOW_BUNDLE_V1_SCHEMA_MAJOR 1u
#define POO_FLOW_BUNDLE_V1_SCHEMA_MINOR 0u
#define POO_FLOW_BUNDLE_V1_DIGEST_BYTES 32u
#define POO_FLOW_BUNDLE_V1_RECOMMENDED_ARENA_ALIGNMENT 64u

#define POO_FLOW_BUNDLE_V1_DESCRIPTOR_F_SORTED UINT32_C(1)
#define POO_FLOW_BUNDLE_V1_DESCRIPTOR_F_ZERO_COPY UINT32_C(2)
#define POO_FLOW_BUNDLE_V1_DESCRIPTOR_KNOWN_FLAGS \
  (POO_FLOW_BUNDLE_V1_DESCRIPTOR_F_SORTED |       \
   POO_FLOW_BUNDLE_V1_DESCRIPTOR_F_ZERO_COPY)

#define POO_FLOW_BUNDLE_V1_COMPONENT_F_ENABLED UINT32_C(1)
#define POO_FLOW_BUNDLE_V1_COMPONENT_KNOWN_FLAGS \
  POO_FLOW_BUNDLE_V1_COMPONENT_F_ENABLED

typedef uint32_t poo_flow_bundle_v1_status;

enum {
  POO_FLOW_BUNDLE_V1_OK = 0,
  POO_FLOW_BUNDLE_V1_INVALID_ARGUMENT = 1,
  POO_FLOW_BUNDLE_V1_INCOMPATIBLE_SCHEMA = 2,
  POO_FLOW_BUNDLE_V1_MALFORMED_DESCRIPTOR = 3,
  POO_FLOW_BUNDLE_V1_REGION_BOUNDS = 4,
  POO_FLOW_BUNDLE_V1_REGION_LAYOUT = 5,
  POO_FLOW_BUNDLE_V1_UNSORTED_TABLE = 6,
  POO_FLOW_BUNDLE_V1_DUPLICATE_KEY = 7,
  POO_FLOW_BUNDLE_V1_NOT_FOUND = 8,
  POO_FLOW_BUNDLE_V1_OUT_OF_MEMORY = 9,
  POO_FLOW_BUNDLE_V1_REFERENCE_LIMIT = 10,
  POO_FLOW_BUNDLE_V1_UNSUPPORTED_ENDIAN = 11
};

typedef struct poo_flow_bundle_v1_compact_id {
  uint64_t high;
  uint64_t low;
} poo_flow_bundle_v1_compact_id;

/*
 * A region is an offset inside one registered, immutable foreign arena.
 * It never contains a Scheme, Python, Rust, or JavaScript heap pointer.
 */
typedef struct poo_flow_bundle_v1_region {
  uint64_t offset;
  uint64_t length;
  uint32_t stride;
  uint32_t alignment;
} poo_flow_bundle_v1_region;

typedef struct poo_flow_bundle_v1_symbol_entry {
  poo_flow_bundle_v1_compact_id symbol_id;
  uint64_t byte_offset;
  uint32_t byte_length;
  uint16_t symbol_kind;
  uint16_t flags;
} poo_flow_bundle_v1_symbol_entry;

/*
 * This row is the native projection of one composed Domain Case component.
 * Keeping the identity columns fixed makes multi-agent lookup independent of
 * any downstream language object model.
 */
typedef struct poo_flow_bundle_v1_component_entry {
  poo_flow_bundle_v1_compact_id case_id;
  poo_flow_bundle_v1_compact_id component_id;
  poo_flow_bundle_v1_compact_id object_id;
  poo_flow_bundle_v1_compact_id type_id;
  poo_flow_bundle_v1_compact_id contract_id;
  poo_flow_bundle_v1_compact_id role_id;
  poo_flow_bundle_v1_compact_id capability_id;
  poo_flow_bundle_v1_compact_id policy_id;
  poo_flow_bundle_v1_compact_id strategy_id;
  poo_flow_bundle_v1_compact_id adapter_id;
  poo_flow_bundle_v1_compact_id projection_id;
  uint64_t composition_order;
  uint32_t flags;
  uint32_t reserved0;
  uint64_t reserved1;
} poo_flow_bundle_v1_component_entry;

typedef struct poo_flow_bundle_v1_edge_entry {
  poo_flow_bundle_v1_compact_id case_id;
  poo_flow_bundle_v1_compact_id source_component_id;
  poo_flow_bundle_v1_compact_id target_component_id;
  poo_flow_bundle_v1_compact_id relation_id;
  uint64_t composition_order;
  uint32_t flags;
  uint32_t reserved0;
} poo_flow_bundle_v1_edge_entry;

typedef struct poo_flow_bundle_v1_evidence_entry {
  poo_flow_bundle_v1_compact_id case_id;
  poo_flow_bundle_v1_compact_id obligation_id;
  poo_flow_bundle_v1_compact_id contract_id;
  poo_flow_bundle_v1_compact_id evidence_type_id;
  poo_flow_bundle_v1_compact_id proof_system_id;
  uint64_t composition_order;
  uint32_t flags;
  uint32_t reserved0;
} poo_flow_bundle_v1_evidence_entry;

/*
 * Descriptor fields contain no owning pointer. The caller keeps the foreign
 * arena alive until the consuming runtime releases its registered arena
 * handle. All table regions are immutable for that interval.
 */
typedef struct poo_flow_bundle_v1_descriptor {
  uint32_t struct_size;
  uint32_t flags;
  uint16_t schema_major;
  uint16_t schema_minor;
  uint32_t reserved0;
  poo_flow_bundle_v1_compact_id bundle_id;
  uint8_t digest[POO_FLOW_BUNDLE_V1_DIGEST_BYTES];
  uint64_t bundle_epoch;
  uint64_t arena_bytes;
  poo_flow_bundle_v1_region symbols;
  poo_flow_bundle_v1_region components;
  poo_flow_bundle_v1_region edges;
  poo_flow_bundle_v1_region evidence_obligations;
  poo_flow_bundle_v1_region metadata_bytes;
  uint64_t reserved[7];
} poo_flow_bundle_v1_descriptor;

typedef uint32_t poo_flow_bundle_v1_region_kind;

enum {
  POO_FLOW_BUNDLE_V1_REGION_SYMBOLS = 1,
  POO_FLOW_BUNDLE_V1_REGION_COMPONENTS = 2,
  POO_FLOW_BUNDLE_V1_REGION_EDGES = 3,
  POO_FLOW_BUNDLE_V1_REGION_EVIDENCE_OBLIGATIONS = 4,
  POO_FLOW_BUNDLE_V1_REGION_METADATA_BYTES = 5
};

/*
 * A slice borrows immutable storage from an arena handle. Its data pointer is
 * valid until the caller releases the reference that protects the handle.
 */
typedef struct poo_flow_bundle_v1_slice {
  const void *data;
  uint64_t length;
  uint32_t stride;
  uint32_t alignment;
} poo_flow_bundle_v1_slice;

typedef struct poo_flow_bundle_v1_arena poo_flow_bundle_v1_arena;

#ifdef __cplusplus
#define POO_FLOW_BUNDLE_V1_STATIC_ASSERT static_assert
#else
#define POO_FLOW_BUNDLE_V1_STATIC_ASSERT _Static_assert
#endif

POO_FLOW_BUNDLE_V1_STATIC_ASSERT(sizeof(poo_flow_bundle_v1_compact_id) == 16,
                                 "Bundle v1 compact id layout changed");
POO_FLOW_BUNDLE_V1_STATIC_ASSERT(sizeof(poo_flow_bundle_v1_region) == 24,
                                 "Bundle v1 region layout changed");
POO_FLOW_BUNDLE_V1_STATIC_ASSERT(sizeof(poo_flow_bundle_v1_symbol_entry) == 32,
                                 "Bundle v1 symbol layout changed");
POO_FLOW_BUNDLE_V1_STATIC_ASSERT(
    sizeof(poo_flow_bundle_v1_component_entry) == 200,
    "Bundle v1 component layout changed");
POO_FLOW_BUNDLE_V1_STATIC_ASSERT(sizeof(poo_flow_bundle_v1_edge_entry) == 80,
                                 "Bundle v1 edge layout changed");
POO_FLOW_BUNDLE_V1_STATIC_ASSERT(sizeof(poo_flow_bundle_v1_evidence_entry) == 96,
                                 "Bundle v1 evidence layout changed");
POO_FLOW_BUNDLE_V1_STATIC_ASSERT(sizeof(poo_flow_bundle_v1_descriptor) == 256,
                                 "Bundle v1 descriptor layout changed");
POO_FLOW_BUNDLE_V1_STATIC_ASSERT(sizeof(poo_flow_bundle_v1_slice) == 24,
                                 "Bundle v1 slice layout changed");

#undef POO_FLOW_BUNDLE_V1_STATIC_ASSERT

poo_flow_bundle_v1_status poo_flow_bundle_v1_validate(
    const poo_flow_bundle_v1_descriptor *descriptor,
    const void *arena,
    uint64_t arena_bytes);

poo_flow_bundle_v1_status poo_flow_bundle_v1_find_component(
    const poo_flow_bundle_v1_descriptor *descriptor,
    const void *arena,
    poo_flow_bundle_v1_compact_id case_id,
    poo_flow_bundle_v1_compact_id component_id,
    const poo_flow_bundle_v1_component_entry **out_component);

/*
 * Create one C-owned immutable arena. The descriptor and payload are copied
 * once at the ABI boundary, validated, and retained in 64-byte-aligned native
 * storage. Runtime slice and lookup operations are zero-copy thereafter.
 */
poo_flow_bundle_v1_status poo_flow_bundle_v1_arena_create(
    const poo_flow_bundle_v1_descriptor *descriptor,
    const void *arena,
    uint64_t arena_bytes,
    poo_flow_bundle_v1_arena **out_arena);

/*
 * Safe entry point for Scheme/Python CFFI buffers whose descriptor alignment
 * is not guaranteed. Packed descriptors use the canonical little-endian byte
 * order. descriptor_bytes must equal the Bundle v1 descriptor size; the
 * implementation copies through an aligned native descriptor.
 */
poo_flow_bundle_v1_status poo_flow_bundle_v1_arena_create_packed(
    const void *descriptor_bytes,
    uint64_t descriptor_length,
    const void *arena,
    uint64_t arena_bytes,
    poo_flow_bundle_v1_arena **out_arena);

poo_flow_bundle_v1_status poo_flow_bundle_v1_arena_retain(
    poo_flow_bundle_v1_arena *arena);

void poo_flow_bundle_v1_arena_release(poo_flow_bundle_v1_arena *arena);

poo_flow_bundle_v1_status poo_flow_bundle_v1_arena_view(
    const poo_flow_bundle_v1_arena *arena,
    const poo_flow_bundle_v1_descriptor **out_descriptor,
    const void **out_data,
    uint64_t *out_bytes);

poo_flow_bundle_v1_status poo_flow_bundle_v1_arena_slice(
    const poo_flow_bundle_v1_arena *arena,
    poo_flow_bundle_v1_region_kind region_kind,
    poo_flow_bundle_v1_slice *out_slice);

poo_flow_bundle_v1_status poo_flow_bundle_v1_arena_find_component(
    const poo_flow_bundle_v1_arena *arena,
    poo_flow_bundle_v1_compact_id case_id,
    poo_flow_bundle_v1_compact_id component_id,
    const poo_flow_bundle_v1_component_entry **out_component);

const char *poo_flow_bundle_v1_status_name(poo_flow_bundle_v1_status status);

#ifdef __cplusplus
}
#endif

#endif
