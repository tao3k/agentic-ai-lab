// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include <agentic_ai_lab/runtime_v0.h>

#include <assert.h>
#include <string.h>

int main(void) {
  agentic_ai_lab_runtime_v0_handle instance = {0};
  assert(agentic_ai_lab_runtime_v0_instance_create(&instance) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  assert(strcmp(agentic_ai_lab_runtime_v0_status_name(AGENTIC_AI_LAB_RUNTIME_V0_OK),
                "ok") == 0);
  assert(agentic_ai_lab_runtime_v0_instance_release(instance) ==
         AGENTIC_AI_LAB_RUNTIME_V0_OK);
  return 0;
}
