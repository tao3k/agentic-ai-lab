// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

/*
 * Project-owned nono C ABI contract for Agentic AI Lab compile probes.
 *
 * This header mirrors the subset of always-further/nono's C ABI that the
 * Scheme control plane describes and the adapter probe compiles against. It is
 * intentionally declarations-only: the real implementation remains in the
 * native nono_ffi library loaded by an external runtime or explicit live test.
 */

#ifndef AGENTIC_AI_LAB_NONO_ABI_H
#define AGENTIC_AI_LAB_NONO_ABI_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NONO_ACCESS_MODE_READ ((uint32_t)0)
#define NONO_ACCESS_MODE_WRITE ((uint32_t)1)
#define NONO_ACCESS_MODE_READ_WRITE ((uint32_t)2)
#define NONO_ACCESS_MODE_INVALID UINT32_MAX

#define NONO_NETWORK_MODE_BLOCKED ((uint32_t)0)
#define NONO_NETWORK_MODE_ALLOW_ALL ((uint32_t)1)
#define NONO_NETWORK_MODE_PROXY_ONLY ((uint32_t)2)

enum NonoCapabilitySourceTag {
  NONO_CAPABILITY_SOURCE_TAG_USER = 0,
  NONO_CAPABILITY_SOURCE_TAG_GROUP = 1,
  NONO_CAPABILITY_SOURCE_TAG_SYSTEM = 2,
  NONO_CAPABILITY_SOURCE_TAG_PROFILE = 3
};

enum NonoQueryStatus {
  NONO_QUERY_STATUS_ALLOWED = 0,
  NONO_QUERY_STATUS_DENIED = 1
};

enum NonoQueryReason {
  NONO_QUERY_REASON_GRANTED_PATH = 0,
  NONO_QUERY_REASON_NETWORK_ALLOWED = 1,
  NONO_QUERY_REASON_PATH_NOT_GRANTED = 2,
  NONO_QUERY_REASON_INSUFFICIENT_ACCESS = 3,
  NONO_QUERY_REASON_NETWORK_BLOCKED = 4
};

struct NonoQueryResult {
  enum NonoQueryStatus status;
  enum NonoQueryReason reason;
  char *granted_path;
  char *access;
  char *granted;
  char *requested;
};

struct NonoSupportInfo {
  bool is_supported;
  char *platform;
  char *details;
};

enum NonoErrorCode {
  NONO_ERROR_CODE_OK = 0,
  NONO_ERROR_CODE_ERR_PATH_NOT_FOUND = -1,
  NONO_ERROR_CODE_ERR_EXPECTED_DIRECTORY = -2,
  NONO_ERROR_CODE_ERR_EXPECTED_FILE = -3,
  NONO_ERROR_CODE_ERR_PATH_CANONICALIZATION = -4,
  NONO_ERROR_CODE_ERR_NO_CAPABILITIES = -5,
  NONO_ERROR_CODE_ERR_SANDBOX_INIT = -6,
  NONO_ERROR_CODE_ERR_UNSUPPORTED_PLATFORM = -7,
  NONO_ERROR_CODE_ERR_BLOCKED_COMMAND = -8,
  NONO_ERROR_CODE_ERR_CONFIG_PARSE = -9,
  NONO_ERROR_CODE_ERR_PROFILE_PARSE = -10,
  NONO_ERROR_CODE_ERR_IO = -11,
  NONO_ERROR_CODE_ERR_INVALID_ARG = -12,
  NONO_ERROR_CODE_ERR_TRUST_VERIFICATION = -13,
  NONO_ERROR_CODE_ERR_UNKNOWN = -99
};

