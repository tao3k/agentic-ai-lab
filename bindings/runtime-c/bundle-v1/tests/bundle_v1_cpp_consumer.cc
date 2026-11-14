// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include "agentic_ai_lab/bundle_v1.h"

#include <cstring>

static_assert(sizeof(agentic_ai_lab_bundle_v1_descriptor) == 256,
              "C++ sees a different Bundle v1 descriptor");

int main() {
  return std::strcmp(agentic_ai_lab_bundle_v1_status_name(AGENTIC_AI_LAB_BUNDLE_V1_OK),
                     "ok") == 0
             ? 0
             : 1;
}
