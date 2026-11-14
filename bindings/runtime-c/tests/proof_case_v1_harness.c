// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include <agentic_ai_lab/proof_case_v1.h>

#include <stdio.h>
#include <string.h>

static const uint8_t k_schema_fingerprint[32] =
    AGENTIC_AI_LAB_PROOF_CASE_SCHEMA_FINGERPRINT_BYTES;

static void write_u32_le(uint8_t *bytes, uint32_t value) {
  bytes[0] = (uint8_t)value;
  bytes[1] = (uint8_t)(value >> 8u);
  bytes[2] = (uint8_t)(value >> 16u);
  bytes[3] = (uint8_t)(value >> 24u);
}

static void write_u64_le(uint8_t *bytes, uint64_t value) {
  size_t index = 0u;
  for (; index < 8u; ++index) {
    bytes[index] = (uint8_t)(value >> (index * 8u));
  }
}

static void make_vector(uint8_t *vector) {
  memset(vector, 0, AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_ABI_VERSION_OFFSET,
               AGENTIC_AI_LAB_PROOF_CASE_VECTOR_VERSION);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_CASE_KIND_OFFSET,
               AGENTIC_AI_LAB_PROOF_CASE_KIND_AUTHORIZED_EFFECT_TOKEN);
  memcpy(vector + AGENTIC_AI_LAB_PROOF_FIELD_SCHEMA_FINGERPRINT_OFFSET,
         k_schema_fingerprint, sizeof(k_schema_fingerprint));
  write_u64_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_REQUIRED_OBLIGATION_MASK_OFFSET,
               AGENTIC_AI_LAB_PROOF_REQUIRED_OBLIGATION_MASK);
  write_u64_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_PRESENT_OBLIGATION_MASK_OFFSET,
               AGENTIC_AI_LAB_PROOF_REQUIRED_OBLIGATION_MASK);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_OBLIGATION_COUNT_OFFSET, 8u);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_MEDIATION_OUTCOME_OFFSET,
               AGENTIC_AI_LAB_PROOF_MEDIATION_ALLOW);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_DURABILITY_PROFILE_OFFSET,
               AGENTIC_AI_LAB_PROOF_DURABILITY_STRICT);
}

static int expect_status(const char *label, agentic_ai_lab_proof_status actual,
                         agentic_ai_lab_proof_status expected) {
  if (actual == expected) {
    return 0;
  }
  fprintf(stderr, "%s: expected %s, got %s\n", label,
          agentic_ai_lab_proof_status_name(expected),
          agentic_ai_lab_proof_status_name(actual));
  return 1;
}

