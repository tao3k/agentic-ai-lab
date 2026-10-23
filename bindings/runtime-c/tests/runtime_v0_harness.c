// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include "agentic_ai_lab/runtime_v0.h"

#include <assert.h>
#include <string.h>

static agentic_ai_lab_runtime_v0_bytes_view view(const char *text) {
  agentic_ai_lab_runtime_v0_bytes_view value = {
      (const uint8_t *)text, (uint64_t)strlen(text)};
  return value;
}

int main(void) {
  const char *schema = "agentic-ai-lab.organization-bundle.draft.3";
  agentic_ai_lab_runtime_v0_handle instance = {0};
  assert(agentic_ai_lab_runtime_v0_instance_create(&instance) == AGENTIC_AI_LAB_RUNTIME_V0_OK);

  agentic_ai_lab_runtime_v0_negotiate_request request = {0};
  request.struct_size = sizeof(request);
  request.abi_major = 0;
  request.abi_minor = 1;
  request.required_capabilities = AGENTIC_AI_LAB_RUNTIME_V0_CAP_CONTROL;
  request.optional_capabilities = AGENTIC_AI_LAB_RUNTIME_V0_CAP_CHECKPOINT;
  request.max_payload_bytes = 1024;
  request.bundle_schema = view(schema);
  request.runtime_identity = view("c-harness");
  agentic_ai_lab_runtime_v0_negotiate_result negotiated = {0};
  negotiated.struct_size = sizeof(negotiated);
  assert(agentic_ai_lab_runtime_v0_negotiate(instance, &request, &negotiated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);

  request.required_capabilities = UINT64_C(1) << 63;
  assert(agentic_ai_lab_runtime_v0_negotiate(instance, &request, &negotiated) ==
         AGENTIC_AI_LAB_RUNTIME_V0_UNSUPPORTED_CAPABILITY);
  request.required_capabilities = AGENTIC_AI_LAB_RUNTIME_V0_CAP_CONTROL;

  agentic_ai_lab_runtime_v0_bundle_descriptor bundle_desc = {0};
  bundle_desc.struct_size = sizeof(bundle_desc);
  bundle_desc.digest_algorithm = 1;
  memset(bundle_desc.digest, 0x5a, sizeof(bundle_desc.digest));
  bundle_desc.bundle_epoch = 9;
  bundle_desc.schema = view(schema);
  bundle_desc.canonical_packet = view("canonical-bundle-packet");
  agentic_ai_lab_runtime_v0_handle bundle = {0};
  assert(agentic_ai_lab_runtime_v0_bundle_open(instance, negotiated.profile,
                                         &bundle_desc, &bundle) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);

  agentic_ai_lab_runtime_v0_session_descriptor session_desc = {0};
  session_desc.struct_size = sizeof(session_desc);
  session_desc.initial_sequence = 7;
  agentic_ai_lab_runtime_v0_handle session = {0};
  assert(agentic_ai_lab_runtime_v0_session_open(instance, bundle, &session_desc,
                                          &session) == AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_session_cancel(instance, session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_session_cancel(instance, session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);

  agentic_ai_lab_runtime_v0_owned_bytes checkpoint = {0};
  assert(agentic_ai_lab_runtime_v0_session_checkpoint(instance, session, &checkpoint) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  agentic_ai_lab_runtime_v0_handle restored = {0};
  agentic_ai_lab_runtime_v0_bytes_view checkpoint_view = {checkpoint.ptr, checkpoint.len};
  assert(agentic_ai_lab_runtime_v0_session_restore(instance, bundle, checkpoint_view,
                                             &restored) == AGENTIC_AI_LAB_RUNTIME_V0_OK);
  checkpoint.ptr[0] ^= 1;
  assert(agentic_ai_lab_runtime_v0_session_restore(instance, bundle, checkpoint_view,
                                             &restored) ==
         AGENTIC_AI_LAB_RUNTIME_V0_CHECKPOINT_INCOMPATIBLE);
  checkpoint.ptr[0] ^= 1;
  assert(agentic_ai_lab_runtime_v0_owned_bytes_release(instance, &checkpoint) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);

  agentic_ai_lab_runtime_v0_handle other_instance = {0};
  assert(agentic_ai_lab_runtime_v0_instance_create(&other_instance) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_session_cancel(other_instance, session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_CROSS_INSTANCE_HANDLE);
  assert(agentic_ai_lab_runtime_v0_bundle_release(instance, session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_WRONG_HANDLE_KIND);

  assert(agentic_ai_lab_runtime_v0_session_close(instance, session, 1) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_session_release(instance, session) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  agentic_ai_lab_runtime_v0_status released_status =
      agentic_ai_lab_runtime_v0_session_cancel(instance, session);
  assert(released_status == AGENTIC_AI_LAB_RUNTIME_V0_STALE_HANDLE ||
         released_status == AGENTIC_AI_LAB_RUNTIME_V0_ALREADY_RELEASED);
  assert(agentic_ai_lab_runtime_v0_session_close(instance, restored, 1) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_session_release(instance, restored) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_bundle_release(instance, bundle) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_profile_release(instance, negotiated.profile) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_instance_release(instance) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(agentic_ai_lab_runtime_v0_instance_release(other_instance) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  return 0;
}
