;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: governor policy projection, validation, and Marlin contract facts.
;;; Invariant: runtime snapshots are inputs; this owner never locks or mutates them.

(import :yuanxu/modules/funflow/control-plane/failure
        (only-in "./descriptor.ss"
                 loop-pattern-actionable?
                 loop-pattern-metadata
                 loop-pattern-name)
        (only-in "./strategy.ss"
                 +loop-strategy-plan-schema+
                 loop-strategy-control-owner
                 loop-strategy-execution-owner
                 loop-strategy-handoff
                 loop-strategy-level-ceiling
                 loop-strategy-local-validation
                 loop-strategy-metadata
                 loop-strategy-name
                 loop-strategy-patterns
                 loop-strategy-plan?
                 loop-strategy-selected-patterns/from-fields
                 loop-strategy-selection
                 loop-strategy-validation-errors)
        (only-in "./governor-core.ss"
                 +loop-governor-schema+
                 loop-governor?
                 loop-governor-agent-judge-nodes
                 loop-governor-agent-judges
                 loop-governor-aggregate-budget
                 loop-governor-alist-ref
                 loop-governor-collision-policy
                 loop-governor-control-owner
                 loop-governor-execution-owner
                 loop-governor-handoff
                 loop-governor-human-inbox
                 loop-governor-metadata
                 loop-governor-name
                 loop-governor-node-contracts
                 loop-governor-node?
                 loop-governor-shared-denylist
                 loop-governor-state-key
                 loop-governor-strategy))

(import (only-in ./governor-policy-sets.ss
                 loop-governor-member?
                 loop-governor-pattern-conflicted-by-set?
                 loop-governor-pattern-denied-by-set?
                 loop-governor-pattern-open?
                 loop-governor-value-set))

(export loop-governor-state-field
        loop-governor-budget-limit
        loop-governor-pattern-action-key
        loop-governor-state-action-key
        loop-governor-pattern-denied?
        loop-governor-pattern-conflicted?
        loop-governor-denied-patterns
        loop-governor-conflicting-patterns
        loop-governor-open-patterns
        loop-governor-human-inbox-items
        loop-governor-validation-errors
        validate-loop-governor
        loop-governor->contract/validated
        loop-governor->contract)

;;; State field lookup exposes the runtime snapshot key as a first-class policy
;;; value so downstream contracts can rename it without changing predicates.
;; : (-> LoopGovernor Symbol)
(def (loop-governor-state-field governor)
  (loop-governor-alist-ref (loop-governor-state-key governor) 'field 'acting_on))

;;; Budget limit is the only local budget behavior in this owner.
;;; Counting attempts and spending tokens remains runtime-owned state.
;; : (-> LoopGovernor Integer)
(def (loop-governor-budget-limit governor)
  (loop-governor-alist-ref (loop-governor-aggregate-budget governor)
                           'max-actionable
                           1))

;;; Pattern action keys come from descriptor metadata when present.
;;; Falling back to the pattern name keeps report-only examples inspectable.
;; : (-> LoopPatternDescriptor ActionKey)
;;; Runtime state snapshots use the governor state field by convention.
;;; Missing or empty values mean no active ownership claim.
;; : (-> LoopGovernor Alist MaybeActionKey)
(def (loop-governor-state-action-key governor state)
  (loop-governor-alist-ref state
                           (loop-governor-state-field governor)
                           #f))

;;; Boundary: loop governor member predicate is the policy-visible edge for
;;; loop behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> ActionKey [ActionKey] Boolean)
;;; Boundary: loop governor value set is the policy-visible edge for loop
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [Value] HashTable)
;;; Hash lookup is deliberately truthy instead of mutating policy state. The
;;; caller owns table construction and this helper only answers membership.
;; : (-> HashTable Value Boolean)
;;; Denyset classification checks both action scope and descriptor identity.
;;; This lets shared denylist policy block broad targets or named patterns.
;; : (-> LoopPatternDescriptor HashTable Boolean)
;;; Conflict classification compares the descriptor action key with runtime
;;; state facts. It never claims or rewrites the state key.
;; : (-> LoopPatternDescriptor HashTable Boolean)
;;; Open classification is the intersection that survived static denylist and
;;; runtime-state conflict checks.
;; : (-> Boolean Boolean Boolean)
;;; Conditional cons keeps the accumulator update branch at the leaf, so the
;;; classifier can remain a named reducer instead of nested dispatch.
;; : (forall (a) (-> Boolean a [a] [a]))
(def (loop-governor-cons-if condition value tail)
  (if condition
    (cons value tail)
    tail))

