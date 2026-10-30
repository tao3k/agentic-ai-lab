// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include <stddef.h>

#include "agentic_ai_lab/scheme_native_v1.h"

_Static_assert(AGENTIC_AI_LAB_SCHEME_NATIVE_ABI_VERSION == 1u,
               "Scheme-native ABI version drift");
_Static_assert(offsetof(agentic_ai_lab_scheme_result_v1, status) == 0u,
               "result status must be the leading field");
_Static_assert(offsetof(agentic_ai_lab_scheme_result_v1, payload) >
                   offsetof(agentic_ai_lab_scheme_result_v1, status),
               "result payload layout drift");
_Static_assert(offsetof(agentic_ai_lab_scheme_result_v1, length) >
                   offsetof(agentic_ai_lab_scheme_result_v1, payload),
               "result length layout drift");

int main(void) { return 0; }
