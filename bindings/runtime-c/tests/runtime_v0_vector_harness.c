// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include "agentic_ai_lab/runtime_v0.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint64_t field(const char *text, const char *name) {
  const char *found = strstr(text, name);
  if (found == NULL || found[strlen(name)] != '=') abort();
  return strtoull(found + strlen(name) + 1, NULL, 10);
}

int main(int argc, char **argv) {
  if (argc != 2) return 2;
  FILE *input = fopen(argv[1], "rb");
  if (input == NULL) return 2;
  char text[2048];
  size_t count = fread(text, 1, sizeof(text) - 1, input);
  fclose(input);
  text[count] = '\0';
  assert(strstr(text, "schema=agentic-ai-lab.runtime-v0.native-event-vector.1\n") != NULL);
  agentic_ai_lab_runtime_v0_event_header header = {0};
  header.layout_version = (uint16_t)field(text, "layout-version");
  header.event_kind = (uint16_t)field(text, "event-kind");
  header.flags = (uint32_t)field(text, "flags");
  header.sequence = field(text, "sequence");
  header.event_identity.high = field(text, "event-id-high");
  header.event_identity.low = field(text, "event-id-low");
  header.correlation_identity.high = field(text, "correlation-id-high");
  header.correlation_identity.low = field(text, "correlation-id-low");
  header.authorization_identity.high = field(text, "authorization-id-high");
  header.authorization_identity.low = field(text, "authorization-id-low");
  header.payload_offset = field(text, "payload-offset");
  header.payload_length = field(text, "payload-length");
  header.deadline_mono_ns = field(text, "deadline-mono-ns");
  header.required_evidence_bits = (uint32_t)field(text, "required-evidence-bits");
  header.reserved0 = (uint32_t)field(text, "reserved0");
  assert(field(text, "header-bytes") == sizeof(header));
  assert(header.layout_version == AGENTIC_AI_LAB_RUNTIME_V0_LAYOUT_VERSION);
  assert(header.sequence == 7);
  assert(header.authorization_identity.high == 5);
  assert(header.authorization_identity.low == 6);
  assert(header.payload_offset == 64 && header.payload_length == 128);
  assert(header.reserved0 == 0);
  return 0;
}
