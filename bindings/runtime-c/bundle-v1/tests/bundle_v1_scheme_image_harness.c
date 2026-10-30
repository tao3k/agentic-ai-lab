// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include "agentic_ai_lab/bundle_v1.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int read_file(const char *path, void **out_data, uint64_t *out_length) {
  FILE *file = NULL;
  long length = 0;
  void *data = NULL;
  size_t read_length = 0u;
  if (path == NULL || out_data == NULL || out_length == NULL) {
    return 0;
  }
  *out_data = NULL;
  *out_length = 0u;
  file = fopen(path, "rb");
  if (file == NULL || fseek(file, 0L, SEEK_END) != 0) {
    if (file != NULL) {
      fclose(file);
    }
    return 0;
  }
  length = ftell(file);
  if (length <= 0L || (uintmax_t)length > (uintmax_t)SIZE_MAX ||
      fseek(file, 0L, SEEK_SET) != 0) {
    fclose(file);
    return 0;
  }
  data = malloc((size_t)length);
  if (data == NULL) {
    fclose(file);
    return 0;
  }
  read_length = fread(data, 1u, (size_t)length, file);
  fclose(file);
  if (read_length != (size_t)length) {
    free(data);
    return 0;
  }
  *out_data = data;
  *out_length = (uint64_t)length;
  return 1;
}

int main(int argc, char **argv) {
  void *descriptor_image = NULL;
  void *arena_image = NULL;
  uint64_t descriptor_length = 0u;
  uint64_t arena_length = 0u;
  agentic_ai_lab_bundle_v1_arena *arena = NULL;
  const agentic_ai_lab_bundle_v1_descriptor *descriptor = NULL;
  const void *data = NULL;
  uint64_t data_length = 0u;
  agentic_ai_lab_bundle_v1_slice symbols = {0};
  agentic_ai_lab_bundle_v1_slice metadata = {0};
  agentic_ai_lab_bundle_v1_slice components = {0};
  const agentic_ai_lab_bundle_v1_symbol_entry *first_symbol = NULL;
  const agentic_ai_lab_bundle_v1_component_entry *first = NULL;
  const agentic_ai_lab_bundle_v1_component_entry *found = NULL;
  agentic_ai_lab_bundle_v1_status status = AGENTIC_AI_LAB_BUNDLE_V1_OK;
  int result = 1;

  if (argc != 3) {
    fprintf(stderr, "usage: %s DESCRIPTOR ARENA\n", argv[0]);
    return 2;
  }
  if (!read_file(argv[1], &descriptor_image, &descriptor_length) ||
      !read_file(argv[2], &arena_image, &arena_length)) {
    fprintf(stderr, "failed to read Scheme Bundle v1 images\n");
    goto cleanup;
  }
  status = agentic_ai_lab_bundle_v1_arena_create_packed(
      descriptor_image, descriptor_length, arena_image, arena_length, &arena);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK) {
    fprintf(stderr, "packed image rejected: %s\n",
            agentic_ai_lab_bundle_v1_status_name(status));
    goto cleanup;
  }
  status = agentic_ai_lab_bundle_v1_arena_view(arena, &descriptor, &data,
                                         &data_length);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK || descriptor == NULL || data == NULL ||
      data == arena_image || data_length != arena_length ||
      ((uintptr_t)data % AGENTIC_AI_LAB_BUNDLE_V1_RECOMMENDED_ARENA_ALIGNMENT) != 0u) {
    fprintf(stderr, "C-owned arena view is invalid\n");
    goto cleanup;
  }
  status = agentic_ai_lab_bundle_v1_arena_slice(
      arena, AGENTIC_AI_LAB_BUNDLE_V1_REGION_SYMBOLS, &symbols);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK ||
      symbols.length != 2u * sizeof(agentic_ai_lab_bundle_v1_symbol_entry) ||
      symbols.stride != sizeof(agentic_ai_lab_bundle_v1_symbol_entry)) {
    fprintf(stderr, "Scheme symbol slice is invalid\n");
    goto cleanup;
  }
  status = agentic_ai_lab_bundle_v1_arena_slice(
      arena, AGENTIC_AI_LAB_BUNDLE_V1_REGION_METADATA_BYTES, &metadata);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK || metadata.length != 22u ||
      metadata.stride != 1u) {
    fprintf(stderr, "Scheme metadata slice is invalid\n");
    goto cleanup;
  }
  first_symbol = (const agentic_ai_lab_bundle_v1_symbol_entry *)symbols.data;
  if (first_symbol->byte_length != 11u || first_symbol->symbol_kind != 1u ||
      first_symbol->flags != 0u ||
      ((const unsigned char *)metadata.data)[first_symbol->byte_offset] !=
          (unsigned char)'C') {
    fprintf(stderr, "Scheme symbol metadata is invalid\n");
    goto cleanup;
  }
  status = agentic_ai_lab_bundle_v1_arena_slice(
      arena, AGENTIC_AI_LAB_BUNDLE_V1_REGION_COMPONENTS, &components);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK || components.length == 0u ||
      components.stride != sizeof(agentic_ai_lab_bundle_v1_component_entry)) {
    fprintf(stderr, "Scheme component slice is invalid\n");
    goto cleanup;
  }
  first = (const agentic_ai_lab_bundle_v1_component_entry *)components.data;
  status = agentic_ai_lab_bundle_v1_arena_find_component(
      arena, first->case_id, first->component_id, &found);
  if (status != AGENTIC_AI_LAB_BUNDLE_V1_OK || found != first) {
    fprintf(stderr, "handle-backed component lookup failed\n");
    goto cleanup;
  }

  printf("schema=agentic-ai-lab.bundle-v1.scheme-c-bridge.1\n");
  printf("scheme-descriptor-accepted=true\n");
  printf("c-owned-alignment=%u\n",
         AGENTIC_AI_LAB_BUNDLE_V1_RECOMMENDED_ARENA_ALIGNMENT);
  printf("component-lookup=binary-search\n");
  printf("symbol-metadata=utf8\n");
  printf("json-in-hot-path=false\n");
  result = 0;

cleanup:
  agentic_ai_lab_bundle_v1_arena_release(arena);
  free(arena_image);
  free(descriptor_image);
  return result;
}
