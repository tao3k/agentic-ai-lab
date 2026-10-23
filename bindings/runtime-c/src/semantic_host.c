/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later */
#include "gambit.h"
#include <agentic_ai_lab/semantic.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
___BEGIN_NEW_LNK
___DEF_NEW_LNK(AGENTIC_AI_LAB_SEMANTIC_LINKER)
___END_NEW_LNK
extern int32_t agentic_ai_lab_semantic_evaluate(char *, char *, agentic_ai_lab_semantic_result *);
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static int state = 0;
static pthread_t owner;
static int valid_utf8(const uint8_t *bytes, size_t length) {
  size_t i = 0;
  while (i < length) {
    uint32_t value = bytes[i++];
    if (value < 0x80) continue;
    unsigned count; uint32_t minimum;
    if (value >= 0xc2 && value <= 0xdf) { count = 1; minimum = 0x80; value &= 0x1f; }
    else if (value >= 0xe0 && value <= 0xef) { count = 2; minimum = 0x800; value &= 0xf; }
    else if (value >= 0xf0 && value <= 0xf4) { count = 3; minimum = 0x10000; value &= 7; }
    else return 0;
    if (count > length - i) return 0;
    while (count--) {
      uint8_t next = bytes[i++];
      if ((next & 0xc0) != 0x80) return 0;
      value = (value << 6) | (next & 0x3f);
    }
    if (value < minimum || value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff)) return 0;
  }
  return 1;
}
static int bounded_scheme_depth(const uint8_t *bytes, size_t length) {
  int depth = 0, quoted = 0, escape = 0;
  for (size_t i = 0; i < length; i++) {
    uint8_t c = bytes[i];
    if (quoted) {
      if (escape) escape = 0;
      else if (c == '\\') escape = 1;
      else if (c == '"') quoted = 0;
    } else if (c == '"') quoted = 1;
    else if (c == '(') { if (++depth > 64) return 0; }
    else if (c == ')') { if (--depth < 0) return 0; }
  }
  return depth == 0 && !quoted;
}
int32_t agentic_ai_lab_semantic_v1_open(void) {
  pthread_mutex_lock(&lock);
  if (state != 0) { pthread_mutex_unlock(&lock); return 1; }
  state = 2; /* Failed setup is terminal. */
  owner = pthread_self();
  ___setup_params_struct params;
  ___setup_params_reset(&params);
  params.version = ___VERSION;
  params.linker = AGENTIC_AI_LAB_SEMANTIC_LINKER;
  params.parallelism_level = 1;
  params.max_heap = 1024 * 1024 * 1024;
  params.debug_settings = ___DEBUG_SETTINGS_INITIAL;
  if (___setup(&params) != ___FIX(___NO_ERR)) {
    pthread_mutex_unlock(&lock); return 1;
  }
  state = 1;
  pthread_mutex_unlock(&lock);
  return 0;
}
static int32_t semantic_call(const char *operation, const uint8_t *input,
                             size_t length, agentic_ai_lab_semantic_result *result, int control) {
  pthread_mutex_lock(&lock);
  int32_t status;
  if (state != 1) status = 1;
  else if (!pthread_equal(owner, pthread_self())) status = 2;
  else if (!operation || !input || !result || result->data || result->length ||
           !length || length > 1048576 || memchr(input, 0, length) ||
           (!control && operation[0] == '$') ||
           strnlen(operation, 129) > 128 ||
           !valid_utf8((const uint8_t *)operation, strnlen(operation, 129)) ||
           !valid_utf8(input, length) ||
           !bounded_scheme_depth(input, length)) status = 3;
  else {
    char *copy = malloc(length + 1);
    if (!copy) status = 5;
    else {
      memcpy(copy, input, length); copy[length] = 0;
      status = agentic_ai_lab_semantic_evaluate((char *)operation, copy, result);
      free(copy);
    }
  }
  if (result && !result->data) result->status = status;
  pthread_mutex_unlock(&lock);
  return status;
}
int32_t agentic_ai_lab_semantic_v1_call(const char *operation, const uint8_t *input,
                                 size_t length, agentic_ai_lab_semantic_result *result) {
  return semantic_call(operation, input, length, result, 0);
}
int32_t agentic_ai_lab_semantic_v1_source_register(const uint8_t *input, size_t length,
                                           agentic_ai_lab_semantic_result *result) {
  return semantic_call("$host.temporal.source.register", input, length, result, 1);
}
int32_t agentic_ai_lab_semantic_v1_policy_refresh(const uint8_t *input, size_t length,
                                          agentic_ai_lab_semantic_result *result) {
  return semantic_call("$host.temporal.policy.refresh", input, length, result, 1);
}
int32_t agentic_ai_lab_semantic_v1_derivation_admit(const uint8_t *input, size_t length,
                                            agentic_ai_lab_semantic_result *result) {
  return semantic_call("$host.temporal.derivation.admit", input, length, result, 1);
}
int32_t agentic_ai_lab_semantic_v1_close(void) {
  pthread_mutex_lock(&lock);
  if (state != 1) { pthread_mutex_unlock(&lock); return 1; }
  if (!pthread_equal(owner, pthread_self())) { pthread_mutex_unlock(&lock); return 2; }
  ___cleanup(); state = 2;
  pthread_mutex_unlock(&lock);
  return 0;
}
void agentic_ai_lab_semantic_v1_result_release(agentic_ai_lab_semantic_result *result) {
  if (!result) return;
  free(result->data); result->data = NULL; result->length = 0; result->status = 0;
}

int32_t agentic_ai_lab_semantic_v1_proof_state_refresh(const uint8_t *input, size_t length, agentic_ai_lab_semantic_result *result) {
  return semantic_call("$host.temporal.proof.state.refresh", input, length, result, 1);
}

int32_t agentic_ai_lab_semantic_v1_proof_register(const uint8_t *input, size_t length, agentic_ai_lab_semantic_result *result) {
  return semantic_call("$host.temporal.proof.register", input, length, result, 1);
}

int32_t agentic_ai_lab_semantic_v1_context_use_refresh(const uint8_t *input, size_t length,
    agentic_ai_lab_semantic_result *result) {
  return semantic_call("$host.context.use.refresh", input, length, result, 1);
}
