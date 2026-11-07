// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include <agentic_ai_lab/proof_case_v1.h>

#include <string.h>

static const uint8_t k_fingerprint[32] =
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

int main(void) {
  uint8_t vector[AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE] = {0};
  uint8_t output[AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE] = {0};
  agentic_ai_lab_proof_case_handle handle = {0};
  size_t written = 0u;

  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_ABI_VERSION_OFFSET,
               AGENTIC_AI_LAB_PROOF_CASE_VECTOR_VERSION);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_CASE_KIND_OFFSET,
               AGENTIC_AI_LAB_PROOF_CASE_KIND_AUTHORIZED_EFFECT_TOKEN);
  memcpy(vector + AGENTIC_AI_LAB_PROOF_FIELD_SCHEMA_FINGERPRINT_OFFSET, k_fingerprint,
         sizeof(k_fingerprint));
  write_u64_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_REQUIRED_OBLIGATION_MASK_OFFSET,
               AGENTIC_AI_LAB_PROOF_REQUIRED_OBLIGATION_MASK);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_MEDIATION_OUTCOME_OFFSET,
               AGENTIC_AI_LAB_PROOF_MEDIATION_ALLOW);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_DURABILITY_PROFILE_OFFSET,
               AGENTIC_AI_LAB_PROOF_DURABILITY_STRICT);

  if (agentic_ai_lab_proof_case_init(vector, sizeof(vector), &handle) !=
          AGENTIC_AI_LAB_PROOF_STATUS_OK ||
      agentic_ai_lab_proof_case_write(&handle, output, sizeof(output), &written) !=
          AGENTIC_AI_LAB_PROOF_STATUS_OK ||
      written != sizeof(vector) || memcmp(vector, output, sizeof(vector)) != 0 ||
      agentic_ai_lab_proof_case_release(&handle) != AGENTIC_AI_LAB_PROOF_STATUS_OK) {
    return 1;
  }
  return 0;
}
