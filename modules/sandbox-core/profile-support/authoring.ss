;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile object row authoring diagnostics.

(import :gerbil/core
        (only-in :clan/poo/object .def .o .ref .slot? object?)
        :yuanxu/module-system/schema/interface
        :poo-flow/modules/sandbox-core/shared-object
        :poo-flow/modules/agent-sandbox/config
        (only-in :poo-flow/modules/agent-sandbox/profile-validation
                 agent-sandbox-profile-resource-policy-filesystem-entry?
                 agent-sandbox-profile-resource-policy-filesystem-diagnostics)
        :poo-flow/modules/sandbox-core/resource-contract
        :poo-flow/modules/sandbox-core/profile-support/projection-syntax
        :poo-flow/modules/sandbox-core/profile-support/prototype)

(export poo-flow-sandbox-profile-object-row-slot
        poo-flow-sandbox-profile-object-row-operator?
        poo-flow-sandbox-profile-object-row-operator
        poo-flow-sandbox-profile-object-row-value
        poo-flow-sandbox-profile-object-authoring-diagnostic
        poo-flow-sandbox-profile-object-row-contains-symbol?
        poo-flow-sandbox-profile-object-runtime-executed-true?
        poo-flow-sandbox-profile-object-row-value/default
        poo-flow-sandbox-profile-object-row-authoring-diagnostics
        poo-flow-sandbox-profile-object-authoring-diagnostics
        poo-flow-sandbox-profile-object-backend-row?
        poo-flow-sandbox-profile-object-row-field
        poo-flow-sandbox-profile-object-row-merge)

