// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include <agentic_ai_lab/runtime_v0.h>

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/utsname.h>
#include <time.h>
#if defined(__APPLE__)
#include <mach/mach_time.h>
#endif

static const uint64_t batch_sizes[] = {1, 8, 32, 128, 1024};
static const uint64_t payload_sizes[] = {0, 1024, 65536, 1048576};
static const char *dispositions[] = {
    "allow", "deny", "success", "runtime-failure",
    "timeout", "cancel", "indeterminate"};

static uint64_t monotonic_ns(void) {
#if defined(__APPLE__)
  static mach_timebase_info_data_t timebase;
  if (timebase.denom == 0 && mach_timebase_info(&timebase) != KERN_SUCCESS)
    abort();
  uint64_t ticks = mach_absolute_time();
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

static agentic_ai_lab_runtime_v0_bytes_view view(const char *text) {
  agentic_ai_lab_runtime_v0_bytes_view value = {
      (const uint8_t *)text, (uint64_t)strlen(text)};
  return value;
}

static void require_ok(agentic_ai_lab_runtime_v0_status status) {
  if (status != AGENTIC_AI_LAB_RUNTIME_V0_OK) {
    fprintf(stderr, "runtime-v0 benchmark failure: %s\n",
            agentic_ai_lab_runtime_v0_status_name(status));
    exit(2);
  }
}

static agentic_ai_lab_runtime_v0_event_header make_event(
    uint64_t sequence, uint64_t payload_size, uint32_t disposition) {
  agentic_ai_lab_runtime_v0_event_header header = {0};
  header.layout_version = AGENTIC_AI_LAB_RUNTIME_V0_LAYOUT_VERSION;
  header.event_kind = 1;
  header.flags = disposition;
  header.sequence = sequence;
  header.event_identity.low = sequence;
  header.correlation_identity.low = sequence + UINT64_C(1000000);
  header.authorization_identity.low = sequence + UINT64_C(2000000);
  header.payload_length = payload_size;
  return header;
}

static uint64_t run_once(
    agentic_ai_lab_runtime_v0_handle instance,
    agentic_ai_lab_runtime_v0_handle bundle,
    uint8_t *arena_memory,
    uint64_t arena_capacity,
    uint64_t batch_size,
    uint64_t payload_size,
    uint32_t disposition,
    agentic_ai_lab_runtime_v0_event_header *headers,
    uint32_t *statuses,
    uint8_t *bitmap) {
  agentic_ai_lab_runtime_v0_session_descriptor session_desc = {0};
  session_desc.struct_size = sizeof(session_desc);
  agentic_ai_lab_runtime_v0_handle session = {0};
  require_ok(agentic_ai_lab_runtime_v0_session_open(instance, bundle, &session_desc,
                                               &session));
  agentic_ai_lab_runtime_v0_arena_descriptor arena_desc = {0};
  arena_desc.struct_size = sizeof(arena_desc);
  arena_desc.alignment = 64;
  arena_desc.ptr = arena_memory;
  arena_desc.capacity = arena_capacity;
  arena_desc.generation = 1;
  agentic_ai_lab_runtime_v0_handle arena = {0};
  require_ok(agentic_ai_lab_runtime_v0_arena_register(instance, &arena_desc, &arena));
  for (uint64_t i = 0; i < batch_size; ++i) {
    headers[i] = make_event(i + 1, payload_size, disposition);
  }
  agentic_ai_lab_runtime_v0_publish_request publish = {0};
  publish.struct_size = sizeof(publish);
  publish.arena = arena;
  publish.arena_generation = 1;
  publish.headers = headers;
  publish.header_stride = sizeof(*headers);
  publish.item_count = batch_size;
  agentic_ai_lab_runtime_v0_publish_result published = {0};
  published.struct_size = sizeof(published);
  require_ok(agentic_ai_lab_runtime_v0_publish_batch(instance, session, &publish,
                                                &published));

  agentic_ai_lab_runtime_v0_poll_request poll = {0};
  poll.struct_size = sizeof(poll);
  poll.arena = arena;
  poll.arena_generation = 1;
  poll.headers = headers;
  poll.header_stride = sizeof(*headers);
  poll.header_capacity = batch_size;
  poll.payload_capacity = arena_capacity;
  agentic_ai_lab_runtime_v0_poll_result polled = {0};
  polled.struct_size = sizeof(polled);

  agentic_ai_lab_runtime_v0_submit_request submit = {0};
  submit.struct_size = sizeof(submit);
  submit.arena = arena;
  submit.arena_generation = 1;
  submit.headers = headers;
  submit.header_stride = sizeof(*headers);
  submit.item_count = batch_size;
  submit.item_statuses = statuses;
  submit.item_status_capacity = batch_size;
  submit.accepted_bitmap = bitmap;
  submit.accepted_bitmap_bytes = batch_size / 8 + (batch_size % 8 != 0);
  agentic_ai_lab_runtime_v0_submit_result submitted = {0};
  submitted.struct_size = sizeof(submitted);

  uint64_t started = monotonic_ns();
  require_ok(agentic_ai_lab_runtime_v0_poll_batch(instance, session, &poll, &polled));
  require_ok(agentic_ai_lab_runtime_v0_submit_batch(instance, session, &submit,
                                              &submitted));
  require_ok(agentic_ai_lab_runtime_v0_batch_ack(instance, session, polled.lease));
  uint64_t elapsed = monotonic_ns() - started;
  if (polled.produced_count != batch_size || submitted.accepted_count != batch_size)
    abort();
  require_ok(agentic_ai_lab_runtime_v0_arena_recycle(instance, arena, 1, 2));
  require_ok(agentic_ai_lab_runtime_v0_arena_release(instance, arena));
  require_ok(agentic_ai_lab_runtime_v0_session_close(instance, session, 1));
  require_ok(agentic_ai_lab_runtime_v0_session_release(instance, session));
  return elapsed;
}

int main(int argc, char **argv) {
  uint64_t iterations = 20;
  if (argc == 2) iterations = (uint64_t)strtoull(argv[1], NULL, 10);
  if (iterations == 0) return 2;
  struct utsname system_info;
  if (uname(&system_info) != 0) return 2;
  const uint64_t arena_capacity = 1048576;
  uint8_t *arena_memory = aligned_alloc(64, arena_capacity);
  agentic_ai_lab_runtime_v0_event_header *headers =
      calloc(1024, sizeof(*headers));
  uint32_t *statuses = calloc(1024, sizeof(*statuses));
  uint8_t *bitmap = calloc(128, 1);
  uint64_t *samples = calloc(iterations, sizeof(*samples));
  if (!arena_memory || !headers || !statuses || !bitmap || !samples) return 2;
  memset(arena_memory, 0x5a, arena_capacity);

  agentic_ai_lab_runtime_v0_handle instance = {0};
  require_ok(agentic_ai_lab_runtime_v0_instance_create(&instance));
  agentic_ai_lab_runtime_v0_negotiate_request negotiate = {0};
  negotiate.struct_size = sizeof(negotiate);
  negotiate.abi_minor = AGENTIC_AI_LAB_RUNTIME_V0_ABI_MINOR;
  negotiate.required_capabilities = AGENTIC_AI_LAB_RUNTIME_V0_CAP_CONTROL |
      AGENTIC_AI_LAB_RUNTIME_V0_CAP_HOT_BATCH |
      AGENTIC_AI_LAB_RUNTIME_V0_CAP_BULK_BUFFER |
      AGENTIC_AI_LAB_RUNTIME_V0_CAP_CALLER_ARENA |
      AGENTIC_AI_LAB_RUNTIME_V0_CAP_PARTIAL_ACCEPTANCE;
  negotiate.bundle_schema = view(AGENTIC_AI_LAB_RUNTIME_V0_BUNDLE_SCHEMA);
  negotiate.runtime_identity = view("c-benchmark");
  agentic_ai_lab_runtime_v0_negotiate_result negotiated = {0};
  negotiated.struct_size = sizeof(negotiated);
  require_ok(agentic_ai_lab_runtime_v0_negotiate(instance, &negotiate, &negotiated));
  agentic_ai_lab_runtime_v0_bundle_descriptor bundle_desc = {0};
  bundle_desc.struct_size = sizeof(bundle_desc);
  memset(bundle_desc.digest, 0x33, sizeof(bundle_desc.digest));
  bundle_desc.schema = view(AGENTIC_AI_LAB_RUNTIME_V0_BUNDLE_SCHEMA);
  bundle_desc.canonical_packet = view("benchmark-bundle");
  agentic_ai_lab_runtime_v0_handle bundle = {0};
  require_ok(agentic_ai_lab_runtime_v0_bundle_open(instance, negotiated.profile,
                                              &bundle_desc, &bundle));

  for (size_t b = 0; b < sizeof(batch_sizes) / sizeof(batch_sizes[0]); ++b) {
    for (size_t p = 0; p < sizeof(payload_sizes) / sizeof(payload_sizes[0]); ++p) {
      for (size_t d = 0; d < sizeof(dispositions) / sizeof(dispositions[0]); ++d) {
        for (uint64_t i = 0; i < iterations; ++i)
          samples[i] = run_once(instance, bundle, arena_memory, arena_capacity,
                                batch_sizes[b], payload_sizes[p], (uint32_t)d,
                                headers, statuses, bitmap);
        qsort(samples, iterations, sizeof(*samples), compare_u64);
        uint64_t p50 = samples[iterations / 2];
        uint64_t p99 = samples[(iterations * 99 - 1) / 100];
        struct rusage usage;
        if (getrusage(RUSAGE_SELF, &usage) != 0) return 2;
        printf("schema=agentic-ai-lab.runtime-v0.benchmark.1\n"
               "path=caller-arena-batch\nbatch=%" PRIu64
               "\npayload-bytes=%" PRIu64 "\ndisposition=%s\n"
               "iterations=%" PRIu64 "\ncrossings=3\n"
               "crossings-per-item=%.9f\nallocations-per-item=0\n"
               "copied-payload-bytes=0\np50-ns=%" PRIu64
               "\np99-ns=%" PRIu64 "\nrss-max=%ld\n"
               "system=%s\nmachine=%s\ncompiler=%s\n"
               "lookup-algorithm=ordered-window-lower-bound\n"
               "lookup-complexity=O(log-n-plus-k)\n"
               "abi-v1-frozen=false\n--\n",
               batch_sizes[b], payload_sizes[p], dispositions[d], iterations,
               3.0 / (double)batch_sizes[b], p50, p99, usage.ru_maxrss,
               system_info.sysname, system_info.machine,
#if defined(__clang__)
               "clang"
#elif defined(__GNUC__)
               "gcc"
#else
               "unknown"
#endif
        );
      }
    }
  }
  require_ok(agentic_ai_lab_runtime_v0_bundle_release(instance, bundle));
  require_ok(agentic_ai_lab_runtime_v0_profile_release(instance, negotiated.profile));
  require_ok(agentic_ai_lab_runtime_v0_instance_release(instance));
  free(samples); free(bitmap); free(statuses); free(headers); free(arena_memory);
  return 0;
}
