;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: stable import surface for memory-core public specs.

(import :tao3k/agentic-ai-lab/modules/ai-agentic-context/features/memory/config
        (only-in :tao3k/agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy
                 agentic-ai-lab-module-configs))

(export agentic-ai-lab-memory-configs
        (import: :tao3k/agentic-ai-lab/modules/ai-agentic-context/features/memory/config))

(defsyntax (agentic-ai-lab-memory-configs stx)
  (syntax-case stx ()
    ((_ config-form ...)
     (syntax
      (agentic-ai-lab-module-configs
       ai-agentic-context
       agentic-ai-lab-ai-agentic-context-memory-poo-config-flags
       (quoted :config config-form ...)
       config-form ...)))))
