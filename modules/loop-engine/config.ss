;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine configuration facade for existing config consumers.
;;; Invariant: interface.ss is the sole public module entrypoint; this role
;;; never imports outward through interface.ss.

(import (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy
                 agentic-ai-lab-module-configs)
        "core.ss"
        "policy-extension.ss"
        "runtime.ss"
        "runtime-projection.ss")

(export agentic-ai-lab-loop-engine-configs
        (import: "core.ss")
        (import: "policy-extension.ss")
        (import: "runtime.ss")
        (import: "runtime-projection.ss"))

;;; Module-owned user syntax delegates to the one generic config lowering.
(defsyntax (agentic-ai-lab-loop-engine-configs stx)
  (syntax-case stx ()
    ((_ config-form ...)
     (syntax
      (agentic-ai-lab-module-configs
       loop-engine
       agentic-ai-lab-user-loop-engine-poo-config-flags
       (quoted :config config-form ...)
       config-form ...)))))
