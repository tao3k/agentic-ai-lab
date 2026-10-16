;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public API re-exports the control-plane modules.
;;; Invariant: implementation logic stays in the leaf owners below.

(import :poo-flow/modules/workflow/control-plane/roles
        :poo-flow/modules/workflow/control-plane/failure
        :poo-flow/modules/workflow/control-plane/receipt
        :poo-flow/modules/workflow/control-plane/task
        :poo-flow/modules/workflow/control-plane/flow-strand
        :poo-flow/modules/workflow/control-plane/flow
        :poo-flow/modules/workflow/control-plane/flow-syntax
        :poo-flow/modules/workflow/control-plane/plan
        :poo-flow/modules/workflow/control-plane/strategy
        :poo-flow/modules/workflow/control-plane/policy
        :poo-flow/modules/workflow/control-plane/runtime-protocol
        :poo-flow/modules/workflow/control-plane/runtime-command-invocation
        :poo-flow/modules/workflow/control-plane/runtime-command-descriptor
        :poo-flow/modules/workflow/control-plane/runtime-adapter
        :poo-flow/modules/workflow/control-plane/agent-harness
        :poo-flow/modules/workflow/control-plane/replay
        :poo-flow/modules/workflow/control-plane/runner
        :poo-flow/modules/workflow/control-plane/config)

(export (import: :poo-flow/modules/workflow/control-plane/roles)
        (import: :poo-flow/modules/workflow/control-plane/failure)
        (import: :poo-flow/modules/workflow/control-plane/receipt)
        (import: :poo-flow/modules/workflow/control-plane/task)
        (import: :poo-flow/modules/workflow/control-plane/flow-strand)
        (import: :poo-flow/modules/workflow/control-plane/flow)
        (import: :poo-flow/modules/workflow/control-plane/flow-syntax)
        (import: :poo-flow/modules/workflow/control-plane/plan)
        (import: :poo-flow/modules/workflow/control-plane/strategy)
        (import: :poo-flow/modules/workflow/control-plane/policy)
        (import: :poo-flow/modules/workflow/control-plane/runtime-protocol)
        (import: :poo-flow/modules/workflow/control-plane/runtime-command-invocation)
        (import: :poo-flow/modules/workflow/control-plane/runtime-command-descriptor)
        (import: :poo-flow/modules/workflow/control-plane/runtime-adapter)
        (import: :poo-flow/modules/workflow/control-plane/agent-harness)
        (import: :poo-flow/modules/workflow/control-plane/replay)
        (import: :poo-flow/modules/workflow/control-plane/runner)
        (import: :poo-flow/modules/workflow/control-plane/config))
