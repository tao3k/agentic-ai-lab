// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include <lean/lean.h>
#include "agentic_ai_lab_proof_ffi.h"

uint32_t agentic_ai_lab_proof_abi_version_raw(void) {
  return AGENTIC_AI_LAB_PROOF_ABI_VERSION;
}

uint32_t agentic_ai_lab_proof_obligation_schema_version_raw(void) {
  return AGENTIC_AI_LAB_PROOF_OBLIGATION_SCHEMA_VERSION;
}

uint32_t agentic_ai_lab_proof_tag_width_raw(void) {
  return AGENTIC_AI_LAB_PROOF_TAG_WIDTH_UINT32;
}

uint32_t agentic_ai_lab_proof_obligation_count_raw(void) {
  return AGENTIC_AI_LAB_PROOF_OBLIGATION_COUNT;
}

uint32_t agentic_ai_lab_proof_required_obligation_mask_raw(void) {
  return AGENTIC_AI_LAB_PROOF_REQUIRED_OBLIGATION_MASK;
}

uint32_t agentic_ai_lab_proof_ui_config_well_formed_bit_raw(void) {
  return AGENTIC_AI_LAB_OBLIGATION_UI_CONFIG_WELL_FORMED;
}

uint32_t agentic_ai_lab_proof_ui_profile_policy_linked_bit_raw(void) {
  return AGENTIC_AI_LAB_OBLIGATION_UI_PROFILE_POLICY_LINKED;
}

uint32_t agentic_ai_lab_proof_loop_strategy_plan_well_formed_bit_raw(void) {
  return AGENTIC_AI_LAB_OBLIGATION_LOOP_STRATEGY_PLAN_WELL_FORMED;
}

uint32_t agentic_ai_lab_proof_execution_policy_capability_bounded_bit_raw(void) {
  return AGENTIC_AI_LAB_OBLIGATION_EXECUTION_POLICY_CAPABILITY_BOUNDED;
}

uint32_t agentic_ai_lab_proof_runtime_command_inert_bit_raw(void) {
  return AGENTIC_AI_LAB_OBLIGATION_RUNTIME_COMMAND_INERT;
}

uint32_t agentic_ai_lab_proof_policy_strategy_deterministic_bit_raw(void) {
  return AGENTIC_AI_LAB_OBLIGATION_POLICY_STRATEGY_DETERMINISTIC;
}

uint32_t agentic_ai_lab_proof_workflow_agreement_linked_bit_raw(void) {
  return AGENTIC_AI_LAB_OBLIGATION_WORKFLOW_AGREEMENT_LINKED;
}

uint32_t agentic_ai_lab_proof_sandbox_boundary_linked_bit_raw(void) {
  return AGENTIC_AI_LAB_OBLIGATION_SANDBOX_BOUNDARY_LINKED;
}

uint32_t agentic_ai_lab_proof_runtime_handoff_owner_linked_bit_raw(void) {
  return AGENTIC_AI_LAB_OBLIGATION_RUNTIME_HANDOFF_OWNER_LINKED;
}

uint32_t agentic_ai_lab_proof_proof_case_vector_complete_bit_raw(void) {
  return AGENTIC_AI_LAB_OBLIGATION_PROOF_CASE_VECTOR_COMPLETE;
}

static lean_obj_res agentic_ai_lab_proof_uint32_result(uint32_t value) {
  return lean_io_result_mk_ok(lean_box_uint32(value));
}

lean_obj_res agentic_ai_lab_proof_abi_version(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(agentic_ai_lab_proof_abi_version_raw());
}

lean_obj_res agentic_ai_lab_proof_obligation_schema_version(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_obligation_schema_version_raw());
}

lean_obj_res agentic_ai_lab_proof_tag_width(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(agentic_ai_lab_proof_tag_width_raw());
}

lean_obj_res agentic_ai_lab_proof_obligation_count(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(agentic_ai_lab_proof_obligation_count_raw());
}

lean_obj_res agentic_ai_lab_proof_required_obligation_mask(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_required_obligation_mask_raw());
}

lean_obj_res agentic_ai_lab_proof_ui_config_well_formed_bit(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_ui_config_well_formed_bit_raw());
}

lean_obj_res agentic_ai_lab_proof_ui_profile_policy_linked_bit(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_ui_profile_policy_linked_bit_raw());
}

lean_obj_res agentic_ai_lab_proof_loop_strategy_plan_well_formed_bit(
    lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_loop_strategy_plan_well_formed_bit_raw());
}

lean_obj_res agentic_ai_lab_proof_execution_policy_capability_bounded_bit(
    lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_execution_policy_capability_bounded_bit_raw());
}

lean_obj_res agentic_ai_lab_proof_runtime_command_inert_bit(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_runtime_command_inert_bit_raw());
}

lean_obj_res agentic_ai_lab_proof_policy_strategy_deterministic_bit(
    lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_policy_strategy_deterministic_bit_raw());
}

lean_obj_res agentic_ai_lab_proof_workflow_agreement_linked_bit(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_workflow_agreement_linked_bit_raw());
}

lean_obj_res agentic_ai_lab_proof_sandbox_boundary_linked_bit(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_sandbox_boundary_linked_bit_raw());
}

lean_obj_res agentic_ai_lab_proof_runtime_handoff_owner_linked_bit(
    lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_runtime_handoff_owner_linked_bit_raw());
}

lean_obj_res agentic_ai_lab_proof_proof_case_vector_complete_bit(lean_obj_arg world) {
  (void)world;
  return agentic_ai_lab_proof_uint32_result(
      agentic_ai_lab_proof_proof_case_vector_complete_bit_raw());
}
