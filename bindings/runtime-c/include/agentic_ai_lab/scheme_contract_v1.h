// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#ifndef AGENTIC_AI_LAB_SCHEME_CONTRACT_V1_H
#define AGENTIC_AI_LAB_SCHEME_CONTRACT_V1_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AGENTIC_AI_LAB_SCHEME_CONTRACT_ABI_VERSION 1u

typedef struct {
  int32_t status;
  /* Owned UTF-8 bytes, NUL-terminated for C readers; length excludes NUL. */
  uint8_t *payload;
  size_t length;
} agentic_ai_lab_scheme_result_v1;

void agentic_ai_lab_scheme_result_v1_init(agentic_ai_lab_scheme_result_v1 *result);
void agentic_ai_lab_scheme_result_v1_release(agentic_ai_lab_scheme_result_v1 *result);
uint32_t agentic_ai_lab_scheme_contract_abi_version(void);
int32_t agentic_ai_lab_scheme_contract_descriptor(agentic_ai_lab_scheme_result_v1 *result);
int32_t agentic_ai_lab_scheme_contract_validate(char *contract,
                                        char *payload,
                                        agentic_ai_lab_scheme_result_v1 *result);

#ifdef __cplusplus
}
#endif

#endif
