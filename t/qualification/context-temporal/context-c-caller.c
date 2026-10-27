/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later */
#include <gambit.h>
#include <stdio.h>
#include <string.h>
#include <agentic_ai_lab/semantic.h>

/* This caller runs inside the heap-fenced gxi test host. Only Gambit runtime setup and
 * teardown are supplied by that host; the production C facade, native Scheme
 * entry, Context/Session CAS, journal and result ownership all run unchanged.
 * This does not claim standalone AOT VM/bootstrap qualification. */
static unsigned context_test_setups;
___mod_or_lnk context_test_linker(___global_state_struct *state) {
  (void)state;
  return 0;
}
static ___SCMOBJ context_test_setup(___setup_params_struct *params) {
  /* Read the real host limit through Gambit's dynamic-extension linkage. */
  if (params->max_heap != (___SIZE_T)2 * 1024 * 1024 * 1024 ||
      params->parallelism_level != 1 ||
      ___EXT(___get_max_heap)() != (___SIZE_T)2 * 1024 * 1024 * 1024)
    return ___FIX(___UNKNOWN_ERR);
  ++context_test_setups;
  return ___FIX(___NO_ERR);
}
/* This host already owns the VM. Only the explicit parameters checked by the
 * setup Fixture above are consumed; no second VM is initialized. Linux Gerbil
 * does not export the standalone setup-parameter initializer to dynamic leaves. */
static void context_test_setup_params_reset(___setup_params_struct *params) {
  memset(params, 0, sizeof(*params));
}
static void context_test_cleanup(void) {}
#define AGENTIC_AI_LAB_SEMANTIC_LINKER context_test_linker
#define ___setup_params_reset context_test_setup_params_reset
#define ___setup context_test_setup
#define ___cleanup context_test_cleanup
/* Shared objects resolve symbols eagerly on Linux. The local callback below
 * delegates to the original Gambit native-evaluate procedure, without requiring
 * another module's C symbol to be globally visible during macro import. */
#define agentic_ai_lab_semantic_evaluate context_test_evaluate
#include "../../../bindings/runtime-c/src/semantic_host.c"
#undef ___setup_params_reset
#undef ___setup
#undef ___cleanup
#undef agentic_ai_lab_semantic_evaluate

