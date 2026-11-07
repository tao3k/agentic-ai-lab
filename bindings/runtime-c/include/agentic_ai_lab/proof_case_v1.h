// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#ifndef AGENTIC_AI_LAB_PROOF_CASE_V1_H
#define AGENTIC_AI_LAB_PROOF_CASE_V1_H

#include <stddef.h>
#include <stdint.h>

#include <agentic_ai_lab/proof_case_vector_v1.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef uint32_t agentic_ai_lab_proof_status;

enum {
  AGENTIC_AI_LAB_PROOF_STATUS_OK = 0u,
  AGENTIC_AI_LAB_PROOF_STATUS_INVALID_ARGUMENT = 1u,
  AGENTIC_AI_LAB_PROOF_STATUS_BUFFER_TOO_SMALL = 2u,
  AGENTIC_AI_LAB_PROOF_STATUS_STALE_HANDLE = 3u,
  AGENTIC_AI_LAB_PROOF_STATUS_SCHEMA_MISMATCH = 4u,
  AGENTIC_AI_LAB_PROOF_STATUS_MALFORMED_EVIDENCE = 5u,
  AGENTIC_AI_LAB_PROOF_STATUS_UNSUPPORTED_OBLIGATION = 6u
};

typedef struct {
  const uint8_t *data;
  size_t size;
  uint64_t generation;
} agentic_ai_lab_proof_case_handle;

typedef struct {
  size_t required_size;
  size_t alignment;
  uint32_t abi_version;
  uint8_t schema_fingerprint[32];
} agentic_ai_lab_proof_case_layout;

/* The vector is borrowed and must outlive the handle. No allocation occurs. */
agentic_ai_lab_proof_status agentic_ai_lab_proof_case_init(
    const void *vector, size_t vector_size, agentic_ai_lab_proof_case_handle *out_handle);

agentic_ai_lab_proof_status agentic_ai_lab_proof_case_release(
    agentic_ai_lab_proof_case_handle *handle);

agentic_ai_lab_proof_status agentic_ai_lab_proof_case_measure(
    const agentic_ai_lab_proof_case_handle *handle,
    agentic_ai_lab_proof_case_layout *out_layout);

/* On BUFFER_TOO_SMALL, written reports the required size and buffer is untouched. */
agentic_ai_lab_proof_status agentic_ai_lab_proof_case_write(
    const agentic_ai_lab_proof_case_handle *handle, void *buffer, size_t capacity,
    size_t *written);

const char *agentic_ai_lab_proof_status_name(agentic_ai_lab_proof_status status);

#ifdef __cplusplus
}
#endif

#endif
