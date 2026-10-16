;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: human audit loops project review decisions over loop facts.
;;; Invariant: this module never edits config, schedules loops, or executes runtime work.

(import :core/composition/roles
        (only-in :clan/poo/object .o .ref .slot? object?)
        :poo-flow/modules/workflow/control-plane/roles
        :poo-flow/modules/workflow/control-plane/failure
        :core/object-family/role-syntax
        :poo-flow/modules/workflow/control-plane/agent-harness
        (only-in "./governor.ss"
                 loop-governor?
                 loop-governor->contract/validated
                 loop-governor-human-node-role
                 loop-governor-node->contract
                 loop-governor-validation-errors)
        (only-in :core/module-system/schema/slot-contracts
                 poo-flow-contract-check-slot!
                 poo-flow-contract-slot
                 poo-flow-contract-value-type
                 poo-flow-native-contract
                 poo-flow-native-contract->alist))

(export +loop-human-audit-schema+
        +loop-human-audit-decisions+
        +loop-human-audit-default-review-policy+
        +loop-human-audit-slot-contracts+
        +loop-human-audit-type-contract+
        loop-human-governor-node-role
        loop-human-audit-role
        loop-human-review-role
        loop-human-decision-role
        loop-human-audit-prototype
        make-loop-human-audit
        loop-human-audit?
        loop-human-audit-slot
        loop-human-audit-name
        loop-human-audit-governor
        loop-human-audit-state-facts
        loop-human-audit-decisions
        loop-human-audit-review-policy
        loop-human-audit-governor-derived?
        loop-human-audit-governance-node-kind
        loop-human-audit-human-intervention?
        loop-human-audit-control-owner
        loop-human-audit-decision-owner
        loop-human-audit-execution-owner
        loop-human-audit-metadata
        loop-human-audit-alist?
        loop-human-audit-list-of?
        loop-human-audit-decision-entry?
        loop-human-audit-decision-list?
        loop-human-audit-type-contract->alist
        loop-human-audit-check-slot!
        loop-human-audit-require-slots!
        loop-human-audit-decision?
        loop-human-audit-decision-ref
        loop-human-audit-review-items
        loop-human-audit-validation-errors
        validate-loop-human-audit
        loop-human-audit->agent-operation
        loop-human-audit->runtime-snapshot
        loop-human-audit->contract)

(import :poo-flow/modules/loop-engine/control/human-audit-value-support)

