/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later */
#include <agentic_ai_lab/semantic.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

/* This caller loads the packaged artifact and exercises its actual SDK VM.
 * It replaces no setup/cleanup functions and installs no native Context.
 * Active Context/Session CAS remains covered by context-c-caller.c. */
typedef struct {
  int32_t (*open)(void);
  int32_t (*call)(const char *, const uint8_t *, size_t,
                  agentic_ai_lab_semantic_result *);
  int32_t (*close)(void);
  void (*release)(agentic_ai_lab_semantic_result *);
} semantic_api;

static semantic_api api;
static int32_t foreign_status;

static int call_status(const char *operation, const char *input, int expected) {
  agentic_ai_lab_semantic_result result = {0, NULL, 0};
  int32_t status = api.call(operation, (const uint8_t *)input, strlen(input), &result);
  api.release(&result);
  if (status != expected || result.data || result.length || result.status) {
    fprintf(stderr, "ABI call %s: expected %d, got %d\n", operation, expected, status);
    return 0;
  }
  return 1;
}

static void *foreign_call(void *unused) {
  (void)unused;
  agentic_ai_lab_semantic_result result = {0, NULL, 0};
  foreign_status = api.call("descriptor", (const uint8_t *)"(object)", 8, &result);
  api.release(&result);
  return NULL;
}

int main(int argc, char **argv) {
  if (argc != 2) return 64;
  void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!library) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 1; }
  api.open = (int32_t (*)(void))dlsym(library, "agentic_ai_lab_semantic_v1_open");
  api.call = (int32_t (*)(const char *, const uint8_t *, size_t,
                          agentic_ai_lab_semantic_result *))
      dlsym(library, "agentic_ai_lab_semantic_v1_call");
  api.close = (int32_t (*)(void))dlsym(library, "agentic_ai_lab_semantic_v1_close");
  api.release = (void (*)(agentic_ai_lab_semantic_result *))
      dlsym(library, "agentic_ai_lab_semantic_v1_result_release");
  if (!api.open || !api.call || !api.close || !api.release) return 2;
  if (api.open() != 0 || api.open() != 1) return 3;

  /* Observe the new projection through the public wire format, and release
   * the copied result before exercising the rejection controls. */
  agentic_ai_lab_semantic_result descriptor = {0, NULL, 0};
  if (api.call("descriptor", (const uint8_t *)"(object)", 8, &descriptor) != 0)
    return 4;
  const char operation[] = "context.lifecycle.inspect";
  int found = 0;
  for (size_t i = 0; i + sizeof(operation) - 1 <= descriptor.length; ++i) {
    if (memcmp(descriptor.data + i, operation, sizeof(operation) - 1) == 0) found = 1;
  }
  api.release(&descriptor);
  if (!found || descriptor.data || descriptor.length) return 5;

  pthread_t foreign;
  if (pthread_create(&foreign, NULL, foreign_call, NULL) != 0) return 6;
  if (pthread_join(foreign, NULL) != 0 || foreign_status != 2) return 7;
  if (!call_status("$host.context.lifecycle.shutdown", "(object)", 3) ||
      !call_status("descriptor", "(object) (object)", 4) ||
      !call_status("descriptor", "(object)", 0)) return 8;

  /* There is no installed service: serialized fields cannot fabricate one.
   * Real shutdown must nevertheless succeed and make VM reopening terminal. */
  if (!call_status("context.lifecycle.inspect",
        "(object (\"schema\" \"agentic-ai-lab.context-service-request.v1\")"
        " (\"id\" \"smoke\") (\"session\" \"absent\") (\"ownerEpoch\" 1))", 4))
    return 9;
  if (api.close() != 0 || api.close() != 1 || api.open() != 1) return 10;
  if (!call_status("descriptor", "(object)", 1)) return 11;
  puts("SEMANTIC-C-OK setup=actual close=actual result=released foreign=refused control=refused reopen=refused");
  return 0;
}
