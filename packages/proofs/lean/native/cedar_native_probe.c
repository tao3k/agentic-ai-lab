// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/* Qualification host, not a replacement for the isolated authority engine.
 * All Lean initialization, calls and object releases happen on one worker.
 * This host launches no subprocess and does not alter signal dispositions.
 */
#include <lean/lean.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* These declarations match this project's generated Lean 4.31 C, rather
 * than assuming the initialization ABI of a different cedar-lean-ffi pin. */
extern void lean_initialize(void);
extern void lean_finalize_thread(void);
extern void lean_set_exit_on_panic(bool);
extern lean_object *initialize_agentic_x2dai_x2dlab_x2dproof_AgenticAILabProof_Runtime_CedarNative(uint8_t);
extern lean_object *agentic_ai_lab_cedar_authorize_native(lean_object *);

enum { INPUT_LIMIT = 1024 * 1024, REPETITIONS = 128 };
struct probe_input {
  unsigned char *bytes;
  size_t size;
  unsigned int repetitions;
  int status;
  struct sigaction child_handler;
};

static unsigned long long elapsed_ns(struct timespec started,
                                     struct timespec finished) {
  long long seconds = finished.tv_sec - started.tv_sec;
  long long nanoseconds = finished.tv_nsec - started.tv_nsec;
  if (nanoseconds < 0) {
    --seconds;
    nanoseconds += 1000000000LL;
  }
  return (unsigned long long)seconds * 1000000000ULL +
         (unsigned long long)nanoseconds;
}

static void *evaluate_owned(void *argument) {
  struct probe_input *input = argument;
  lean_initialize();
  /* Never continue with Lean's default value after a panic. */
  lean_set_exit_on_panic(true);
  lean_object *initialized =
      initialize_agentic_x2dai_x2dlab_x2dproof_AgenticAILabProof_Runtime_CedarNative(1);
  if (lean_io_result_is_error(initialized)) {
    lean_io_result_show_error(initialized);
    lean_dec(initialized);
    input->status = 3;
    return NULL;
  }
  lean_dec(initialized);
  lean_io_mark_end_initialization();
  struct sigaction current;
  if (sigaction(SIGCHLD, NULL, &current) != 0 ||
      current.sa_handler != input->child_handler.sa_handler ||
      current.sa_flags != input->child_handler.sa_flags) {
    fprintf(stderr, "cedar-native-signal-owner-changed\n");
    input->status = 7;
    return NULL;
  }
  for (int signal_number = 1; signal_number < NSIG; ++signal_number) {
    if (sigismember(&current.sa_mask, signal_number) !=
        sigismember(&input->child_handler.sa_mask, signal_number)) {
      fprintf(stderr, "cedar-native-signal-owner-changed\n");
      input->status = 7;
      return NULL;
    }
  }
  char *first = NULL;
  struct timespec started;
  struct timespec finished;
  if (clock_gettime(CLOCK_MONOTONIC, &started) != 0) {
    input->status = 8;
    return NULL;
  }
  for (unsigned int i = 0; i < input->repetitions; ++i) {
    lean_object *bytes = lean_alloc_sarray(1, input->size, input->size);
    memcpy(lean_sarray_cptr(bytes), input->bytes, input->size);
    /* authorize_native consumes bytes. The Except owns its String field. */
    lean_object *result = agentic_ai_lab_cedar_authorize_native(bytes);
    const char *json = lean_string_cstr(lean_ctor_get(result, 0));
    if (lean_obj_tag(result) == 0) {
      fprintf(stderr, "cedar-input-invalid: %s\n", json);
      lean_dec(result);
      free(first);
      input->status = 2;
      return NULL;
    }
    if (first == NULL) {
      first = strdup(json);
      if (first == NULL) {
        lean_dec(result);
        input->status = 4;
        return NULL;
      }
    } else if (strcmp(first, json) != 0) {
      fprintf(stderr, "cedar-native-projection-unstable\n");
      lean_dec(result);
      free(first);
      input->status = 5;
      return NULL;
    }
    lean_dec(result);
  }
  if (clock_gettime(CLOCK_MONOTONIC, &finished) != 0) {
    free(first);
    input->status = 8;
    return NULL;
  }
  puts(first);
  fprintf(stderr,
          "cedar-native-receipt repetitions=%d steady_elapsed_ns=%llu "
          "sigchld_preserved=true\n",
          input->repetitions, elapsed_ns(started, finished));
  free(first);
  input->status = 0;
  return NULL;
}

static void *evaluate(void *argument) {
  void *result = evaluate_owned(argument);
  lean_finalize_thread();
  return result;
}

int main(int argc, char **argv) {
  const char *filename;
  unsigned int repetitions;
  if (argc == 2) {
    filename = argv[1];
    repetitions = REPETITIONS;
  } else if (argc == 3 && strcmp(argv[1], "authorize") == 0) {
    filename = argv[2];
    repetitions = 1;
  } else {
    return 64;
  }
  FILE *file = fopen(filename, "rb");
  if (file == NULL) return 66;
  unsigned char *bytes = malloc(INPUT_LIMIT + 1);
  if (bytes == NULL) { fclose(file); return 4; }
  size_t size = fread(bytes, 1, INPUT_LIMIT + 1, file);
  int invalid = ferror(file) || size > INPUT_LIMIT;
  fclose(file);
  if (invalid) { free(bytes); return 65; }
  struct probe_input input = {
      .bytes = bytes, .size = size, .repetitions = repetitions, .status = 3};
  if (sigaction(SIGCHLD, NULL, &input.child_handler) != 0) {
    free(bytes);
    return 71;
  }
  pthread_t worker;
  if (pthread_create(&worker, NULL, evaluate, &input) != 0) {
    free(bytes);
    return 71;
  }
  if (pthread_join(worker, NULL) != 0) return 71;
  free(bytes);
  return input.status;
}
