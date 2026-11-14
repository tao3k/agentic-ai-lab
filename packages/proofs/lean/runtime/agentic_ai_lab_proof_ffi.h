// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#ifndef AGENTIC_AI_LAB_PROOF_FFI_H
#define AGENTIC_AI_LAB_PROOF_FFI_H

#include <stdint.h>

#define AGENTIC_AI_LAB_PROOF_ABI_VERSION 1u
#define AGENTIC_AI_LAB_PROOF_OBLIGATION_SCHEMA_VERSION 1u
#define AGENTIC_AI_LAB_PROOF_TAG_WIDTH_UINT32 32u
#define AGENTIC_AI_LAB_PROOF_OBLIGATION_COUNT 10u

#define AGENTIC_AI_LAB_OBLIGATION_UI_CONFIG_WELL_FORMED (1u << 0)
#define AGENTIC_AI_LAB_OBLIGATION_UI_PROFILE_POLICY_LINKED (1u << 1)
#define AGENTIC_AI_LAB_OBLIGATION_LOOP_STRATEGY_PLAN_WELL_FORMED (1u << 2)
#define AGENTIC_AI_LAB_OBLIGATION_EXECUTION_POLICY_CAPABILITY_BOUNDED (1u << 3)
#define AGENTIC_AI_LAB_OBLIGATION_POLICY_STRATEGY_DETERMINISTIC (1u << 4)
#define AGENTIC_AI_LAB_OBLIGATION_RUNTIME_COMMAND_INERT (1u << 5)
#define AGENTIC_AI_LAB_OBLIGATION_WORKFLOW_AGREEMENT_LINKED (1u << 6)
#define AGENTIC_AI_LAB_OBLIGATION_SANDBOX_BOUNDARY_LINKED (1u << 7)
#define AGENTIC_AI_LAB_OBLIGATION_RUNTIME_HANDOFF_OWNER_LINKED (1u << 8)
#define AGENTIC_AI_LAB_OBLIGATION_PROOF_CASE_VECTOR_COMPLETE (1u << 9)

#define AGENTIC_AI_LAB_PROOF_REQUIRED_OBLIGATION_MASK \
  (AGENTIC_AI_LAB_OBLIGATION_UI_CONFIG_WELL_FORMED | \
   AGENTIC_AI_LAB_OBLIGATION_UI_PROFILE_POLICY_LINKED | \
   AGENTIC_AI_LAB_OBLIGATION_LOOP_STRATEGY_PLAN_WELL_FORMED | \
   AGENTIC_AI_LAB_OBLIGATION_EXECUTION_POLICY_CAPABILITY_BOUNDED | \
   AGENTIC_AI_LAB_OBLIGATION_POLICY_STRATEGY_DETERMINISTIC | \
   AGENTIC_AI_LAB_OBLIGATION_RUNTIME_COMMAND_INERT | \
   AGENTIC_AI_LAB_OBLIGATION_WORKFLOW_AGREEMENT_LINKED | \
   AGENTIC_AI_LAB_OBLIGATION_SANDBOX_BOUNDARY_LINKED | \
   AGENTIC_AI_LAB_OBLIGATION_RUNTIME_HANDOFF_OWNER_LINKED | \
   AGENTIC_AI_LAB_OBLIGATION_PROOF_CASE_VECTOR_COMPLETE)

uint32_t agentic_ai_lab_proof_abi_version_raw(void);
uint32_t agentic_ai_lab_proof_obligation_schema_version_raw(void);
uint32_t agentic_ai_lab_proof_tag_width_raw(void);
uint32_t agentic_ai_lab_proof_obligation_count_raw(void);
uint32_t agentic_ai_lab_proof_required_obligation_mask_raw(void);
uint32_t agentic_ai_lab_proof_ui_config_well_formed_bit_raw(void);
uint32_t agentic_ai_lab_proof_ui_profile_policy_linked_bit_raw(void);
uint32_t agentic_ai_lab_proof_loop_strategy_plan_well_formed_bit_raw(void);
uint32_t agentic_ai_lab_proof_execution_policy_capability_bounded_bit_raw(void);
uint32_t agentic_ai_lab_proof_runtime_command_inert_bit_raw(void);
uint32_t agentic_ai_lab_proof_policy_strategy_deterministic_bit_raw(void);
uint32_t agentic_ai_lab_proof_workflow_agreement_linked_bit_raw(void);
uint32_t agentic_ai_lab_proof_sandbox_boundary_linked_bit_raw(void);
uint32_t agentic_ai_lab_proof_runtime_handoff_owner_linked_bit_raw(void);
uint32_t agentic_ai_lab_proof_proof_case_vector_complete_bit_raw(void);

#endif