enum NonoDiagnosticCode {
  NONO_DIAGNOSTIC_CODE_SANDBOX_DENIED_PATH = 0,
  NONO_DIAGNOSTIC_CODE_SANDBOX_DENIED_NETWORK = 1,
  NONO_DIAGNOSTIC_CODE_SANDBOX_DENIED_UNIX_SOCKET = 2,
  NONO_DIAGNOSTIC_CODE_COMMAND_NOT_FOUND = 3,
  NONO_DIAGNOSTIC_CODE_COMMAND_FAILED_LIKELY_SANDBOX = 4,
  NONO_DIAGNOSTIC_CODE_COMMAND_FAILED_APPLICATION = 5,
  NONO_DIAGNOSTIC_CODE_CREDENTIAL_NOT_FOUND = 6,
  NONO_DIAGNOSTIC_CODE_CREDENTIAL_UNAVAILABLE = 7,
  NONO_DIAGNOSTIC_CODE_UNSUPPORTED_PLATFORM_FEATURE = 8,
  NONO_DIAGNOSTIC_CODE_ROLLBACK_BUDGET_EXCEEDED = 9,
  NONO_DIAGNOSTIC_CODE_CWD_ACCESS_REQUIRED = 10,
  NONO_DIAGNOSTIC_CODE_CONFIGURATION_ERROR = 11,
  NONO_DIAGNOSTIC_CODE_TRUST_VERIFICATION_FAILED = 12,
  NONO_DIAGNOSTIC_CODE_IO_ERROR = 13,
  NONO_DIAGNOSTIC_CODE_CANCELLED = 14,
  NONO_DIAGNOSTIC_CODE_OTHER = 99
};

struct NonoCapabilitySet;
struct NonoQueryContext;
struct NonoSandboxState;

char *nono_last_error(void);
void nono_clear_error(void);
void nono_string_free(char *s);
char *nono_version(void);
enum NonoDiagnosticCode nono_last_diagnostic_code(void);
char *nono_last_remediation_json(void);
char *nono_session_diagnostic_report_to_json(int32_t exit_code,
                                             const char *denials_json,
                                             const char *ipc_denials_json,
                                             const char *violations_json);
char *nono_merge_diagnostic_report_json(const char *session_json,
                                        const char *proxy_diagnostics_json);

struct NonoCapabilitySet *nono_capability_set_new(void);
void nono_capability_set_free(struct NonoCapabilitySet *caps);
enum NonoErrorCode nono_capability_set_allow_path(
    struct NonoCapabilitySet *caps,
    const char *path,
    uint32_t mode);
enum NonoErrorCode nono_capability_set_allow_file(
    struct NonoCapabilitySet *caps,
    const char *path,
    uint32_t mode);
enum NonoErrorCode nono_capability_set_set_network_blocked(
    struct NonoCapabilitySet *caps,
    bool blocked);
enum NonoErrorCode nono_capability_set_set_network_mode(
    struct NonoCapabilitySet *caps,
    uint32_t mode);
uint32_t nono_capability_set_network_mode(const struct NonoCapabilitySet *caps);
enum NonoErrorCode nono_capability_set_set_proxy_port(
    struct NonoCapabilitySet *caps,
    uint16_t port);
uint16_t nono_capability_set_proxy_port(const struct NonoCapabilitySet *caps);
enum NonoErrorCode nono_capability_set_allow_command(
    struct NonoCapabilitySet *caps,
    const char *command);
enum NonoErrorCode nono_capability_set_block_command(
    struct NonoCapabilitySet *caps,
    const char *command);
enum NonoErrorCode nono_capability_set_add_platform_rule(
    struct NonoCapabilitySet *caps,
    const char *rule);
void nono_capability_set_deduplicate(struct NonoCapabilitySet *caps);

struct NonoQueryContext *nono_query_context_new(
    const struct NonoCapabilitySet *caps);
void nono_query_context_free(struct NonoQueryContext *context);
enum NonoErrorCode nono_query_context_query_path(
    const struct NonoQueryContext *context,
    const char *path,
    uint32_t mode,
    struct NonoQueryResult *out);
enum NonoErrorCode nono_query_context_query_network(
    const struct NonoQueryContext *context,
    struct NonoQueryResult *out);

enum NonoErrorCode nono_sandbox_apply(const struct NonoCapabilitySet *caps);
bool nono_sandbox_is_supported(void);
struct NonoSupportInfo nono_sandbox_support_info(void);

struct NonoSandboxState *nono_sandbox_state_from_caps(
    const struct NonoCapabilitySet *caps);
void nono_sandbox_state_free(struct NonoSandboxState *state);
char *nono_sandbox_state_to_json(const struct NonoSandboxState *state);
struct NonoSandboxState *nono_sandbox_state_from_json(const char *json);
struct NonoCapabilitySet *nono_sandbox_state_to_caps(
    const struct NonoSandboxState *state);

#ifdef __cplusplus
}
#endif

#endif /* AGENTIC_AI_LAB_NONO_ABI_H */