;;; Profile row aliases keep the authoring surface small while the backend
;;; object uses canonical sandbox-core field names.
;; : (-> Symbol MaybeSymbol)
(def (poo-flow-sandbox-profile-object-row-slot row-key)
  (cond
   ((eq? row-key 'network) 'network-policy)
   ((eq? row-key 'capabilities) 'capabilities)
   ((eq? row-key 'resources) 'resource-policy)
   ((eq? row-key 'metadata) 'metadata)
   (else #f)))

;;; Merge operators are explicit row modifiers, not field names. They are
;;; parsed before slot lookup so remove/append can reuse the same field object.
;; : (-> SandboxProfileRowOperatorCandidate Boolean)
;; | SandboxProfileRowOperatorCandidate = Symbol
(def (poo-flow-sandbox-profile-object-row-operator? value)
  (or (eq? value ':override)
      (eq? value ':append)
      (eq? value ':prepend)
      (eq? value ':remove)))

;;; Operator lookup is intentionally shallow: it reads only the second cell of
;;; a user row and leaves field validity to object-contract validation.
;; : (-> SandboxProfileForm MaybeSandboxProfileRowOperator)
(def (poo-flow-sandbox-profile-object-row-operator row)
  (let (tail (if (and row (pair? row)) (cdr row) '()))
    (if (and (pair? tail)
             (poo-flow-sandbox-profile-object-row-operator? (car tail)))
      (car tail)
      #f)))

;;; Row payload extraction strips the optional merge operator but preserves
;;; declaration order for append/prepend/remove semantics.
;; : (-> SandboxProfileForm [Value])
(def (poo-flow-sandbox-profile-object-row-value row)
  (let* ((tail (cdr row))
         (operator (poo-flow-sandbox-profile-object-row-operator row)))
    (if operator (cdr tail) tail)))

;;; Authoring diagnostics are report-only facts for enforcing the POO-native
;;; programming contract. They do not reject rows; structural validation below
;;; remains the hard gate before POO extension.
;; : (-> Symbol SandboxProfileForm Alist ValidationError)
(def (poo-flow-sandbox-profile-object-authoring-diagnostic code row payload)
  (poo-flow-sandbox-profile-field-rows/tail
   payload
   (field 'profile-row)
   (code code)
   (row row)))

;;; Boundary: sandbox profile object row contains symbol predicate is the
;;; policy-visible edge for sandbox, core behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> Value Symbol Boolean)
(def (poo-flow-sandbox-profile-object-row-contains-symbol? value target)
  (cond
   ((eq? value target) #t)
   ((pair? value)
    (or (poo-flow-sandbox-profile-object-row-contains-symbol? (car value)
                                                              target)
        (poo-flow-sandbox-profile-object-row-contains-symbol? (cdr value)
                                                              target)))
   (else #f)))

;; : (-> SandboxProfileDatum Boolean)
;; | type SandboxProfileDatum = (U Pair Symbol Boolean String Integer)
(def (poo-flow-sandbox-profile-object-runtime-executed-true? value)
  (cond
   ((not (pair? value)) #f)
   ((and (pair? (car value))
         (eq? (caar value) 'runtime-executed)
         (eq? (cdar value) #t))
    #t)
   (else
    (or (poo-flow-sandbox-profile-object-runtime-executed-true? (car value))
        (poo-flow-sandbox-profile-object-runtime-executed-true? (cdr value))))))

;;; Row authoring diagnostics turn gerbil-poo best practices into inspectable
;;; facts: row operators are advanced escape hatches, raw compute hooks are not
;;; a user interface, and runtime-executed markers must remain report-only.
;; : (-> SandboxProfileForm Value)
(def (poo-flow-sandbox-profile-object-row-value/default row)
  (if (and row (pair? row))
    (poo-flow-sandbox-profile-object-row-value row)
    row))

;;; Boundary: sandbox profile object row authoring diagnostics is the policy-
;;; visible edge for sandbox, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooModuleObject SandboxProfileForm [ValidationError])
(def (poo-flow-sandbox-profile-object-row-authoring-diagnostics
      profile-object
      row)
  (let* ((field (poo-flow-sandbox-profile-object-row-field profile-object row))
         (slot (and field (yuanxu-module-field-contract-identity field)))
         (operator (and (pair? row)
                        (poo-flow-sandbox-profile-object-row-operator row)))
         (value (poo-flow-sandbox-profile-object-row-value/default row)))
    (poo-flow-sandbox-profile-rows/tail
     (if operator
       (list
        (poo-flow-sandbox-profile-object-authoring-diagnostic
         'advanced-row-operator
         row
         (poo-flow-sandbox-profile-field-rows
          (slot slot)
          (operator operator)
          (recommendation 'named-prototype-extension))))
       '())
     (poo-flow-sandbox-profile-rows/tail
      (if (or (poo-flow-sandbox-profile-object-row-contains-symbol? row
                                                                    ':compute)
              (poo-flow-sandbox-profile-object-row-contains-symbol? row
                                                                    '$computed-slot-spec)
              (poo-flow-sandbox-profile-object-row-contains-symbol? row
                                                                    'lambda))
        (list
         (poo-flow-sandbox-profile-object-authoring-diagnostic
          'raw-compute-hook
          row
          (poo-flow-sandbox-profile-field-rows
           (slot slot)
           (recommendation 'poo-slot-operator-or-helper))))
        '())
      (if (poo-flow-sandbox-profile-object-runtime-executed-true? value)
        (list
         (poo-flow-sandbox-profile-object-authoring-diagnostic
          'runtime-executed-marker
          row
          (poo-flow-sandbox-profile-field-rows
           (slot slot)
           (expected '#f))))
        '())))))

;;; Boundary: sandbox profile object authoring diagnostics is the policy-
;;; visible edge for sandbox, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooModuleObject [SandboxProfileForm] [ValidationError])
(def (poo-flow-sandbox-profile-object-authoring-diagnostics profile-object
                                                            forms)
  (cond
   ((null? forms) '())
   ((not (pair? forms)) '())
   (else
    (poo-flow-sandbox-profile-rows/tail
     (poo-flow-sandbox-profile-object-row-authoring-diagnostics
      profile-object
      (car forms))
     (poo-flow-sandbox-profile-object-authoring-diagnostics
      profile-object
      (cdr forms))))))

;;; Backend rows are rejected here because backend kind/ref come from the
;;; selected module object, not from user profile rows.
;; : (-> SandboxProfileForm Boolean)
(def (poo-flow-sandbox-profile-object-backend-row? row)
  (and (pair? row)
       (eq? (car row) 'backend)))

;;; Row-field resolution is the contract gate: unknown row names never become
;;; POO prototype slots, even if their payload shape looks list-like.
;; : (-> PooModuleObject SandboxProfileForm MaybePooModuleFieldContract)
(def (poo-flow-sandbox-profile-object-row-field profile-object row)
  (if (and (pair? row) (symbol? (car row)))
    (let (slot (poo-flow-sandbox-profile-object-row-slot (car row)))
      (and slot
           (yuanxu-module-object-field profile-object slot)))
    #f))

;;; User-supplied merge operators override the field default only for this row;
;;; backend objects keep their declared merge strategy for later rows.
;; : (-> MaybeSymbol PooModuleFieldContract Symbol)
(def (poo-flow-sandbox-profile-object-row-merge operator field)
  (cond
   ((eq? operator ':override) 'override)
   ((eq? operator ':append) 'append)
   ((eq? operator ':prepend) 'prepend)
   ((eq? operator ':remove) 'remove)
   (else
    (yuanxu-module-field-contract-merge field))))
