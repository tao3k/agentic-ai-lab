// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#include "agentic_ai_lab/workflow_cursor.h"

#include <stddef.h>

#include "agentic_ai_lab/runtime_wasm.h"

#define PFW_WORKFLOW_CURSOR_SLOT_COUNT 1024u

typedef struct pfw_workflow_cursor_slot {
  uint32_t step_count;
  uint32_t completed_steps;
  uint8_t occupied;
} pfw_workflow_cursor_slot;

static pfw_workflow_cursor_slot pfw_workflow_cursor_slots[PFW_WORKFLOW_CURSOR_SLOT_COUNT];

static pfw_workflow_cursor_slot *pfw_workflow_cursor_get(uint32_t cursor_handle) {
  if (cursor_handle == 0u || cursor_handle >= PFW_WORKFLOW_CURSOR_SLOT_COUNT) {
    return NULL;
  }
  if (pfw_workflow_cursor_slots[cursor_handle].occupied == 0u) {
    return NULL;
  }
  return &pfw_workflow_cursor_slots[cursor_handle];
}

uint32_t pfw_workflow_cursor_capacity(void) {
  return PFW_WORKFLOW_CURSOR_SLOT_COUNT - 1u;
}

uint32_t pfw_workflow_cursor_open(
    uint32_t topology_handle,
    uint32_t *out_cursor_handle) {
  uint32_t cursor_handle;
  uint32_t step_count = 0u;
  uint32_t status;

  if (out_cursor_handle == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  status = pfw_topology_component_count(topology_handle, &step_count);
  if (status != 0u) {
    return status;
  }
  if (step_count == 0u) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }

  for (cursor_handle = 1u; cursor_handle < PFW_WORKFLOW_CURSOR_SLOT_COUNT; cursor_handle += 1u) {
    pfw_workflow_cursor_slot *slot = &pfw_workflow_cursor_slots[cursor_handle];
    if (slot->occupied == 0u) {
      slot->step_count = step_count;
      slot->completed_steps = 0u;
      slot->occupied = 1u;
      *out_cursor_handle = cursor_handle;
      return 0u;
    }
  }

  return PFW_WASM_STATUS_SLOT_EXHAUSTED;
}

uint32_t pfw_workflow_cursor_position(
    uint32_t cursor_handle,
    uint32_t *out_completed_steps,
    uint32_t *out_step_count) {
  pfw_workflow_cursor_slot *slot;

  if (out_completed_steps == NULL || out_step_count == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  slot = pfw_workflow_cursor_get(cursor_handle);
  if (slot == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }

  *out_completed_steps = slot->completed_steps;
  *out_step_count = slot->step_count;
  return 0u;
}

uint32_t pfw_workflow_cursor_step(uint32_t cursor_handle, uint32_t *out_completed_steps) {
  pfw_workflow_cursor_slot *slot;

  if (out_completed_steps == NULL) {
    return PFW_WASM_STATUS_INVALID_ARGUMENT;
  }
  slot = pfw_workflow_cursor_get(cursor_handle);
  if (slot == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }

  if (slot->completed_steps < slot->step_count) {
    slot->completed_steps += 1u;
  }
  *out_completed_steps = slot->completed_steps;
  return 0u;
}

uint32_t pfw_workflow_cursor_reset(uint32_t cursor_handle) {
  pfw_workflow_cursor_slot *slot = pfw_workflow_cursor_get(cursor_handle);
  if (slot == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  slot->completed_steps = 0u;
  return 0u;
}

uint32_t pfw_workflow_cursor_release(uint32_t cursor_handle) {
  pfw_workflow_cursor_slot *slot = pfw_workflow_cursor_get(cursor_handle);
  if (slot == NULL) {
    return PFW_WASM_STATUS_INVALID_SLOT;
  }
  slot->step_count = 0u;
  slot->completed_steps = 0u;
  slot->occupied = 0u;
  return 0u;
}
