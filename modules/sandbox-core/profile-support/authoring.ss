;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile object row authoring diagnostics.

(import :gerbil/core
        (only-in :clan/poo/object .def .o .ref .slot? object?)
        :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/sandbox-core/shared-object
        :agentic-ai-lab/modules/agent-sandbox/config
        (only-in :agentic-ai-lab/modules/agent-sandbox/profile-validation
                 agent-sandbox-profile-resource-policy-filesystem-entry?
                 agent-sandbox-profile-resource-policy-filesystem-diagnostics)
        :agentic-ai-lab/modules/sandbox-core/resource-contract
        :agentic-ai-lab/modules/sandbox-core/profile-support/projection-syntax
        :agentic-ai-lab/modules/sandbox-core/profile-support/prototype)

(export agentic-ai-lab-sandbox-profile-object-row-slot
        agentic-ai-lab-sandbox-profile-object-row-operator?
        agentic-ai-lab-sandbox-profile-object-row-operator
        agentic-ai-lab-sandbox-profile-object-row-value
        agentic-ai-lab-sandbox-profile-object-authoring-diagnostic
        agentic-ai-lab-sandbox-profile-object-row-contains-symbol?
        agentic-ai-lab-sandbox-profile-object-runtime-executed-true?
        agentic-ai-lab-sandbox-profile-object-row-value/default
        agentic-ai-lab-sandbox-profile-object-row-authoring-diagnostics
        agentic-ai-lab-sandbox-profile-object-authoring-diagnostics
        agentic-ai-lab-sandbox-profile-object-backend-row?
        agentic-ai-lab-sandbox-profile-object-row-field
        agentic-ai-lab-sandbox-profile-object-row-merge)

