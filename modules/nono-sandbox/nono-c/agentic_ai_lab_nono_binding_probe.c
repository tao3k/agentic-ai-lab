// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/*
 * Compile-only probe for the Agentic AI Lab nono C binding.
 *
 * The probe intentionally does not link or apply nono. It verifies that a C11
 * compiler can consume our binding header, the generated nono header, constants,
 * opaque pointer types, value structs, and function signatures in one unit.
 */

#include "agentic_ai_lab_nono_binding.h"

#include <stddef.h>

_Static_assert(AGENTIC_AI_LAB_NONO_ACCESS_READ == NONO_ACCESS_MODE_READ,
               "read access constant drifted");
_Static_assert(AGENTIC_AI_LAB_NONO_ACCESS_WRITE == NONO_ACCESS_MODE_WRITE,
               "write access constant drifted");
_Static_assert(AGENTIC_AI_LAB_NONO_ACCESS_READ_WRITE == NONO_ACCESS_MODE_READ_WRITE,
               "read-write access constant drifted");
_Static_assert(AGENTIC_AI_LAB_NONO_NETWORK_BLOCKED == NONO_NETWORK_MODE_BLOCKED,
               "blocked network constant drifted");
_Static_assert(AGENTIC_AI_LAB_NONO_NETWORK_ALLOW_ALL == NONO_NETWORK_MODE_ALLOW_ALL,
               "allow-all network constant drifted");
_Static_assert(AGENTIC_AI_LAB_NONO_NETWORK_PROXY_ONLY == NONO_NETWORK_MODE_PROXY_ONLY,
               "proxy-only network constant drifted");

static void
agentic_ai_lab_nono_binding_probe_values(void)
{
  enum NonoErrorCode code = NONO_ERROR_CODE_OK;
  enum NonoDiagnosticCode diagnostic_code = NONO_DIAGNOSTIC_CODE_OTHER;
  struct NonoQueryResult query_result = {0};
  struct NonoSupportInfo support_info = {0};
  AgenticAILabNonoMountGrant mount = {
    .path = "/workspace",
    .access_mode = AGENTIC_AI_LAB_NONO_ACCESS_READ_WRITE,
    .is_file = false
  };
  AgenticAILabNonoNetworkGrant network = {
    .network_mode = AGENTIC_AI_LAB_NONO_NETWORK_PROXY_ONLY,
    .proxy_port = 11434,
    .has_proxy_port = true
  };

  (void)code;
  (void)diagnostic_code;
  (void)query_result;
  (void)support_info;
  (void)mount;
  (void)network;
}

static void
agentic_ai_lab_nono_binding_probe_api(void)
{
  AgenticAILabNonoBindingApi api = {
    .last_error = nono_last_error,
    .clear_error = nono_clear_error,
    .string_free = nono_string_free,
    .version = nono_version,
    .last_diagnostic_code = nono_last_diagnostic_code,
    .last_remediation_json = nono_last_remediation_json,
    .session_diagnostic_report_to_json = nono_session_diagnostic_report_to_json,
    .merge_diagnostic_report_json = nono_merge_diagnostic_report_json,
    .capability_set_new = nono_capability_set_new,
    .capability_set_free = nono_capability_set_free,
    .capability_set_allow_path = nono_capability_set_allow_path,
    .capability_set_allow_file = nono_capability_set_allow_file,
    .capability_set_set_network_mode = nono_capability_set_set_network_mode,
    .capability_set_set_proxy_port = nono_capability_set_set_proxy_port,
    .capability_set_allow_command = nono_capability_set_allow_command,
    .capability_set_block_command = nono_capability_set_block_command,
    .capability_set_add_platform_rule = nono_capability_set_add_platform_rule,
    .capability_set_deduplicate = nono_capability_set_deduplicate,
    .query_context_new = nono_query_context_new,
    .query_context_free = nono_query_context_free,
    .query_context_query_path = nono_query_context_query_path,
    .query_context_query_network = nono_query_context_query_network,
    .sandbox_apply = nono_sandbox_apply,
    .sandbox_is_supported = nono_sandbox_is_supported,
    .sandbox_support_info = nono_sandbox_support_info,
    .sandbox_state_from_caps = nono_sandbox_state_from_caps,
    .sandbox_state_free = nono_sandbox_state_free,
    .sandbox_state_to_json = nono_sandbox_state_to_json,
    .sandbox_state_from_json = nono_sandbox_state_from_json,
    .sandbox_state_to_caps = nono_sandbox_state_to_caps
  };

  (void)api;
}

int
agentic_ai_lab_nono_binding_probe(void)
{
  agentic_ai_lab_nono_binding_probe_values();
  agentic_ai_lab_nono_binding_probe_api();
  return agentic_ai_lab_nono_access_mode_supported(AGENTIC_AI_LAB_NONO_ACCESS_READ) &&
         agentic_ai_lab_nono_network_mode_supported(AGENTIC_AI_LAB_NONO_NETWORK_BLOCKED)
           ? 0
           : 1;
}
