// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include <agentic_ai_lab/proof_case_v1.h>

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>
#include <time.h>
#if defined(__APPLE__)
#include <mach/mach_time.h>
#endif

static const uint64_t batch_sizes[] = {1, 8, 32, 128, 1024};
static const uint32_t profiles[] = {AGENTIC_AI_LAB_PROOF_DURABILITY_STRICT,
                                    AGENTIC_AI_LAB_PROOF_DURABILITY_BATCHED};
static const char *profile_names[] = {"strict", "batched"};
static const uint8_t schema_fingerprint[32] =
    AGENTIC_AI_LAB_PROOF_CASE_SCHEMA_FINGERPRINT_BYTES;

static uint64_t monotonic_ns(void) {
#if defined(__APPLE__)
  static mach_timebase_info_data_t timebase;
  uint64_t ticks;
  if (timebase.denom == 0u && mach_timebase_info(&timebase) != KERN_SUCCESS)
    abort();
  ticks = mach_absolute_time();
  return ticks * timebase.numer / timebase.denom;
#else
  struct timespec value;
  if (clock_gettime(CLOCK_MONOTONIC, &value) != 0) abort();
  return (uint64_t)value.tv_sec * UINT64_C(1000000000) +
         (uint64_t)value.tv_nsec;
#endif
}

static int compare_u64(const void *left, const void *right) {
  uint64_t a = *(const uint64_t *)left;
  uint64_t b = *(const uint64_t *)right;
  return (a > b) - (a < b);
}

static void write_u32_le(uint8_t *bytes, uint32_t value) {
  bytes[0] = (uint8_t)value;
  bytes[1] = (uint8_t)(value >> 8u);
  bytes[2] = (uint8_t)(value >> 16u);
  bytes[3] = (uint8_t)(value >> 24u);
}

static void write_u64_le(uint8_t *bytes, uint64_t value) {
  size_t index;
  for (index = 0u; index < 8u; ++index)
    bytes[index] = (uint8_t)(value >> (index * 8u));
}

static void make_vector(uint8_t *vector, uint64_t sequence,
                        uint32_t durability) {
  memset(vector, 0, AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_ABI_VERSION_OFFSET,
               AGENTIC_AI_LAB_PROOF_CASE_VECTOR_VERSION);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_CASE_KIND_OFFSET,
               AGENTIC_AI_LAB_PROOF_CASE_KIND_AUTHORIZED_EFFECT_TOKEN);
  memcpy(vector + AGENTIC_AI_LAB_PROOF_FIELD_SCHEMA_FINGERPRINT_OFFSET,
         schema_fingerprint, sizeof(schema_fingerprint));
  write_u64_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_NONCE_OFFSET, sequence + 1u);
  write_u64_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_EPOCH_OFFSET, 4u);
  write_u64_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_SEQUENCE_OFFSET, sequence);
  write_u64_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_REQUIRED_OBLIGATION_MASK_OFFSET,
               AGENTIC_AI_LAB_PROOF_REQUIRED_OBLIGATION_MASK);
  write_u64_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_PRESENT_OBLIGATION_MASK_OFFSET,
               AGENTIC_AI_LAB_PROOF_REQUIRED_OBLIGATION_MASK);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_OBLIGATION_COUNT_OFFSET, 8u);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_MEDIATION_OUTCOME_OFFSET,
               AGENTIC_AI_LAB_PROOF_MEDIATION_ALLOW);
  write_u32_le(vector + AGENTIC_AI_LAB_PROOF_FIELD_DURABILITY_PROFILE_OFFSET,
               durability);
}

static uint64_t run_once(uint8_t *vectors, uint8_t *outputs,
                         agentic_ai_lab_proof_case_handle *handles,
                         uint64_t batch_size) {
  uint64_t index;
  uint64_t started = monotonic_ns();
  for (index = 0u; index < batch_size; ++index) {
    size_t written = 0u;
    uint8_t *vector = vectors + index * AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE;
    uint8_t *output = outputs + index * AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE;
    if (agentic_ai_lab_proof_case_init(vector, AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE,
                                 &handles[index]) != AGENTIC_AI_LAB_PROOF_STATUS_OK ||
        agentic_ai_lab_proof_case_write(&handles[index], output,
                                  AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE,
                                  &written) != AGENTIC_AI_LAB_PROOF_STATUS_OK ||
        written != AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE ||
        agentic_ai_lab_proof_case_release(&handles[index]) !=
            AGENTIC_AI_LAB_PROOF_STATUS_OK)
      abort();
  }
  return monotonic_ns() - started;
}

int main(int argc, char **argv) {
  uint64_t iterations = 100u;
  const uint64_t maximum_batch = 1024u;
  uint8_t *vectors;
  uint8_t *outputs;
  agentic_ai_lab_proof_case_handle *handles;
  uint64_t *samples;
  struct utsname system_info;
  size_t profile_index;
  size_t batch_index;
  if (argc == 2) iterations = (uint64_t)strtoull(argv[1], NULL, 10);
  if (iterations == 0u || uname(&system_info) != 0) return 2;
  vectors = calloc(maximum_batch, AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE);
  outputs = calloc(maximum_batch, AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE);
  handles = calloc(maximum_batch, sizeof(*handles));
  samples = calloc(iterations, sizeof(*samples));
  if (vectors == NULL || outputs == NULL || handles == NULL || samples == NULL)
    return 2;

  for (profile_index = 0u; profile_index < 2u; ++profile_index) {
    uint64_t index;
    for (index = 0u; index < maximum_batch; ++index)
      make_vector(vectors + index * AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE, index,
                  profiles[profile_index]);
    for (batch_index = 0u;
         batch_index < sizeof(batch_sizes) / sizeof(batch_sizes[0]);
         ++batch_index) {
      uint64_t iteration;
      uint64_t batch_size = batch_sizes[batch_index];
      for (iteration = 0u; iteration < iterations; ++iteration)
        samples[iteration] = run_once(vectors, outputs, handles, batch_size);
      qsort(samples, iterations, sizeof(*samples), compare_u64);
      printf("schema=agentic-ai-lab.proof-case-v1.benchmark.1\n"
             "path=caller-owned-whole-vector\nprofile=%s\nbatch=%" PRIu64
             "\niterations=%" PRIu64 "\ncrossings-per-item=3\n"
             "allocations-per-item=0\ncopied-bytes-per-item=%u\n"
             "p50-ns=%" PRIu64 "\np99-ns=%" PRIu64 "\n"
             "vector-construction-complexity=O(1)\n"
             "batch-complexity=O(k)\n"
             "system=%s\nmachine=%s\nabi-v1-frozen=false\n--\n",
             profile_names[profile_index], batch_size, iterations,
             AGENTIC_AI_LAB_PROOF_CASE_VECTOR_SIZE, samples[iterations / 2u],
             samples[(iterations * 99u - 1u) / 100u], system_info.sysname,
             system_info.machine);
    }
  }
  free(samples);
  free(handles);
  free(outputs);
  free(vectors);
  return 0;
}
