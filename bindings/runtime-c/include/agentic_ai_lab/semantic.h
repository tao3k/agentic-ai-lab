/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later */
#ifndef AGENTIC_AI_LAB_SEMANTIC_H
#define AGENTIC_AI_LAB_SEMANTIC_H
#include <stdint.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct { int32_t status; uint8_t *data; size_t length; } agentic_ai_lab_semantic_result;
/* ABI 1: bounded inert Scheme datum bytes; see semantic-wire.org.
 * No legacy JSON entry symbols are exported.
 * One process-global, thread-affine AOT instance. Closing is terminal.
 * No Gambit objects cross this ABI. Input is borrowed for the call. Result is
 * initialized empty by the caller and released only with result_release.
 * Operation is a NUL-terminated UTF-8 string of at most 128 bytes. The caller
 * provides valid readable pointers for their declared sizes. */
int32_t agentic_ai_lab_semantic_v1_open(void);
int32_t agentic_ai_lab_semantic_v1_call(const char *operation, const uint8_t *input,
                                size_t length, agentic_ai_lab_semantic_result *result);
/* Trusted host control lane. Register a pinned source snapshot; never expose
 * this function as a model tool. Same owner/lifetime/input/result rules apply.
 * This validates local snapshot fidelity, not external issuer signatures. */
int32_t agentic_ai_lab_semantic_v1_source_register(const uint8_t *input, size_t length,
                                           agentic_ai_lab_semantic_result *result);
/* Trusted Context contract/purpose registration. Native current Source and the
 * existing policy Host clock determine use eligibility; no external effect grant. */
int32_t agentic_ai_lab_semantic_v1_context_use_refresh(const uint8_t *input, size_t length,
                                               agentic_ai_lab_semantic_result *result);
/* Trusted host policy/observed-clock registration. Ordinary semantic calls
 * cannot access this control lane. No provider authentication or effect grant. */
int32_t agentic_ai_lab_semantic_v1_policy_refresh(const uint8_t *input, size_t length,
                                         agentic_ai_lab_semantic_result *result);
/* Trusted original-owner lineage projection. Scheme recomputes positive proof,
 * Rule/direct Derivation correspondence and exact Temporal source bindings.
 * Source-relative only; this never grants an external effect or publication. */
int32_t agentic_ai_lab_semantic_v1_proof_state_refresh(const uint8_t *input, size_t length,
                                              agentic_ai_lab_semantic_result *result);
int32_t agentic_ai_lab_semantic_v1_proof_register(const uint8_t *input, size_t length,
                                              agentic_ai_lab_semantic_result *result);
int32_t agentic_ai_lab_semantic_v1_derivation_admit(const uint8_t *input, size_t length,
                                           agentic_ai_lab_semantic_result *result);
int32_t agentic_ai_lab_semantic_v1_close(void);
void agentic_ai_lab_semantic_v1_result_release(agentic_ai_lab_semantic_result *result);
/* 0 success, 1 closed/unavailable, 2 wrong thread, 3 invalid transport,
 * 4 semantic input/operation rejection, 5 allocation failure. */
#ifdef __cplusplus
}
#endif
#endif
