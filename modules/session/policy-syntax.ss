;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: hygienic macros for repeated session policy object families.
;;; Invariant: macros expand to ordinary public constructors over POO-native
;;; session policy objects. They are internal generation helpers, not a user DSL.

(export defpoo-session-policy-family)

;; : (-> List List List)
(def (agentic-ai-lab-session-policy-rows/tail rows tail)
  (foldr cons tail rows))

;; defpoo-session-policy-family
;; : (-> Syntax Syntax)
;; | doc m%
;;   Generate a session policy constructor family while keeping runtime
;;   validation in the generated ordinary function.
;;   # Examples
;;   ```scheme
;;   (defpoo-session-policy-family make-policy object (kind k) ...)
;;   ;; => policy constructor definitions
;;   ```
(defrules defpoo-session-policy-family
  (kind schema default-action scope-ref parameters slots validate
        emit scope-ref-value)
  ((_ constructor policy-object
      (kind kind-expr)
      (schema schema-expr)
      (default-action default-action-expr)
      (scope-ref scope-ref-expr)
      (parameters (policy-name arg ... . maybe-metadata))
      (slots ((slot-key slot-value) ...))
      (validate validation ...))
   (defpoo-session-policy-family
    (emit constructor policy-object
      (kind kind-expr)
      (schema schema-expr)
      (default-action default-action-expr)
      (parameters (policy-name arg ... . maybe-metadata))
      (scope-ref-value scope-ref-expr)
      (slots ((slot-key slot-value) ...))
      (validate validation ...))))
  ((_ constructor policy-object
      (kind kind-expr)
      (schema schema-expr)
      (default-action default-action-expr)
      (parameters (policy-name scope-ref-param arg ... . maybe-metadata))
      (slots ((slot-key slot-value) ...))
      (validate validation ...))
   (defpoo-session-policy-family
    (emit constructor policy-object
      (kind kind-expr)
      (schema schema-expr)
      (default-action default-action-expr)
      (parameters
       (policy-name scope-ref-param arg ... . maybe-metadata))
      (scope-ref-value scope-ref-param)
      (slots ((slot-key slot-value) ...))
      (validate validation ...))))
  ((_ (emit constructor policy-object
       (kind kind-expr)
       (schema schema-expr)
       (default-action default-action-expr)
       (parameters (policy-name arg ... . maybe-metadata))
       (scope-ref-value scope-ref-expr)
       (slots ((slot-key slot-value) ...))
       (validate validation ...)))
   ;; Engineering note: policy-sensitive helpers in this owner keep explicit
   ;; contracts adjacent to definitions so downstream reports stay actionable.
   ;; : (-> Any Any)
   (def (constructor policy-name arg ... . maybe-metadata)
     validation ...
     (apply policy-object
            kind-expr
            schema-expr
            policy-name
            scope-ref-expr
            default-action-expr
            (list (cons slot-key slot-value) ...)
            maybe-metadata))))
