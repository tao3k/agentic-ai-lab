# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Out-of-line CFFI API projection of the semantic AOT byte boundary."""
import sys
from cffi import FFI
ffibuilder = FFI()
ffibuilder.cdef('''
typedef struct { int32_t status; uint8_t *data; size_t length; } agentic_ai_lab_semantic_result;
int32_t agentic_ai_lab_python_semantic_open(const char *path);
int32_t agentic_ai_lab_python_semantic_call(const char *operation, const uint8_t *input,
                                    size_t length, agentic_ai_lab_semantic_result *result);
int32_t agentic_ai_lab_python_semantic_source_register(const uint8_t *input, size_t length,
                                                agentic_ai_lab_semantic_result *result);
int32_t agentic_ai_lab_python_semantic_context_use_refresh(const uint8_t *input, size_t length, agentic_ai_lab_semantic_result *result);
int32_t agentic_ai_lab_python_semantic_policy_refresh(const uint8_t *input, size_t length, agentic_ai_lab_semantic_result *result);
int32_t agentic_ai_lab_python_semantic_derivation_admit(const uint8_t *input, size_t length, agentic_ai_lab_semantic_result *result);
int32_t agentic_ai_lab_python_semantic_proof_state_refresh(const uint8_t *input, size_t length, agentic_ai_lab_semantic_result *result);
int32_t agentic_ai_lab_python_semantic_proof_register(const uint8_t *input, size_t length, agentic_ai_lab_semantic_result *result);
int32_t agentic_ai_lab_python_semantic_close(void);
void agentic_ai_lab_python_semantic_release(agentic_ai_lab_semantic_result *result);
''')
ffibuilder.set_source('agentic_ai_lab_runtime._native._semantic_cffi', r'''
#include <stdint.h>
#include <stddef.h>
#include <dlfcn.h>
#include <string.h>
#include <pthread.h>
static pthread_mutex_t shim_lock = PTHREAD_MUTEX_INITIALIZER;
typedef struct { int32_t status; uint8_t *data; size_t length; } agentic_ai_lab_semantic_result;
static void *library;
static int32_t (*open_native)(void);
static int32_t (*call_native)(const char *, const uint8_t *, size_t, agentic_ai_lab_semantic_result *);
static int32_t (*register_source_native)(const uint8_t *, size_t, agentic_ai_lab_semantic_result *);
static int32_t (*context_use_refresh_native)(const uint8_t *, size_t, agentic_ai_lab_semantic_result *);
static int32_t (*refresh_policy_native)(const uint8_t *, size_t, agentic_ai_lab_semantic_result *);
static int32_t (*admit_derivation_native)(const uint8_t *, size_t, agentic_ai_lab_semantic_result *);
static int32_t (*proof_state_refresh_native)(const uint8_t *, size_t, agentic_ai_lab_semantic_result *);
static int32_t (*proof_register_native)(const uint8_t *, size_t, agentic_ai_lab_semantic_result *);
static int32_t (*close_native)(void);
static void (*release_native)(agentic_ai_lab_semantic_result *);
int32_t agentic_ai_lab_python_semantic_open(const char *path) {
  pthread_mutex_lock(&shim_lock);
  if (library) { pthread_mutex_unlock(&shim_lock); return 1; }
  library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
  if (!library) { pthread_mutex_unlock(&shim_lock); return 6; }
  void *symbol;
#define LOAD(field, name) symbol = dlsym(library, name); if (!symbol) { dlclose(library); library = NULL; pthread_mutex_unlock(&shim_lock); return 6; } memcpy(&field, &symbol, sizeof(field))
  LOAD(open_native, "agentic_ai_lab_semantic_v1_open");
  LOAD(call_native, "agentic_ai_lab_semantic_v1_call");
  LOAD(register_source_native, "agentic_ai_lab_semantic_v1_source_register");
  LOAD(context_use_refresh_native, "agentic_ai_lab_semantic_v1_context_use_refresh");
  LOAD(refresh_policy_native, "agentic_ai_lab_semantic_v1_policy_refresh");
  LOAD(admit_derivation_native, "agentic_ai_lab_semantic_v1_derivation_admit");
  LOAD(proof_state_refresh_native, "agentic_ai_lab_semantic_v1_proof_state_refresh");
  LOAD(proof_register_native, "agentic_ai_lab_semantic_v1_proof_register");
  LOAD(close_native, "agentic_ai_lab_semantic_v1_close");
  LOAD(release_native, "agentic_ai_lab_semantic_v1_result_release");
#undef LOAD
  int32_t status = open_native();
  pthread_mutex_unlock(&shim_lock);
  return status;
}
int32_t agentic_ai_lab_python_semantic_call(const char *operation, const uint8_t *input,
                                    size_t length, agentic_ai_lab_semantic_result *result) {
  pthread_mutex_lock(&shim_lock);
  int32_t status = library ? call_native(operation, input, length, result) : 1;
  pthread_mutex_unlock(&shim_lock);
  return status;
}
int32_t agentic_ai_lab_python_semantic_source_register(const uint8_t *input, size_t length,
                                                agentic_ai_lab_semantic_result *result) {
  pthread_mutex_lock(&shim_lock);
  int32_t status = library ? register_source_native(input, length, result) : 1;
  pthread_mutex_unlock(&shim_lock);
  return status;
}
int32_t agentic_ai_lab_python_semantic_context_use_refresh(const uint8_t *input, size_t length, agentic_ai_lab_semantic_result *result) {
  pthread_mutex_lock(&shim_lock);
  int32_t status = library ? context_use_refresh_native(input, length, result) : 1;
  pthread_mutex_unlock(&shim_lock);
  return status;
}
int32_t agentic_ai_lab_python_semantic_policy_refresh(const uint8_t *input, size_t length,
                                               agentic_ai_lab_semantic_result *result) {
  pthread_mutex_lock(&shim_lock);
  int32_t status = library ? refresh_policy_native(input, length, result) : 1;
  pthread_mutex_unlock(&shim_lock);
  return status;
}
int32_t agentic_ai_lab_python_semantic_derivation_admit(const uint8_t *input, size_t length,
                                                agentic_ai_lab_semantic_result *result) {
  pthread_mutex_lock(&shim_lock);
  int32_t status = library ? admit_derivation_native(input, length, result) : 1;
  pthread_mutex_unlock(&shim_lock);
  return status;
}
int32_t agentic_ai_lab_python_semantic_proof_state_refresh(const uint8_t *input, size_t length, agentic_ai_lab_semantic_result *result) {
  pthread_mutex_lock(&shim_lock);
  int32_t status = library ? proof_state_refresh_native(input, length, result) : 1;
  pthread_mutex_unlock(&shim_lock);
  return status;
}
int32_t agentic_ai_lab_python_semantic_proof_register(const uint8_t *input, size_t length, agentic_ai_lab_semantic_result *result) {
  pthread_mutex_lock(&shim_lock);
  int32_t status = library ? proof_register_native(input, length, result) : 1;
  pthread_mutex_unlock(&shim_lock);
  return status;
}
int32_t agentic_ai_lab_python_semantic_close(void) {
  pthread_mutex_lock(&shim_lock);
  int32_t status = library ? close_native() : 1;
  pthread_mutex_unlock(&shim_lock);
  return status;
}
void agentic_ai_lab_python_semantic_release(agentic_ai_lab_semantic_result *result) {
  pthread_mutex_lock(&shim_lock);
  if (library) release_native(result);
  pthread_mutex_unlock(&shim_lock);
}
''', libraries=['dl', 'pthread'] if sys.platform.startswith('linux') else [])

if __name__ == '__main__':
    ffibuilder.compile(verbose=True)
