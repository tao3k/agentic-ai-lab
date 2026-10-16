;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session-owned declaration and case syntax.
;;; Invariant: syntax lowers through session functions and the single module
;;; selection contract without importing the user-interface aggregate.

(import (only-in :clan/poo/object object<-alist)
        (only-in :poo-flow/modules/workflow/scenario/configuration/selection-policy
                 poo-flow-product-use-module)
        "funs.ss"
        :poo-flow/modules/ai-agentic-context/features/memory/durable/policy
        :poo-flow/modules/session/agent
        :poo-flow/modules/session/agent-param
        :poo-flow/modules/session/communication
        :poo-flow/modules/session/materialization
        :poo-flow/modules/session/objects
        :poo-flow/modules/session/policy
        :poo-flow/modules/session/policy-validation
        :poo-flow/modules/session/registry
        :poo-flow/modules/session/selector
        :poo-flow/modules/session/transform
        :poo-flow/modules/session/config-session-syntax
        :poo-flow/modules/session/config-policy-syntax)

(export (import: "funs.ss")
        (import: :poo-flow/modules/ai-agentic-context/features/memory/durable/policy)
        (import: :poo-flow/modules/session/agent)
        (import: :poo-flow/modules/session/agent-param)
        (import: :poo-flow/modules/session/communication)
        (import: :poo-flow/modules/session/materialization)
        (import: :poo-flow/modules/session/objects)
        (import: :poo-flow/modules/session/policy)
        (import: :poo-flow/modules/session/policy-validation)
        (import: :poo-flow/modules/session/registry)
        (import: :poo-flow/modules/session/selector)
        (import: :poo-flow/modules/session/transform)
        (import: :poo-flow/modules/session/config-session-syntax)
        (import: :poo-flow/modules/session/config-policy-syntax)
        poo-flow-session-cases)

(defsyntax (poo-flow-session-cases stx)
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
        (poo-flow-product-use-module
         'session
         (poo-flow-session-poo-config-flags
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
        (poo-flow-product-use-module
         'session
         (poo-flow-session-poo-config-flags
          (list case-name ...)
          '(:config
            (session-case case-name
              (metadata metadata-entry ...)
              (objects (object-name object-expr) ...)
              (rows row-expr ...))
            ...))))))))
