// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

#ifndef AGENTIC_AI_LAB_WORKFLOW_CURSOR_H
#define AGENTIC_AI_LAB_WORKFLOW_CURSOR_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint32_t pfw_workflow_cursor_capacity(void);
uint32_t pfw_workflow_cursor_open(
    uint32_t topology_handle,
    uint32_t *out_cursor_handle);
uint32_t pfw_workflow_cursor_position(
    uint32_t cursor_handle,
    uint32_t *out_completed_steps,
    uint32_t *out_step_count);
uint32_t pfw_workflow_cursor_step(uint32_t cursor_handle, uint32_t *out_completed_steps);
uint32_t pfw_workflow_cursor_reset(uint32_t cursor_handle);
uint32_t pfw_workflow_cursor_release(uint32_t cursor_handle);

#ifdef __cplusplus
}
#endif

#endif