;;; Boundary: schema names the human audit review contract.
;; : (-> Unit Symbol)
(def +loop-human-audit-schema+ 'poo-flow.loop-human-audit.v1)

;;; Boundary: decision values are review state, not config comments.
;; : (-> Unit [Symbol])
(def +loop-human-audit-decisions+
  '(pending approved rejected escalated changes-requested))

;;; Boundary: default policy says the surface is review-only.
;; : (-> Unit Alist)
(def +loop-human-audit-default-review-policy+
  '((mode . review-loop)
    (governor-derived . #t)
    (governance-node-kind . human)
    (requires-human . #t)
    (records-decisions . #t)
    (mutates-config . #f)
    (executes-runtime . #f)))

;;; Boundary: human audit is a governor-derived node in the governance chain.
;;; It reuses POO/C4 governor policy shape while marking the node as human.
;; : (-> Unit Role)
(def loop-human-governor-node-role
  (.o (:: @ loop-governor-human-node-role)
      (name 'loop-human-governor-node)
      (kind 'loop-control)
      (responsibility 'human-node-governance)
      (runtime-owner 'gerbil)
      (loop-capability 'human-governor-node)
      (governance-node-kind 'human)
      (governance-responsibility 'human-audit)
      (human-intervention #t)))

;;; Boundary: root audit role owns true human intervention.
;;; It is a governor-derived human node, not an agent judge.
;; : (-> Unit Role)
(def loop-human-audit-role
  (.o (:: @ loop-human-governor-node-role)
      (name 'loop-human-audit)
      (kind 'loop-control)
      (responsibility 'human-intervention-loop)
      (runtime-owner 'gerbil)
      (loop-capability 'human-audit-review)))

;;; Boundary: review role projects human review items from supplied facts.
;; : (-> Unit Role)
(def loop-human-review-role
  (.o (:: @ loop-human-audit-role)
      (name 'loop-human-review)
      (kind 'loop-policy)
      (responsibility 'review-item-projection)
      (loop-policy-slot 'review-items)))

;;; Boundary: decision role records human outcomes as data.
;; : (-> Unit Role)
(def loop-human-decision-role
  (.o (:: @ loop-human-audit-role)
      (name 'loop-human-decision)
      (kind 'loop-policy)
      (responsibility 'approval-rejection-escalation)
      (loop-policy-slot 'decisions)))

;;; Prototype slots keep audit state separate from user config.
;; : (-> Unit LoopHumanAuditPrototype)
(def loop-human-audit-prototype
  (poo-core-role-object
   (slots ((schema +loop-human-audit-schema+)
           (kind 'loop-human-audit)
           (name #f)
           (governor #f)
           (governor-contract #f)
           (state-facts '())
           (decisions '())
           (review-policy +loop-human-audit-default-review-policy+)
           (governor-derived #t)
           (governance-node-kind 'human)
           (governance-responsibility 'human-audit)
           (human-intervention #t)
           (control-owner 'gerbil)
           (decision-owner 'human)
           (execution-owner 'marlin-agent-core)
           (metadata '())))
   (supers loop-human-decision-role
           loop-human-review-role
           loop-human-audit-role)))

;; : (-> Alist Alist Alist)
(def (loop-human-audit-slot-rows/tail rows tail)
  (foldr cons tail rows))

;; : (-> Symbol LoopGovernor [Alist] [Alist] Alist Alist)
(def (loop-human-audit-slot-rows name
                                 governor
                                 state-facts
                                 decisions
                                 overrides)
  (loop-human-audit-slot-rows/tail
   (list
    (cons 'name name)
    (cons 'governor governor)
    (cons 'state-facts state-facts)
    (cons 'decisions decisions))
   overrides))

;;; Constructor binds one governor view to human decisions.
;;; Decisions are alists of =(pattern . decision)=.
;; : (-> Symbol LoopGovernor [Alist] [Alist] [Alist] LoopHumanAudit)
(def (make-loop-human-audit name governor state-facts decisions . maybe-overrides)
  (poo-core-role-object
   (slot-rows
    (loop-human-audit-slot-rows
     name
     governor
     state-facts
     decisions
     (if (null? maybe-overrides) '() (car maybe-overrides))))
   (supers loop-human-audit-prototype)))

;; : (-> LoopHumanAuditCandidate Boolean)
(def (loop-human-audit? audit)
  (and (object? audit)
       (eq? (loop-human-audit-slot audit 'kind #f)
            'loop-human-audit)))

;; : (-> LoopHumanAudit Symbol Value Value)
(def (loop-human-audit-slot audit slot default)
  (role-slot/default audit slot default))

;; : (-> PooFlowValue Boolean)
(def (loop-human-audit-decision-entry? value)
  (and (pair? value)
       (symbol? (car value))
       (loop-human-audit-decision? (cdr value))))

;; : (-> PooFlowValue Boolean)
(def (loop-human-audit-decision-list? value)
  (loop-human-audit-list-of? loop-human-audit-decision-entry? value))

;; loop-human-audit-type-contract->alist
;;   : (-> Unit Alist)
;;   | doc m%
;;       Project the structured contract for human audit loop POO objects.
;;       # Examples
;;       (loop-human-audit-type-contract->alist)
;;       # Result
;;       An alist representation for doctor, graph explanation, and manifests.
;;     %
(def (loop-human-audit-type-contract->alist)
  (poo-flow-native-contract->alist +loop-human-audit-type-contract+))

;; loop-human-audit-check-slot!
;;   : (-> PooFlowSlotContract PooFlowValue PooFlowValue)
;;   | doc m%
;;       Execute one human-audit slot contract through utilities.
;;       # Examples
;;       (loop-human-audit-check-slot! +loop-human-audit-name-contract+ 'audit)
;;       # Result
;;       The original value when valid; otherwise raises a contract error.
;;     %
(def (loop-human-audit-check-slot! contract value)
  (poo-flow-contract-check-slot! contract value))

;; loop-human-audit-require-slots!
;;   : (-> Symbol LoopGovernor MaybeAlist [Alist] [Alist] Alist Boolean Symbol Boolean Symbol Symbol Symbol Alist Boolean)
;;   | doc m%
;;       Enforce generated slot contracts for the human audit loop boundary.
;;       # Examples
;;       (loop-human-audit-require-slots!
;;        'audit governor #f state-facts decisions policy #t 'human #t 'gerbil 'human 'marlin-agent-core '())
;;       # Result
;;       #t when every human audit slot satisfies its generated contract.
;;     %
(def (loop-human-audit-require-slots! name governor governor-contract state-facts decisions review-policy governor-derived governance-node-kind human-intervention control-owner decision-owner execution-owner metadata)
  (loop-human-audit-check-slot! +loop-human-audit-name-contract+ name)
  (loop-human-audit-check-slot! +loop-human-audit-governor-contract+ governor)
  (loop-human-audit-check-slot!
   +loop-human-audit-governor-contract-slot-contract+
   governor-contract)
  (loop-human-audit-check-slot!
   +loop-human-audit-state-facts-contract+
   state-facts)
  (loop-human-audit-check-slot! +loop-human-audit-decisions-contract+ decisions)
  (loop-human-audit-check-slot!
   +loop-human-audit-review-policy-contract+
   review-policy)
  (loop-human-audit-check-slot!
   +loop-human-audit-governor-derived-contract+
   governor-derived)
  (loop-human-audit-check-slot!
   +loop-human-audit-governance-node-kind-contract+
   governance-node-kind)
  (loop-human-audit-check-slot!
   +loop-human-audit-human-intervention-contract+
   human-intervention)
  (loop-human-audit-check-slot!
   +loop-human-audit-control-owner-contract+
   control-owner)
  (loop-human-audit-check-slot!
   +loop-human-audit-decision-owner-contract+
   decision-owner)
  (loop-human-audit-check-slot!
   +loop-human-audit-execution-owner-contract+
   execution-owner)
  (loop-human-audit-check-slot! +loop-human-audit-metadata-contract+ metadata)
  #t)

;;; Boundary: loop human audit filter is the policy-visible edge for loop
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Predicate [Value] [Value])

;; : (-> LoopHumanAudit Symbol)

;; : (-> LoopHumanAudit LoopGovernor)

;; : (-> LoopHumanAudit MaybeAlist)

;; : (-> LoopHumanAudit [Alist])

;; : (-> LoopHumanAudit [Alist])

;; : (-> LoopHumanAudit Alist)

;; : (-> LoopHumanAudit Boolean)

;; : (-> LoopHumanAudit Symbol)

;; : (-> LoopHumanAudit Boolean)

;; : (-> LoopHumanAudit Symbol)

;; : (-> LoopHumanAudit Symbol)
(def (loop-human-audit-decision-owner audit)
  (loop-human-audit-slot audit 'decision-owner #f))

;; : (-> LoopHumanAudit Symbol)
(def (loop-human-audit-execution-owner audit)
  (loop-human-audit-slot audit 'execution-owner #f))

;; : (-> LoopHumanAudit Alist)
(def (loop-human-audit-metadata audit)
  (loop-human-audit-slot audit 'metadata '()))

;; : (-> Symbol Boolean)

;;; Boundary: loop human audit decision ref is the policy-visible edge for loop
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> LoopHumanAudit Symbol Symbol Symbol)

;; : (-> Symbol Symbol Value Symbol Alist)

;; : (-> LoopHumanAudit Alist Symbol Alist)

;; : (-> LoopHumanAudit Symbol Alist)

;;; Review items combine actionable recommendations and blocked inbox facts.
;;; This is the human loop surface; it does not mutate config or state.
;; : (-> LoopHumanAudit [Alist])

;;; Boundary: loop human audit review items from governor contract is the
;;; policy-visible edge for loop behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> LoopHumanAudit Alist [Alist])

;; : (-> LoopHumanAudit [Symbol] [Alist] [Alist])

;; : (-> LoopHumanAudit [Alist] [Alist] [Alist])

;;; Boundary: loop human audit required field error is the policy-visible edge
;;; for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol Value [ValidationError])
(def (loop-human-audit-required-field-error/tail field value tail)
  (if value
    tail
    (cons (list (cons 'field field)
                (cons 'code 'required))
          tail)))

;; : (-> Symbol Value [ValidationError])
(def (loop-human-audit-required-field-error field value)
  (loop-human-audit-required-field-error/tail field value '()))

;;; Boundary: loop human audit field validation error unless is the policy-
;;; visible edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Boolean Symbol Symbol FieldValue [ValidationError])
(def (loop-human-audit-field-validation-error/unless/tail valid?
                                                        field
                                                        code
                                                        value
                                                        tail)
  (if valid?
    tail
    (cons (list (cons 'field field)
                (cons 'code code)
                (cons 'value value))
          tail)))

;; : (-> Boolean Symbol Symbol FieldValue [ValidationError])
(def (loop-human-audit-field-validation-error/unless valid? field code value)
  (loop-human-audit-field-validation-error/unless/tail
   valid?
   field
   code
   value
   '()))

;;; Boundary: loop human audit governor validation errors is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> LoopGovernor [ValidationError])
(def (loop-human-audit-governor-validation-errors governor)
  (if (loop-governor? governor)
    (loop-governor-validation-errors governor)
    (list (list (cons 'field 'governor)
                (cons 'code 'not-loop-governor)))))

;;; Boundary: loop human audit governor contract validation errors is the
;;; policy-visible edge for loop behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> LoopGovernor [ValidationError])
(def (loop-human-audit-governor-contract-validation-errors governor)
  (if (loop-governor? governor)
    '()
    (list (list (cons 'field 'governor)
                (cons 'code 'not-loop-governor)))))

;;; Boundary: loop human audit governor contract field validation errors is the
;;; policy-visible edge for loop behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> MaybeAlist [ValidationError])
(def (loop-human-audit-governor-contract-field-validation-errors contract)
  (if (or (not contract) (list? contract))
    '()
    (list (list (cons 'field 'governor-contract)
                (cons 'code 'not-list)
                (cons 'value contract)))))

;;; Boundary: loop human audit decision validation errors is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;;; Boundary: loop human audit decisions field validation errors is the policy-
;;; visible edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [Alist] [ValidationError])
(def (loop-human-audit-decisions-field-validation-errors decisions)
  (if (list? decisions)
    (loop-human-audit-decision-validation-errors decisions)
    (list (list (cons 'field 'decisions)
                (cons 'code 'not-list)
                (cons 'value decisions)))))

;;; Boundary: loop human audit decision validation errors is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [Alist] [ValidationError])
(def (loop-human-audit-decision-validation-errors decisions)
  (cond
   ((null? decisions) '())
   ((and (pair? (car decisions))
         (loop-human-audit-decision? (cdar decisions)))
    (loop-human-audit-decision-validation-errors (cdr decisions)))
   (else
    (cons (list (cons 'field 'decisions)
                (cons 'code 'unsupported-decision)
                (cons 'value (car decisions)))
          (loop-human-audit-decision-validation-errors (cdr decisions))))))

;; : (-> [ValidationError] [ValidationError] [ValidationError])
(def (loop-human-audit-errors/tail errors tail)
  (if (null? errors)
    tail
    (cons (car errors)
          (loop-human-audit-errors/tail (cdr errors) tail))))

;;; Boundary: validation keeps audit contracts typed before review projection.
;; : (-> LoopHumanAudit [ValidationError])
(def (loop-human-audit-validation-errors audit)
  (if (loop-human-audit? audit)
    (loop-human-audit-required-field-error/tail
     'name
     (loop-human-audit-name audit)
     (loop-human-audit-errors/tail
      (loop-human-audit-governor-validation-errors
       (loop-human-audit-governor audit))
      (loop-human-audit-errors/tail
       (loop-human-audit-governor-contract-field-validation-errors
        (loop-human-audit-governor-contract audit))
       (loop-human-audit-field-validation-error/unless/tail
        (list? (loop-human-audit-state-facts audit))
        'state-facts
        'not-list
        (loop-human-audit-state-facts audit)
        (loop-human-audit-decisions-field-validation-errors
         (loop-human-audit-decisions audit))))))
    (list '((field . audit) (code . not-loop-human-audit)))))

;;; Boundary: loop human audit validation errors contract facts is the policy-
;;; visible edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> LoopHumanAudit [ValidationError])

;;; Boundary: validate loop human audit is the policy-visible edge for loop
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> LoopHumanAudit LoopHumanAudit)

;;; Boundary: validate loop human audit contract facts is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> LoopHumanAudit LoopHumanAudit)
(def (validate-loop-human-audit/contract-facts audit)
  (let (errors (loop-human-audit-validation-errors/contract-facts audit))
    (if (null? errors)
      audit
      (raise-control-plane-failure
       'loop-human-audit
       'invalid-loop-human-audit
       "invalid loop human audit"
       (list (cons 'errors errors))))))

;;; Decision projection keeps review filtering as data-flow over the policy
;;; table, so adding a decision does not change the contract writer.
;; : (-> LoopHumanAudit Symbol [Symbol])
(include "human-audit-projection-implementation.inc")

;; : (-> [Alist] Symbol [Symbol])

;;; Boundary: loop human audit review items pending predicate is the policy-
;;; visible edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [Alist] Boolean)

;;; Boundary: loop human audit operation status is the policy-visible edge for
;;; loop behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [Alist] Symbol)

;; : (-> LoopHumanAudit Symbol)

;;; Human audit is projected as an agent operation so loop cases can hand the
;;; same inert object family to CLI, UI, or runtime adapters. It is still
;;; review-only data: no runtime work is submitted here.
;; : (-> LoopHumanAudit [Alist] PooFlowAgentOperation)

;; : (-> LoopHumanAudit PooFlowAgentOperation)

;; : (-> LoopHumanAudit [Alist] PooFlowRuntimeSnapshot)

;; : (-> LoopHumanAudit PooFlowRuntimeSnapshot)

;;; Contract projection is the human audit loop review surface.
;;; It records review state without writing config, state, or runtime effects.
;; : (-> LoopHumanAudit Alist Alist)

;;; Boundary: loop human audit to contract is the policy-visible edge for loop
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> LoopHumanAudit Alist)

(def LoopHumanAuditSymbolType
  (poo-flow-contract-value-type 'Symbol symbol? 'Symbol))
(def LoopHumanAuditBooleanType
  (poo-flow-contract-value-type 'Boolean boolean? 'Boolean))
(def LoopHumanAuditAlistType
  (poo-flow-contract-value-type 'Alist loop-human-audit-alist? 'Alist))
(def LoopHumanAuditGovernorType
  (poo-flow-contract-value-type
   'LoopGovernor loop-governor? 'LoopGovernor))
(def LoopHumanAuditMaybeAlistType
  (poo-flow-contract-value-type
   'MaybeAlist loop-human-audit-governor-contract? 'MaybeAlist))
(def LoopHumanAuditStateFactListType
  (poo-flow-contract-value-type
   '[Alist] loop-human-audit-state-fact-list? '[Alist]))
(def LoopHumanAuditDecisionListType
  (poo-flow-contract-value-type
   '[LoopHumanAuditDecision]
   loop-human-audit-decision-list?
   '[LoopHumanAuditDecision]))

(def (loop-human-audit-required-slot key slot value-type)
  (poo-flow-contract-slot key slot value-type #t '()))

(def +loop-human-audit-name-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/name 'name LoopHumanAuditSymbolType))
(def +loop-human-audit-governor-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/governor 'governor LoopHumanAuditGovernorType))
(def +loop-human-audit-governor-contract-slot-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/governor-contract
   'governor-contract
   LoopHumanAuditMaybeAlistType))
(def +loop-human-audit-state-facts-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/state-facts
   'state-facts
   LoopHumanAuditStateFactListType))
(def +loop-human-audit-decisions-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/decisions
   'decisions
   LoopHumanAuditDecisionListType))
(def +loop-human-audit-review-policy-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/review-policy 'review-policy LoopHumanAuditAlistType))
(def +loop-human-audit-governor-derived-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/governor-derived
   'governor-derived
   LoopHumanAuditBooleanType))
(def +loop-human-audit-governance-node-kind-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/governance-node-kind
   'governance-node-kind
   LoopHumanAuditSymbolType))
(def +loop-human-audit-human-intervention-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/human-intervention
   'human-intervention
   LoopHumanAuditBooleanType))
(def +loop-human-audit-control-owner-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/control-owner 'control-owner LoopHumanAuditSymbolType))
(def +loop-human-audit-decision-owner-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/decision-owner 'decision-owner LoopHumanAuditSymbolType))
(def +loop-human-audit-execution-owner-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/execution-owner 'execution-owner LoopHumanAuditSymbolType))
(def +loop-human-audit-metadata-contract+
  (loop-human-audit-required-slot
   'loop-human-audit/metadata 'metadata LoopHumanAuditAlistType))

(def +loop-human-audit-slot-contracts+
  (list +loop-human-audit-name-contract+
        +loop-human-audit-governor-contract+
        +loop-human-audit-governor-contract-slot-contract+
        +loop-human-audit-state-facts-contract+
        +loop-human-audit-decisions-contract+
        +loop-human-audit-review-policy-contract+
        +loop-human-audit-governor-derived-contract+
        +loop-human-audit-governance-node-kind-contract+
        +loop-human-audit-human-intervention-contract+
        +loop-human-audit-control-owner-contract+
        +loop-human-audit-decision-owner-contract+
        +loop-human-audit-execution-owner-contract+
        +loop-human-audit-metadata-contract+))
(def +loop-human-audit-type-contract+
  (poo-flow-native-contract
   'loop-human-audit 'loops 'LoopHumanAudit loop-human-audit?
   +loop-human-audit-slot-contracts+
   (lambda (candidate slot) (and (object? candidate) (.slot? candidate slot)))
   (lambda (candidate slot) (.ref candidate slot))
   '((boundary . loop-human-audit) (projection . human-review-loop))))