int main(void) {
  uint8_t vector[AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE];
  uint8_t output[AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE];
  uint8_t guard[AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE];
  agentic_ai_lab_proof_case_handle handle = {0};
  agentic_ai_lab_proof_case_layout layout = {0};
  size_t written = 0u;

  make_vector(vector);
  if (expect_status("null-vector",
                    agentic_ai_lab_proof_case_init(NULL, sizeof(vector), &handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_INVALID_ARGUMENT) != 0 ||
      expect_status("null-output-handle",
                    agentic_ai_lab_proof_case_init(vector, sizeof(vector), NULL),
                    AGENTIC_AI_LAB_PROOF_STATUS_INVALID_ARGUMENT) != 0) {
    return 1;
  }
  if (expect_status("init",
                    agentic_ai_lab_proof_case_init(vector, sizeof(vector), &handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_OK) != 0 ||
      expect_status("measure", agentic_ai_lab_proof_case_measure(&handle, &layout),
                    AGENTIC_AI_LAB_PROOF_STATUS_OK) != 0) {
    return 1;
  }
  if (layout.required_size != sizeof(vector) ||
      layout.alignment != AGENTIC_AI_LAB_PROOF_CASE_VECTOR_ALIGNMENT ||
      layout.abi_version != AGENTIC_AI_LAB_PROOF_CASE_VECTOR_VERSION ||
      memcmp(layout.schema_fingerprint, k_schema_fingerprint,
             sizeof(k_schema_fingerprint)) != 0) {
    fprintf(stderr, "measure returned the wrong layout\n");
    return 1;
  }

  memset(guard, 0xa5, sizeof(guard));
  if (expect_status("small-buffer",
                    agentic_ai_lab_proof_case_write(&handle, guard,
                                              sizeof(guard) - 1u, &written),
                    AGENTIC_AI_LAB_PROOF_STATUS_BUFFER_TOO_SMALL) != 0 ||
      written != sizeof(vector) || guard[0] != 0xa5u) {
    fprintf(stderr, "small-buffer write was not atomic\n");
    return 1;
  }
  if (expect_status("write",
                    agentic_ai_lab_proof_case_write(&handle, output, sizeof(output),
                                              &written),
                    AGENTIC_AI_LAB_PROOF_STATUS_OK) != 0 ||
      written != sizeof(vector) || memcmp(output, vector, sizeof(vector)) != 0) {
    fprintf(stderr, "bulk write did not preserve the vector\n");
    return 1;
  }
  if (expect_status("release", agentic_ai_lab_proof_case_release(&handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_OK) != 0 ||
      expect_status("stale", agentic_ai_lab_proof_case_measure(&handle, &layout),
                    AGENTIC_AI_LAB_PROOF_STATUS_STALE_HANDLE) != 0 ||
      expect_status("double-release", agentic_ai_lab_proof_case_release(&handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_STALE_HANDLE) != 0) {
    return 1;
  }

  make_vector(vector);
  vector[AGENTIC_AI_LAB_PROOF_FIELD_SCHEMA_FINGERPRINT_OFFSET] ^= 1u;
  if (expect_status("schema-mismatch",
                    agentic_ai_lab_proof_case_init(vector, sizeof(vector), &handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_SCHEMA_MISMATCH) != 0) {
    return 1;
  }
  make_vector(vector);
  write_u64_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_REQUIRED_OBLIGATION_MASK_OFFSET,
               UINT64_C(0x1ff));
  if (expect_status("unsupported-obligation",
                    agentic_ai_lab_proof_case_init(vector, sizeof(vector), &handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_UNSUPPORTED_OBLIGATION) != 0) {
    return 1;
  }
  make_vector(vector);
  write_u64_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_PRESENT_OBLIGATION_MASK_OFFSET,
               UINT64_C(0x1ff));
  if (expect_status("unsupported-present-obligation",
                    agentic_ai_lab_proof_case_init(vector, sizeof(vector), &handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_UNSUPPORTED_OBLIGATION) != 0) {
    return 1;
  }
  make_vector(vector);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_OBLIGATION_COUNT_OFFSET, 9u);
  if (expect_status("obligation-count",
                    agentic_ai_lab_proof_case_init(vector, sizeof(vector), &handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_MALFORMED_EVIDENCE) != 0) {
    return 1;
  }
  make_vector(vector);
  vector[AGENTIC_AI_LAB_PROOF_FIELD_RESERVED_OFFSET] = 1u;
  if (expect_status("reserved-byte",
                    agentic_ai_lab_proof_case_init(vector, sizeof(vector), &handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_MALFORMED_EVIDENCE) != 0) {
    return 1;
  }
  make_vector(vector);
  if (expect_status("truncated",
                    agentic_ai_lab_proof_case_init(vector, sizeof(vector) - 1u,
                                             &handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_MALFORMED_EVIDENCE) != 0) {
    return 1;
  }

  make_vector(vector);
  if (expect_status("toctou-init",
                    agentic_ai_lab_proof_case_init(vector, sizeof(vector), &handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_OK) != 0) {
    return 1;
  }
  vector[AGENTIC_AI_LAB_PROOF_FIELD_RESERVED_OFFSET + 11u] = 1u;
  if (expect_status("toctou-measure",
                    agentic_ai_lab_proof_case_measure(&handle, &layout),
                    AGENTIC_AI_LAB_PROOF_STATUS_MALFORMED_EVIDENCE) != 0 ||
      expect_status("toctou-release", agentic_ai_lab_proof_case_release(&handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_OK) != 0) {
    return 1;
  }

  make_vector(vector);
  if (expect_status("toctou-write-init",
                    agentic_ai_lab_proof_case_init(vector, sizeof(vector), &handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_OK) != 0) {
    return 1;
  }
  vector[AGENTIC_AI_LAB_PROOF_FIELD_SCHEMA_FINGERPRINT_OFFSET + 31u] ^= 1u;
  memset(guard, 0xa5, sizeof(guard));
  written = sizeof(vector);
  if (expect_status("toctou-write",
                    agentic_ai_lab_proof_case_write(&handle, guard, sizeof(guard),
                                              &written),
                    AGENTIC_AI_LAB_PROOF_STATUS_SCHEMA_MISMATCH) != 0 ||
      written != 0u || guard[0] != 0xa5u ||
      expect_status("toctou-write-release",
                    agentic_ai_lab_proof_case_release(&handle),
                    AGENTIC_AI_LAB_PROOF_STATUS_OK) != 0) {
    fprintf(stderr, "TOCTOU write was not fail-closed and atomic\n");
    return 1;
  }

  puts("proof-case-v1: ok");
  return 0;
}