static int context_check(agentic_ai_lab_semantic_result *result, int32_t status,
                         int32_t expected_status, const char *fragment, int code) {
  int valid = status == expected_status && result->status == expected_status &&
              (!fragment || (result->data && strstr((char *)result->data, fragment)));
  if (expected_status == 0)
    valid = valid && result->data &&
            strstr((char *)result->data, "(\"actionAuthorized\" #f)");
  if (!valid) fprintf(stderr, "CONTEXT-C failure=%d status=%d payload=%s\n",
                      code, status, result->data ? (char *)result->data : "<empty>");
  agentic_ai_lab_semantic_v1_result_release(result);
  agentic_ai_lab_semantic_v1_result_release(result);
  return valid && !result->data && !result->length && !result->status ? 0 : code;
}
static int context_command(const char *text, const char *fragment, int code) {
  agentic_ai_lab_semantic_result result = {0};
  int32_t status = agentic_ai_lab_semantic_v1_context_command(
      (const uint8_t *)text, strlen(text), &result);
  return context_check(&result, status, 0, fragment, code);
}
static int context_inspect(const char *session, unsigned epoch, const char *fragment,
                            long long *revision, int code) {
  char text[512];
  snprintf(text, sizeof text, "(object (\"schema\" \"agentic-ai-lab.context-service-request.v1\")"
      " (\"id\" \"inspect\") (\"session\" \"%s\") (\"ownerEpoch\" %u))", session, epoch);
  agentic_ai_lab_semantic_result result = {0};
  int32_t status = agentic_ai_lab_semantic_v1_call("context.lifecycle.inspect",
      (const uint8_t *)text, strlen(text), &result);
  if (revision && result.data) {
    const char *field = strstr((char *)result.data, "(\"revision\" ");
    if (!field || sscanf(field, "(\"revision\" %lld)", revision) != 1) {
      agentic_ai_lab_semantic_v1_result_release(&result);
      return code;
    }
  }
  return context_check(&result, status, 0, fragment, code);
}
static int context_session_command(const char *id, const char *operation,
    const char *session, long long revision, unsigned epoch, const char *observation,
    const char *fragment, int code) {
  char text[1024];
  snprintf(text, sizeof text, "(object (\"schema\" \"agentic-ai-lab.context-service-request.v1\")"
      " (\"id\" \"%s\") (\"operation\" \"%s\") (\"session\" \"%s\")"
      " (\"revision\" %lld) (\"generation\" 0) (\"ownerEpoch\" %u) (\"observation\" %s))",
      id, operation, session, revision, epoch, observation);
  return context_command(text, fragment, code);
}
static void *context_wrong_thread(void *unused) {
  (void)unused;
  agentic_ai_lab_semantic_result result = {0};
  int status = agentic_ai_lab_semantic_v1_context_command((const uint8_t *)"(object)", 8, &result);
  int failure = context_check(&result, status, 2, NULL, 12);
  return (void *)(uintptr_t)failure;
}
int context_c_roundtrip(int restart, const char *digest) {
  int error;
  agentic_ai_lab_semantic_result result = {0};
  if (agentic_ai_lab_semantic_v1_open() != 0 || context_test_setups != 1) return 10;
  pthread_t foreign;
  void *thread_result;
  if (pthread_create(&foreign, NULL, context_wrong_thread, NULL) ||
      pthread_join(foreign, &thread_result) || thread_result) return 12;
  /* Ordinary tool calls cannot reach the trusted mutation lane. */
  int status = agentic_ai_lab_semantic_v1_call("$host.context.lifecycle.command",
      (const uint8_t *)"(object)", 8, &result);
  if ((error = context_check(&result, status, 3, NULL, 13))) return error;
  status = agentic_ai_lab_semantic_v1_call("context.lifecycle.inspect",
      (const uint8_t *)"(object) (object)", 17, &result);
  if ((error = context_check(&result, status, 4, "semantic-error", 14))) return error;
  if (restart) {
    if ((error = context_inspect("session-c", 2, "(\"terminalCount\" 1)", NULL, 15))) return error;
    if ((error = context_session_command("restart-old", "result", "session", 2, 2,
        "\"obs-A\"", "unknown-observation", 16))) return error;
  } else {
    if ((error = context_session_command("complete-C", "result", "session-c", 2, 1,
        "\"obs-C\"", "(\"nativeResultPublished\" #t)", 20))) return error;
    if ((error = context_session_command("complete-C", "result", "session-c", 2, 1,
        "\"obs-C\"", "(\"historical\" #t)", 21))) return error;
    if ((error = context_session_command("complete-C", "result", "session", 2, 1,
        "\"obs-A\"", "identity-conflict", 22))) return error;
    if ((error = context_session_command("stale-owner", "cancel", "session", 2, 2,
        "#f", "stale-owner", 23))) return error;
    char revoke[768];
    snprintf(revoke, sizeof revoke, "(object (\"schema\" \"agentic-ai-lab.context-service-request.v1\")"
        " (\"id\" \"revoke\") (\"operation\" \"grant-revocation\") (\"grant\" \"grant\")"
        " (\"expected\" \"%s\") (\"ownerEpoch\" 1))", digest);
    if ((error = context_command(revoke, "(\"accepted\" #t)", 24))) return error;
    if ((error = context_command(revoke, "(\"historical\" #t)", 25))) return error;
    long long revision;
    if ((error = context_inspect("session", 1, "invalidated", &revision, 26))) return error;
    if ((error = context_inspect("session-b", 1, "invalidated", NULL, 27))) return error;
    if ((error = context_session_command("cancel-A", "cancel", "session", revision, 1,
        "#f", "(\"accepted\" #t)", 28))) return error;
    if ((error = context_inspect("session", 1, "invalidated", &revision, 29))) return error;
    if ((error = context_session_command("recover-A", "recover", "session", revision, 1,
        "#f", "(\"accepted\" #t)", 30))) return error;
    if ((error = context_session_command("old-A", "result", "session", 2, 1,
        "\"obs-A\"", "(\"accepted\" #f)", 31))) return error;
    if ((error = context_inspect("session-c", 1, "(\"terminalCount\" 1)", NULL, 32))) return error;
  }
  /* This invokes the real Scheme drain before the embedding host's VM hook. */
  if (agentic_ai_lab_semantic_v1_close() != 0) return 40;
  if (agentic_ai_lab_semantic_v1_open() != 1) return 41;
  status = agentic_ai_lab_semantic_v1_call("context.lifecycle.inspect",
      (const uint8_t *)"(object)", 8, &result);
  if ((error = context_check(&result, status, 1, NULL, 42))) return error;
  return 0;
}
