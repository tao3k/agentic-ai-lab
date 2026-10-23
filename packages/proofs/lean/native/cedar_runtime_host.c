// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/* Thin ABI owner for the Lean-linked AOT Runtime Host. Rust owns the Host
 * protocol; this file owns Lean initialization and Lean object lifetimes. */
#include <lean/lean.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

extern void lean_initialize(void);
extern void lean_set_exit_on_panic(bool);
extern lean_object *initialize_agentic_x2dai_x2dlab_x2dproof_AgenticAILabProof_Runtime_CedarRuntimeHost(uint8_t);
extern lean_object *agentic_ai_lab_cedar_authorize_native(lean_object *);
extern int agentic_ai_lab_cedar_runtime_host_main(int argc, const char *const *argv);

static bool lean_ready = false;

static int initialize_lean(void) {
  if (lean_ready) return 0;
  lean_initialize();
  lean_set_exit_on_panic(true);
  lean_object *initialized =
      initialize_agentic_x2dai_x2dlab_x2dproof_AgenticAILabProof_Runtime_CedarRuntimeHost(1);
  if (lean_io_result_is_error(initialized)) {
    lean_io_result_show_error(initialized);
    lean_dec(initialized);
    return 3;
  }
  lean_dec(initialized);
  lean_io_mark_end_initialization();
  lean_ready = true;
  return 0;
}

int agentic_ai_lab_cedar_lean_authorize(const uint8_t *input, size_t length,
                                  char **output, char **error) {
  *output = NULL;
  *error = NULL;
  int initialized = initialize_lean();
  if (initialized != 0) return initialized;
  lean_object *bytes = lean_alloc_sarray(1, length, length);
  memcpy(lean_sarray_cptr(bytes), input, length);
  /* The exported Lean function consumes bytes. Except owns the String. */
  lean_object *result = agentic_ai_lab_cedar_authorize_native(bytes);
  const char *value = lean_string_cstr(lean_ctor_get(result, 0));
  char *copy = strdup(value);
  bool failed = lean_obj_tag(result) == 0;
  lean_dec(result);
  if (copy == NULL) return 4;
  if (failed) {
    *error = copy;
    return 2;
  }
  *output = copy;
  return 0;
}

void agentic_ai_lab_cedar_lean_string_free(char *value) { free(value); }

int main(int argc, char **argv) {
  return agentic_ai_lab_cedar_runtime_host_main(argc, (const char *const *)argv);
}