;; loop-governor-pattern-classification
;;   | contract: adjacent machine contract below defines the alist projection.
;;   | doc m%
;;       Builds the per-pattern classification receipt consumed by the
;;       governor reducer. The receipt is still an alist because it is projected
;;       into doctor and manifest explanations.
;;
;;       # Examples
;;       (loop-governor-pattern-classification descriptor denyset stateset)
;;       ;; => ((descriptor . descriptor) (denied? . #f) ...)
;;     %
;; : (-> LoopPatternDescriptor HashTable HashTable Alist)
(def (loop-governor-pattern-classification descriptor denylist-set state-action-key-set)
  (let* ((denied?
          (loop-governor-pattern-denied-by-set? descriptor denylist-set))
         (conflicted?
          (loop-governor-pattern-conflicted-by-set?
           descriptor
           state-action-key-set)))
    (list (cons 'descriptor descriptor)
          (cons 'denied? denied?)
          (cons 'conflicted? conflicted?)
          (cons 'open?
                (loop-governor-pattern-open? denied? conflicted?)))))

;; loop-governor-classification-accumulate
;;   | contract: adjacent machine contract below defines the three values.
;;   | doc m%
;;       Updates the open/conflicting/denied reverse accumulators from one
;;       classification receipt. Returning multiple values makes the tuple
;;       protocol explicit and avoids anonymous list tuple plumbing.
;;
;;       # Examples
;;       (loop-governor-classification-accumulate descriptor classification '() '() '())
;;       ;; => values open-rev conflicting-rev denied-rev
;;     %
;; : (-> LoopPatternDescriptor Alist [LoopPatternDescriptor] [LoopPatternDescriptor] [LoopPatternDescriptor] (Values Value Value Value))
(def (loop-governor-classification-accumulate descriptor
                                              classification
                                              open-rev
                                              conflicting-rev
                                              denied-rev)
  (values
   (loop-governor-cons-if
    (loop-governor-alist-ref classification 'open? #f)
    descriptor
    open-rev)
   (loop-governor-cons-if
    (loop-governor-alist-ref classification 'conflicted? #f)
    descriptor
    conflicting-rev)
   (loop-governor-cons-if
    (loop-governor-alist-ref classification 'denied? #f)
    descriptor
    denied-rev)))

;;; Boundary: loop governor filter is the policy-visible edge for loop
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Predicate [Value] [Value])
(def (loop-governor-filter predicate values)
  (cond
   ((null? values) '())
   ((predicate (car values))
    (cons (car values)
          (loop-governor-filter predicate (cdr values))))
   (else
    (loop-governor-filter predicate (cdr values)))))

;;; Boundary: loop governor take at most is the policy-visible edge for loop
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Nat [Value] [Value])
(def (loop-governor-take-at-most limit values)
  (cond
   ((<= limit 0) '())
   ((null? values) '())
   (else
    (cons (car values)
          (loop-governor-take-at-most (- limit 1) (cdr values))))))

;; : (-> LoopGovernor [Alist] [ActionKey] [ActionKey])
(def (loop-governor-state-action-keys/rev governor states action-keys-rev)
  (cond
   ((null? states) action-keys-rev)
   (else
    (let (action-key (loop-governor-state-action-key governor (car states)))
      (loop-governor-state-action-keys/rev
       governor
       (cdr states)
       (if action-key
         (cons action-key action-keys-rev)
         action-keys-rev))))))

;; : (-> LoopGovernor [Alist] [ActionKey])
(def (loop-governor-state-action-keys governor states)
  (reverse (loop-governor-state-action-keys/rev governor states '())))

;; loop-governor-classify-actionable-patterns/rev
;;   | contract: adjacent machine contract below defines the reducer values.
;;   | doc m%
;;       Folds actionable descriptors into open/conflicting/denied groups. This
;;       is the loop-governor reducer used before final budget clipping.
;;
;;       # Examples
;;       (loop-governor-classify-actionable-patterns/rev patterns denyset stateset '() '() '())
;;       ;; => values open-rev conflicting-rev denied-rev
;;     %
;; : (-> [LoopPatternDescriptor] HashTable HashTable [LoopPatternDescriptor] [LoopPatternDescriptor] [LoopPatternDescriptor] (Values Value Value Value))
(def (loop-governor-classify-actionable-patterns/rev actionable-patterns
                                                       denylist-set
                                                       state-action-key-set
                                                       open-rev
                                                       conflicting-rev
                                                       denied-rev)
  (cond
   ((null? actionable-patterns)
    (values open-rev conflicting-rev denied-rev))
   (else
    (let* ((descriptor (car actionable-patterns))
           (classification
            (loop-governor-pattern-classification
             descriptor
             denylist-set
             state-action-key-set)))
      (call-with-values
       (lambda ()
         (loop-governor-classification-accumulate
          descriptor
          classification
          open-rev
          conflicting-rev
          denied-rev))
       (lambda (next-open-rev next-conflicting-rev next-denied-rev)
         (loop-governor-classify-actionable-patterns/rev
          (cdr actionable-patterns)
          denylist-set
          state-action-key-set
          next-open-rev
          next-conflicting-rev
          next-denied-rev)))))))

;;; Boundary: loop governor classify patterns is the policy-visible edge for
;;; loop behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> LoopGovernor [Alist] Alist)
(def (loop-governor-classify-patterns valid-governor states)
  (let* ((strategy (loop-governor-strategy valid-governor))
         (selected-patterns
          (loop-strategy-selected-patterns/from-fields
           (loop-strategy-patterns strategy)
           (loop-strategy-level-ceiling strategy)))
         (actionable-patterns
          (loop-governor-filter loop-pattern-actionable? selected-patterns))
         (denylist (loop-governor-shared-denylist valid-governor))
         (state-action-keys
          (loop-governor-state-action-keys valid-governor states))
         (denylist-set (loop-governor-value-set denylist))
         (state-action-key-set
          (loop-governor-value-set state-action-keys))
         (budget-limit (loop-governor-budget-limit valid-governor)))
    (call-with-values
     (lambda ()
       (loop-governor-classify-actionable-patterns/rev
        actionable-patterns
        denylist-set
        state-action-key-set
        '()
        '()
        '()))
     (lambda (open conflicting denied)
       (list
        (cons 'selected-patterns selected-patterns)
        (cons 'actionable-patterns actionable-patterns)
        (cons 'open-patterns
              (loop-governor-take-at-most
               budget-limit
               (reverse open)))
        (cons 'conflicting-patterns (reverse conflicting))
        (cons 'denied-patterns (reverse denied)))))))

;;; Denylist checks both action keys and pattern names so policy authors can
;;; block a target scope or a named loop with the same slot.
;; : (-> LoopGovernor LoopPatternDescriptor Boolean)
(def (loop-governor-pattern-action-key descriptor)
  (loop-governor-alist-ref (loop-pattern-metadata descriptor)
                           'acting_on
                           (loop-pattern-name descriptor)))

(def (loop-governor-pattern-denied? governor descriptor)
  (let (denylist (loop-governor-shared-denylist governor))
    (or (loop-governor-member? (loop-governor-pattern-action-key descriptor)
                               denylist)
        (loop-governor-member? (loop-pattern-name descriptor)
                               denylist))))

;;; Collision checks compare descriptor action keys with runtime-supplied state
;;; facts. The check never claims the target or edits the state snapshot.
;; : (-> LoopGovernor [Alist] LoopPatternDescriptor Boolean)
(def (loop-governor-pattern-conflicted? governor states descriptor)
  (let (action-key (loop-governor-pattern-action-key descriptor))
    (and action-key
         (loop-governor-member?
          action-key
          (loop-governor-state-action-keys governor states)))))

;;; Denied projection is kept separate from collision projection so doctors can
;;; explain policy blocks and state conflicts independently.
;; : (-> LoopGovernor [LoopPatternDescriptor])
(def (loop-governor-denied-patterns governor)
  (let (valid-governor (validate-loop-governor governor))
    (loop-governor-alist-ref
     (loop-governor-classify-patterns valid-governor '())
     'denied-patterns
     '())))

;;; Conflict projection consumes runtime state facts as an argument.
;;; Callers can test state behavior without starting a scheduler.
;; : (-> LoopGovernor [Alist] [LoopPatternDescriptor])
(def (loop-governor-conflicting-patterns governor states)
  (let (valid-governor (validate-loop-governor governor))
    (loop-governor-alist-ref
     (loop-governor-classify-patterns valid-governor states)
     'conflicting-patterns
     '())))

;;; Open patterns are recommendations after static denylist and state conflict
;;; checks, then clipped by the aggregate max-actionable budget.
;; : (-> LoopGovernor [Alist] [LoopPatternDescriptor])
(def (loop-governor-open-patterns governor states)
  (let (valid-governor (validate-loop-governor governor))
    (loop-governor-alist-ref
     (loop-governor-classify-patterns valid-governor states)
     'open-patterns
     '())))

;; loop-governor-inbox-item
;;   | contract: adjacent machine contract below defines the inbox alist.
;;   | doc m%
;;       Projects one blocked descriptor into the human inbox receipt shape.
;;       This is still Scheme-side structured data; delivery and UI ownership
;;       remain runtime concerns.
;;
;;       # Examples
;;       (loop-governor-inbox-item 'acting-on-conflict descriptor 'workspace)
;;       ;; => ((reason . acting-on-conflict) (pattern . name) (acting_on . workspace))
;;     %
;; : (-> Symbol LoopPatternDescriptor ActionKey Alist)
(def (loop-governor-inbox-item reason descriptor action-key)
  (list (cons 'reason reason)
        (cons 'pattern (loop-pattern-name descriptor))
        (cons 'acting_on action-key)))

;;; Human inbox items describe blocked recommendations as structured data.
;;; The inbox target is a later runtime or UI concern.
;; : (-> LoopGovernor [Alist] [Alist])
(def (loop-governor-human-inbox-items governor states)
  (let* ((valid-governor (validate-loop-governor governor))
         (classified
          (loop-governor-classify-patterns valid-governor states)))
    (loop-governor-human-inbox-items/from-patterns
     (loop-governor-alist-ref classified 'denied-patterns '())
     (loop-governor-alist-ref classified 'conflicting-patterns '()))))

;;; Boundary: loop governor human inbox items from patterns is the policy-
;;; visible edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [LoopPatternDescriptor] [LoopPatternDescriptor] [Alist])
(def (loop-governor-human-inbox-items/from-patterns denied-patterns conflicting-patterns)
  (loop-governor-human-inbox-items/tail
   denied-patterns
   'shared-denylist
   (loop-governor-human-inbox-items/tail
    conflicting-patterns
    'acting-on-conflict
    '())))

;; : (-> [LoopPatternDescriptor] Symbol [Alist] [Alist])
(def (loop-governor-human-inbox-items/tail descriptors reason tail)
  (cond
   ((null? descriptors) tail)
   (else
    (cons (loop-governor-inbox-item
           reason
           (car descriptors)
           (loop-governor-pattern-action-key (car descriptors)))
          (loop-governor-human-inbox-items/tail
           (cdr descriptors)
           reason
           tail)))))

;;; Required errors use the same alist shape as strategy validation.
;;; That keeps governor findings composable with existing doctor output.
;; : (-> Symbol FieldValue [ValidationError] [ValidationError])
(def (loop-governor-required-field-error/tail field value tail)
  (if value
    tail
    (cons (list (cons 'field field)
                (cons 'code 'required))
          tail)))

;; : (-> Symbol FieldValue [ValidationError])
(def (loop-governor-required-field-error field value)
  (loop-governor-required-field-error/tail field value '()))

;;; Boundary: loop governor field validation error unless is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Boolean Symbol Symbol FieldValue [ValidationError] [ValidationError])
(def (loop-governor-field-validation-error/unless/tail valid?
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
(def (loop-governor-field-validation-error/unless valid? field code value)
  (loop-governor-field-validation-error/unless/tail
   valid?
   field
   code
   value
   '()))

;;; Boundary: loop governor strategy validation errors is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> LoopStrategyPlan [ValidationError] [ValidationError])
(def (loop-governor-strategy-validation-errors/tail strategy tail)
  (if (loop-strategy-plan? strategy)
    (let (strategy-errors (loop-strategy-validation-errors strategy))
      (if (null? strategy-errors)
        tail
        (cons (list (cons 'field 'strategy)
                    (cons 'code 'invalid-strategy)
                    (cons 'errors strategy-errors))
              tail)))
    (cons (list (cons 'field 'strategy)
                (cons 'code 'not-loop-strategy-plan))
          tail)))

;; : (-> LoopStrategyPlan [ValidationError])
(def (loop-governor-strategy-validation-errors strategy)
  (loop-governor-strategy-validation-errors/tail strategy '()))

;;; Boundary: loop governor node list validation errors is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;;; Boundary: loop governor agent judge node field errors is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [LoopGovernorNode] [ValidationError])
(def (loop-governor-agent-judge-node-field-errors nodes)
  (if (list? nodes)
    (loop-governor-node-list-validation-errors nodes)
    (list (list (cons 'field 'agent-judge-nodes)
                (cons 'code 'not-list)
                (cons 'value nodes)))))

;;; Boundary: loop governor node list validation errors is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [Value] [ValidationError])
(def (loop-governor-node-list-validation-errors nodes)
  (cond
   ((null? nodes) '())
   ((loop-governor-node? (car nodes))
    (loop-governor-node-list-validation-errors (cdr nodes)))
   (else
    (cons (list (cons 'field 'agent-judge-nodes)
                (cons 'code 'not-loop-governor-node)
                (cons 'value (car nodes)))
          (loop-governor-node-list-validation-errors (cdr nodes))))))

;;; Validation folds strategy-plan errors under the governor boundary.
;;; Runtime state remains outside validation because it changes per handoff.
;; : (-> LoopGovernor [ValidationError])
(def (loop-governor-validation-errors governor)
  (if (loop-governor? governor)
    (loop-governor-required-field-error/tail
     'name
     (loop-governor-name governor)
     (loop-governor-strategy-validation-errors/tail
      (loop-governor-strategy governor)
      (loop-governor-field-validation-error/unless/tail
       (symbol? (loop-governor-state-field governor))
       'state-key
       'field-not-symbol
       (loop-governor-state-field governor)
       (loop-governor-field-validation-error/unless/tail
        (integer? (loop-governor-budget-limit governor))
        'aggregate-budget
        'max-actionable-not-integer
        (loop-governor-budget-limit governor)
        (loop-governor-field-validation-error/unless/tail
         (list? (loop-governor-agent-judges governor))
         'agent-judges
         'not-list
         (loop-governor-agent-judges governor)
         (loop-governor-agent-judge-node-field-errors
          (loop-governor-agent-judge-nodes governor)))))))
    (list '((field . governor) (code . not-loop-governor)))))

;;; Validation is the only gate before governor contracts leave Scheme.
;;; Failures stay typed so callers never parse policy strings.
;; : (-> LoopGovernor LoopGovernor)
(def (validate-loop-governor governor)
  (let (errors (loop-governor-validation-errors governor))
    (if (null? errors)
      governor
      (raise-control-plane-failure
       'loop-governor
       'invalid-loop-governor
       "invalid loop governor"
       (list (cons 'errors errors))))))

;;; Pattern-name projection is the compact contract summary for Marlin and
;;; doctor output. Full descriptor contracts remain in the nested strategy.
;; : (-> [LoopPatternDescriptor] [Symbol])
(def (loop-governor-pattern-names descriptors)
  (map loop-pattern-name descriptors))

;;; Governor contracts need strategy identity and ordered names, not 600 full
;;; descriptor contracts. Full descriptor projection stays on the strategy API.
;; : (-> LoopStrategyPlan [LoopPatternDescriptor] [LoopPatternDescriptor] Alist)
(def (loop-governor-strategy-summary strategy selected-patterns actionable-patterns)
  (let (next-pattern
        (if (null? actionable-patterns)
          #f
          (car actionable-patterns)))
    (list (cons 'schema +loop-strategy-plan-schema+)
          (cons 'kind 'loop-strategy-plan)
          (cons 'projection 'compact-governor-view)
          (cons 'name (loop-strategy-name strategy))
          (cons 'selection (loop-strategy-selection strategy))
          (cons 'level-ceiling (loop-strategy-level-ceiling strategy))
          (cons 'pattern-count (length (loop-strategy-patterns strategy)))
          (cons 'selected-patterns
                (loop-governor-pattern-names selected-patterns))
          (cons 'actionable-patterns
                (loop-governor-pattern-names actionable-patterns))
          (cons 'next-pattern
                (if next-pattern (loop-pattern-name next-pattern) #f))
          (cons 'local-validation (loop-strategy-local-validation strategy))
          (cons 'handoff (loop-strategy-handoff strategy))
          (cons 'runtime-boundary
                '((local-execution . validation-only)
                  (production-execution . marlin-agent-core)))
          (cons 'control-owner (loop-strategy-control-owner strategy))
          (cons 'execution-owner (loop-strategy-execution-owner strategy))
          (cons 'metadata (loop-strategy-metadata strategy)))))

;;; Contract projection is the governor handoff surface for Marlin.
;;; It includes state-derived facts but performs no runtime transition.
;; : (-> LoopGovernor [Alist] Alist)
(def (loop-governor->contract/validated valid-governor states)
  (let* ((strategy (loop-governor-strategy valid-governor))
         (classified
          (loop-governor-classify-patterns valid-governor states))
         (open-patterns
          (loop-governor-alist-ref classified 'open-patterns '()))
         (conflicting-patterns
          (loop-governor-alist-ref classified 'conflicting-patterns '()))
         (denied-patterns
          (loop-governor-alist-ref classified 'denied-patterns '()))
         (selected-patterns
          (loop-governor-alist-ref classified 'selected-patterns '()))
         (actionable-patterns
          (loop-governor-alist-ref classified 'actionable-patterns '()))
         (agent-judge-nodes
          (loop-governor-agent-judge-nodes valid-governor)))
    (list (cons 'schema +loop-governor-schema+)
          (cons 'kind 'loop-governor)
          (cons 'name (loop-governor-name valid-governor))
          (cons 'strategy
                (loop-governor-strategy-summary
                 strategy
                 selected-patterns
                 actionable-patterns))
          (cons 'state-key (loop-governor-state-key valid-governor))
          (cons 'collision-policy
                (loop-governor-collision-policy valid-governor))
          (cons 'aggregate-budget
                (loop-governor-aggregate-budget valid-governor))
          (cons 'agent-judges
                (loop-governor-agent-judges valid-governor))
          (cons 'agent-judge-nodes
                (loop-governor-node-contracts agent-judge-nodes))
          (cons 'shared-denylist
                (loop-governor-shared-denylist valid-governor))
          (cons 'open-patterns
                (loop-governor-pattern-names open-patterns))
          (cons 'conflicting-patterns
                (loop-governor-pattern-names conflicting-patterns))
          (cons 'denied-patterns
                (loop-governor-pattern-names denied-patterns))
          (cons 'human-inbox-items
                (loop-governor-human-inbox-items/from-patterns
                 denied-patterns
                 conflicting-patterns))
          (cons 'human-inbox (loop-governor-human-inbox valid-governor))
          (cons 'handoff (loop-governor-handoff valid-governor))
          (cons 'runtime-boundary
                '((local-execution . validation-only)
                  (agent-governance . loop-governor)
                  (human-intervention . human-audit-loop)
                  (production-execution . marlin-agent-core)))
          (cons 'control-owner
                (loop-governor-control-owner valid-governor))
          (cons 'execution-owner
                (loop-governor-execution-owner valid-governor))
          (cons 'metadata (loop-governor-metadata valid-governor)))))

;; : (-> LoopGovernor [Alist] Alist)
(def (loop-governor->contract governor states)
  (loop-governor->contract/validated
   (validate-loop-governor governor)
   states))
