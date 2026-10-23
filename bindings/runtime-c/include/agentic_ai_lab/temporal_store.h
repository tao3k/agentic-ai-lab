/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later */
#ifndef AGENTIC_AI_LAB_TEMPORAL_STORE_H
#define AGENTIC_AI_LAB_TEMPORAL_STORE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct agentic_ai_lab_temporal_store agentic_ai_lab_temporal_store;
/* Borrowed input: a projection of a freshly replayed native POO admission.
 * Host control code supplies this; never expose raw basis/grant APIs as tools.
 * Names are bounded UTF-8 C strings (128 bytes), digests canonical sha256 IDs. */
typedef struct {
  char admission[129], source[129], source_digest[129];
  char subject[129], scope[129], policy[129], revision[129], proof[129];
  uint64_t generation;
} agentic_ai_lab_temporal_basis;
typedef struct {
  char store_identity[65], key[129], request_digest[129];
  char admission[129], subject[129], scope[129], policy[129];
  char revision[129], proof[129], source_digest[129], authority[129];
  uint64_t previous_version, version, authorization_fence, source_generation;
} agentic_ai_lab_temporal_commit_receipt;
/* 0 success, 1 invalid input, 2 pointer conflict, 3 authorization denied,
 * 4 stale source, 5 idempotency mismatch, 6 storage error, 7 not found.
 * Transactions serialize across handles/processes. Receipts are immutable.
 * Registry, grant and commit calls are host controls, not semantic byte ops.
 * First-root profile: only version 0 / empty predecessor may select a root.
 * Grant authorizes local pointer selection only, never an external effect. */
int32_t agentic_ai_lab_temporal_store_open(const char *path, agentic_ai_lab_temporal_store **out);
void agentic_ai_lab_temporal_store_close(agentic_ai_lab_temporal_store *store);
int32_t agentic_ai_lab_temporal_store_source(agentic_ai_lab_temporal_store *store,
    const char *source, const char *digest, uint64_t generation);
int32_t agentic_ai_lab_temporal_store_authorize(agentic_ai_lab_temporal_store *store,
    const char *subject, const char *scope, const char *policy,
    const char *authority, uint64_t fence, int32_t enabled);
int32_t agentic_ai_lab_temporal_store_pointer(agentic_ai_lab_temporal_store *store,
    const char *subject, const char *scope, uint64_t *version, char selected[129]);
int32_t agentic_ai_lab_temporal_store_receipt(agentic_ai_lab_temporal_store *store,
    const char *key, agentic_ai_lab_temporal_commit_receipt *out);
int32_t agentic_ai_lab_temporal_store_commit(agentic_ai_lab_temporal_store *store,
    const agentic_ai_lab_temporal_basis *basis, const char *key, const char *request_digest,
    uint64_t expected_version, const char *expected_revision, uint64_t fence,
    agentic_ai_lab_temporal_commit_receipt *out);
#ifdef __cplusplus
}
#endif
#endif
