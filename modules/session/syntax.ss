;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session-owned declaration and case syntax.
;;; Invariant: syntax lowers through session functions and the single module
;;; selection contract without importing the user-interface aggregate.

(import (only-in :clan/poo/object object<-alist)
        (only-in :tao3k/agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy
                 agentic-ai-lab-product-use-module)
        "funs.ss"
        :tao3k/agentic-ai-lab/modules/session/durable-policy
        :tao3k/agentic-ai-lab/modules/session/agent
        :tao3k/agentic-ai-lab/modules/session/agent-param
        :tao3k/agentic-ai-lab/modules/session/communication
        :tao3k/agentic-ai-lab/modules/session/materialization
        :tao3k/agentic-ai-lab/modules/session/objects
        :tao3k/agentic-ai-lab/modules/session/policy
        :tao3k/agentic-ai-lab/modules/session/policy-validation
        :tao3k/agentic-ai-lab/modules/session/registry
        :tao3k/agentic-ai-lab/modules/session/selector
        :tao3k/agentic-ai-lab/modules/session/transform
        :tao3k/agentic-ai-lab/modules/session/config-session-syntax
        :tao3k/agentic-ai-lab/modules/session/config-policy-syntax)

(export (import: "funs.ss")
        (import: :tao3k/agentic-ai-lab/modules/session/durable-policy)
        (import: :tao3k/agentic-ai-lab/modules/session/agent)
        (import: :tao3k/agentic-ai-lab/modules/session/agent-param)
        (import: :tao3k/agentic-ai-lab/modules/session/communication)
        (import: :tao3k/agentic-ai-lab/modules/session/materialization)
        (import: :tao3k/agentic-ai-lab/modules/session/objects)
        (import: :tao3k/agentic-ai-lab/modules/session/policy)
        (import: :tao3k/agentic-ai-lab/modules/session/policy-validation)
        (import: :tao3k/agentic-ai-lab/modules/session/registry)
        (import: :tao3k/agentic-ai-lab/modules/session/selector)
        (import: :tao3k/agentic-ai-lab/modules/session/transform)
        (import: :tao3k/agentic-ai-lab/modules/session/config-session-syntax)
        (import: :tao3k/agentic-ai-lab/modules/session/config-policy-syntax)
        agentic-ai-lab-session-cases)

(defsyntax (agentic-ai-lab-session-cases stx)
  (syntax-case stx (session-case metadata objects rows row-groups)
    ((_ (session-case case-name
          (metadata metadata-entry ...)
          (objects (object-name object-expr) ...)
          (rows row-expr ...)
          (row-groups row-group-expr ...))
        ...)
     (syntax
      (let* ((case-name
              (let* ((object-name object-expr) ...)
                (object<-alist
                 (list
                  (cons 'rows
                        (append (list row-expr ...)
                                row-group-expr ...
                                '()))
                  (cons 'metadata '(metadata-entry ...)))
                 supers: session-config)))
             ...)
        (agentic-ai-lab-product-use-module
         'session
         (agentic-ai-lab-session-poo-config-flags
          (list case-name ...)
          '(:config
            (session-case case-name
              (metadata metadata-entry ...)
              (objects (object-name object-expr) ...)
              (rows row-expr ...)
              (row-groups row-group-expr ...))
            ...))))))
    ((_ (session-case case-name
          (metadata metadata-entry ...)
          (objects (object-name object-expr) ...)
          (rows row-expr ...))
        ...)
     (syntax
      (let* ((case-name
              (let* ((object-name object-expr) ...)
                (object<-alist
                 (list
                  (cons 'rows (list row-expr ...))
                  (cons 'metadata '(metadata-entry ...)))
                 supers: session-config)))
             ...)
        (agentic-ai-lab-product-use-module
         'session
         (agentic-ai-lab-session-poo-config-flags
          (list case-name ...)
          '(:config
            (session-case case-name
              (metadata metadata-entry ...)
              (objects (object-name object-expr) ...)
              (rows row-expr ...))
            ...))))))))