;;; Profile row aliases keep the authoring surface small while the backend
;;; object uses canonical sandbox-core field names.
;; : (-> Symbol MaybeSymbol)
(def (agentic-ai-lab-sandbox-profile-object-row-slot row-key)
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
(def (agentic-ai-lab-sandbox-profile-object-row-operator? value)
  (or (eq? value ':override)
      (eq? value ':append)
      (eq? value ':prepend)
      (eq? value ':remove)))

;;; Operator lookup is intentionally shallow: it reads only the second cell of
;;; a user row and leaves field validity to object-contract validation.
;; : (-> SandboxProfileForm MaybeSandboxProfileRowOperator)
(def (agentic-ai-lab-sandbox-profile-object-row-operator row)
  (let (tail (if (and row (pair? row)) (cdr row) '()))
    (if (and (pair? tail)
             (agentic-ai-lab-sandbox-profile-object-row-operator? (car tail)))
      (car tail)
      #f)))

;;; Row payload extraction strips the optional merge operator but preserves
;;; declaration order for append/prepend/remove semantics.
;; : (-> SandboxProfileForm [Value])
(def (agentic-ai-lab-sandbox-profile-object-row-value row)
  (let* ((tail (cdr row))
         (operator (agentic-ai-lab-sandbox-profile-object-row-operator row)))
    (if operator (cdr tail) tail)))

;;; Authoring diagnostics are report-only facts for enforcing the POO-native
;;; programming contract. They do not reject rows; structural validation below
;;; remains the hard gate before POO extension.
;; : (-> Symbol SandboxProfileForm Alist ValidationError)
(def (agentic-ai-lab-sandbox-profile-object-authoring-diagnostic code row payload)
  (agentic-ai-lab-sandbox-profile-field-rows/tail
   payload
   (field 'profile-row)
   (code code)
   (row row)))

;;; Boundary: sandbox profile object row contains symbol predicate is the
;;; policy-visible edge for sandbox, core behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> Value Symbol Boolean)
(def (agentic-ai-lab-sandbox-profile-object-row-contains-symbol? value target)
  (cond
   ((eq? value target) #t)
   ((pair? value)
    (or (agentic-ai-lab-sandbox-profile-object-row-contains-symbol? (car value)
                                                              target)
        (agentic-ai-lab-sandbox-profile-object-row-contains-symbol? (cdr value)
                                                              target)))
   (else #f)))

;; : (-> SandboxProfileDatum Boolean)
;; | type SandboxProfileDatum = (U Pair Symbol Boolean String Integer)
(def (agentic-ai-lab-sandbox-profile-object-runtime-executed-true? value)
  (cond
   ((not (pair? value)) #f)
   ((and (pair? (car value))
         (eq? (caar value) 'runtime-executed)
         (eq? (cdar value) #t))
    #t)
   (else
    (or (agentic-ai-lab-sandbox-profile-object-runtime-executed-true? (car value))
        (agentic-ai-lab-sandbox-profile-object-runtime-executed-true? (cdr value))))))

;;; Row authoring diagnostics turn gerbil-poo best practices into inspectable
;;; facts: row operators are advanced escape hatches, raw compute hooks are not
;;; a user interface, and runtime-executed markers must remain report-only.
;; : (-> SandboxProfileForm Value)
(def (agentic-ai-lab-sandbox-profile-object-row-value/default row)
  (if (and row (pair? row))
    (agentic-ai-lab-sandbox-profile-object-row-value row)
    row))

;;; Boundary: sandbox profile object row authoring diagnostics is the policy-
;;; visible edge for sandbox, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooModuleObject SandboxProfileForm [ValidationError])
(def (agentic-ai-lab-sandbox-profile-object-row-authoring-diagnostics
      profile-object
      row)
  (let* ((field (agentic-ai-lab-sandbox-profile-object-row-field profile-object row))
         (slot (and field (yuanxu-module-field-contract-identity field)))
         (operator (and (pair? row)
                        (agentic-ai-lab-sandbox-profile-object-row-operator row)))
         (value (agentic-ai-lab-sandbox-profile-object-row-value/default row)))
    (agentic-ai-lab-sandbox-profile-rows/tail
     (if operator
       (list
        (agentic-ai-lab-sandbox-profile-object-authoring-diagnostic
         'advanced-row-operator
         row
         (agentic-ai-lab-sandbox-profile-field-rows
          (slot slot)
          (operator operator)
          (recommendation 'named-prototype-extension))))
       '())
     (agentic-ai-lab-sandbox-profile-rows/tail
      (if (or (agentic-ai-lab-sandbox-profile-object-row-contains-symbol? row
                                                                    ':compute)
              (agentic-ai-lab-sandbox-profile-object-row-contains-symbol? row
                                                                    '$computed-slot-spec)
              (agentic-ai-lab-sandbox-profile-object-row-contains-symbol? row
                                                                    'lambda))
        (list
         (agentic-ai-lab-sandbox-profile-object-authoring-diagnostic
          'raw-compute-hook
          row
          (agentic-ai-lab-sandbox-profile-field-rows
           (slot slot)
           (recommendation 'poo-slot-operator-or-helper))))
        '())
      (if (agentic-ai-lab-sandbox-profile-object-runtime-executed-true? value)
        (list
         (agentic-ai-lab-sandbox-profile-object-authoring-diagnostic
          'runtime-executed-marker
          row
          (agentic-ai-lab-sandbox-profile-field-rows
           (slot slot)
           (expected '#f))))
        '())))))

;;; Boundary: sandbox profile object authoring diagnostics is the policy-
;;; visible edge for sandbox, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooModuleObject [SandboxProfileForm] [ValidationError])
(def (agentic-ai-lab-sandbox-profile-object-authoring-diagnostics profile-object
                                                            forms)
  (cond
   ((null? forms) '())
   ((not (pair? forms)) '())
   (else
    (agentic-ai-lab-sandbox-profile-rows/tail
     (agentic-ai-lab-sandbox-profile-object-row-authoring-diagnostics
      profile-object
      (car forms))
     (agentic-ai-lab-sandbox-profile-object-authoring-diagnostics
      profile-object
      (cdr forms))))))

;;; Backend rows are rejected here because backend kind/ref come from the
;;; selected module object, not from user profile rows.
;; : (-> SandboxProfileForm Boolean)
(def (agentic-ai-lab-sandbox-profile-object-backend-row? row)
  (and (pair? row)
       (eq? (car row) 'backend)))

;;; Row-field resolution is the contract gate: unknown row names never become
;;; POO prototype slots, even if their payload shape looks list-like.
;; : (-> PooModuleObject SandboxProfileForm MaybePooModuleFieldContract)
(def (agentic-ai-lab-sandbox-profile-object-row-field profile-object row)
  (if (and (pair? row) (symbol? (car row)))
    (let (slot (agentic-ai-lab-sandbox-profile-object-row-slot (car row)))
      (and slot
           (yuanxu-module-object-field profile-object slot)))
    #f))

;;; User-supplied merge operators override the field default only for this row;
;;; backend objects keep their declared merge strategy for later rows.
;; : (-> MaybeSymbol PooModuleFieldContract Symbol)
(def (agentic-ai-lab-sandbox-profile-object-row-merge operator field)
  (cond
   ((eq? operator ':override) 'override)
   ((eq? operator ':append) 'append)
   ((eq? operator ':prepend) 'prepend)
   ((eq? operator ':remove) 'remove)
   (else
    (yuanxu-module-field-contract-merge field))))
