;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop strategies compose policy descriptors into inert handoff data.
;;; Invariant: local execution here is harness-only validation, never production runtime.

(import :core/composition/roles
        (only-in :clan/poo/object .o object?)
        :poo-flow/modules/workflow/control-plane/roles
        :poo-flow/modules/workflow/control-plane/failure
        :core/object-family/role-syntax
        :poo-flow/modules/loop-engine/control/descriptor)

(export +loop-strategy-plan-schema+
        +loop-local-validation-default+
        +loop-runtime-handoff-default+
        loop-strategy-engine-role
        loop-prioritization-role
        loop-local-validation-role
        loop-runtime-handoff-role
        loop-strategy-plan-prototype
        make-loop-strategy-plan
        loop-strategy-plan?
        loop-strategy-slot
        loop-strategy-name
        loop-strategy-patterns
        loop-strategy-selection
        loop-strategy-level-ceiling
        loop-strategy-local-validation
        loop-strategy-handoff
        loop-strategy-metadata
        loop-strategy-control-owner
        loop-strategy-execution-owner
        loop-strategy-local-validation-harness-only?
        loop-pattern-within-ceiling?
        loop-pattern-prioritized-before?
        loop-strategy-selected-patterns/from-fields
        loop-strategy-selected-patterns
        loop-strategy-actionable-patterns
        loop-strategy-human-gated-patterns
        loop-strategy-next-pattern
        loop-strategy-validation-errors
        validate-loop-strategy-plan
        loop-strategy-plan->contract)

;;; Boundary: schema id is the stable contract name exported to Marlin.
;; : (-> Unit Symbol)
(def +loop-strategy-plan-schema+ 'poo-flow.loop-strategy-plan.v1)

;;; Boundary: local validation defaults keep repository execution harness-only.
;;; Intent: tests and probes may run locally without claiming production loop ownership.
;; : (-> Unit Alist)
(def +loop-local-validation-default+
  '((mode . harness-only)
    (purpose . (test validation stability performance))
    (allow-effects . #f)
    (checks . (contract smoke replay benchmark))))

;;; Boundary: handoff defaults document the production owner for loop execution.
;;; Intent: Scheme should not allocate timers, worktrees, or connector IO here.
;; : (-> Unit Alist)
(def +loop-runtime-handoff-default+
  '((target . marlin-agent-core)
    (transport . scheme-abi)
    (contract . poo-flow.loop-pattern.v1)))

;;; Boundary: engine role marks this file as policy composition, not execution.
;;; Boundary: root strategy role identifies Scheme as the policy owner while
;;; leaving the effect-capable loop runtime to the handoff contract.
;; : (-> Unit Role)
(def loop-strategy-engine-role
  (.o (:: @ strategy-role)
      (name 'loop-strategy-engine)
      (kind 'loop-control)
      (responsibility 'multi-loop-policy-composition)
      (runtime-owner 'gerbil)
      (loop-capability 'strategy-composition)))

;;; Boundary: prioritization role owns ordering policy for selected patterns.
;;; Boundary: prioritization is a policy role so repository defaults can later
;;; override ranking without changing the strategy-plan constructor.
;; : (-> Unit Role)
(def loop-prioritization-role
  (.o (:: @ loop-strategy-engine-role)
      (name 'loop-prioritization)
      (kind 'loop-policy)
      (responsibility 'priority-and-autonomy-ordering)
      (loop-policy-slot 'prioritization)))

;;; Boundary: local validation role keeps repository checks harness-only.
;;; Boundary: local validation is a role because tests need a first-class slot
;;; that explicitly forbids production effects in this package.
;; : (-> Unit Role)
(def loop-local-validation-role
  (.o (:: @ loop-strategy-engine-role)
      (name 'loop-local-validation)
      (kind 'loop-policy)
      (responsibility 'harness-only-validation)
      (loop-policy-slot 'local-validation)))

;;; Boundary: runtime handoff role names Marlin as the execution owner.
;;; Boundary: runtime handoff is a role so Marlin ownership is inherited by the
;;; composed plan instead of repeated in ad hoc projection code.
;; : (-> Unit Role)
(def loop-runtime-handoff-role
  (.o (:: @ loop-strategy-engine-role)
      (name 'loop-runtime-handoff)
      (kind 'loop-boundary)
      (responsibility 'marlin-runtime-contract-projection)
      (loop-policy-slot 'handoff)))

;;; Boundary: plan slots are policy data for selecting loop descriptors.
;;; Intent: C4/POO composes strategy roles before Marlin receives a contract.
;; : (-> Unit LoopStrategyPlanPrototype)
(def loop-strategy-plan-prototype
  (poo-core-role-object
   (slots ((schema +loop-strategy-plan-schema+)
           (kind 'loop-strategy-plan)
           (name #f)
           (patterns '())
           (selection 'priority-first)
           (level-ceiling 'l2)
           (local-validation +loop-local-validation-default+)
           (handoff +loop-runtime-handoff-default+)
           (control-owner 'gerbil)
           (execution-owner 'marlin-agent-core)
           (metadata '())))
   (supers loop-runtime-handoff-role
           loop-local-validation-role
           loop-prioritization-role
           loop-strategy-engine-role)))

;; : (forall (k v) (-> [(Pair k v)] [(Pair k v)] [(Pair k v)]))
;; : (-> Alist Alist Alist)
(def (loop-strategy-slot-rows/tail rows tail)
  (foldr cons tail rows))

;; : (-> Symbol [LoopPatternDescriptor] Alist Alist)
(def (loop-strategy-plan-slot-rows name patterns overrides)
  (loop-strategy-slot-rows/tail
   (list
    (cons 'name name)
    (cons 'patterns patterns))
   overrides))

;;; Boundary: constructor receives descriptors and strategy-policy overrides.
;;; Runtime handles, timers, connector clients, and worktrees stay out of scope.
;; : (-> Symbol [LoopPatternDescriptor] [Alist] LoopStrategyPlan)
(def (make-loop-strategy-plan name patterns . maybe-overrides)
  (poo-core-role-object
   (slot-rows
    (loop-strategy-plan-slot-rows
     name
     patterns
     (if (null? maybe-overrides) '() (car maybe-overrides))))
   (supers loop-strategy-plan-prototype)))

;;; Boundary: predicate accepts C4-composed strategy objects by kind slot.
;; : (-> LoopStrategyPlanCandidate Boolean)
(def (loop-strategy-plan? plan)
  (and (object? plan)
       (eq? (loop-strategy-slot plan 'kind #f)
            'loop-strategy-plan)))

;;; Boundary: slot access keeps strategy plans record-like and policy-owned.
;; : (-> LoopStrategyPlan Symbol LoopStrategySlotValue LoopStrategySlotValue)
(def (loop-strategy-slot plan slot default)
  (role-slot/default plan slot default))

;;; Boundary: alist policy lookup is used only for local validation metadata.
;;; Alist lookup stays local to the strategy module so runtime-boundary policy
;;; checks do not depend on descriptor-internal helpers.
;; : (-> Alist Symbol AlistValue AlistValue)
(def (loop-strategy-alist-ref alist key default)
  (cond
   ((assoc key alist) => cdr)
   (else default)))

;;; Boundary: name is the stable handle used in projected contracts.
;; : (-> LoopStrategyPlan Symbol)
(def (loop-strategy-name plan)
  (loop-strategy-slot plan 'name #f))

;;; Boundary: patterns stay descriptor data until a Marlin handoff consumes them.
;; : (-> LoopStrategyPlan [LoopPatternDescriptor])
(def (loop-strategy-patterns plan)
  (loop-strategy-slot plan 'patterns '()))

;;; Boundary: selection names the ordering policy without executing it.
;; : (-> LoopStrategyPlan Symbol)
(def (loop-strategy-selection plan)
  (loop-strategy-slot plan 'selection #f))

;;; Boundary: autonomy ceiling filters patterns before any runtime handoff.
;; : (-> LoopStrategyPlan Symbol)
(def (loop-strategy-level-ceiling plan)
  (loop-strategy-slot plan 'level-ceiling #f))

;;; Boundary: local validation metadata describes harness checks only.
;; : (-> LoopStrategyPlan Alist)
(def (loop-strategy-local-validation plan)
  (loop-strategy-slot plan 'local-validation '()))

;; : (-> Alist Boolean)
(def (loop-strategy-local-validation-policy-harness-only? policy)
  (and (eq? (loop-strategy-alist-ref policy 'mode #f) 'harness-only)
       (eq? (loop-strategy-alist-ref policy 'allow-effects #t) #f)))

;;; Boundary: handoff metadata describes the downstream runtime contract.
;; : (-> LoopStrategyPlan Alist)
(def (loop-strategy-handoff plan)
  (loop-strategy-slot plan 'handoff '()))

;;; Boundary: metadata is descriptive and never scheduler state.
;; : (-> LoopStrategyPlan Alist)
(def (loop-strategy-metadata plan)
  (loop-strategy-slot plan 'metadata '()))

;;; Boundary: control owner stays Gerbil for descriptor policy composition.
;; : (-> LoopStrategyPlan Symbol)
(def (loop-strategy-control-owner plan)
  (loop-strategy-slot plan 'control-owner #f))

;;; Boundary: execution owner remains external to this Scheme strategy surface.
;; : (-> LoopStrategyPlan Symbol)
(def (loop-strategy-execution-owner plan)
  (loop-strategy-slot plan 'execution-owner #f))

;;; This predicate is the enforcement point for the local/runtime split: tests
;;; may project contracts locally, but any effect-capable loop must be rejected.
;;; Boundary: this predicate prevents tests from becoming production execution.
;; : (-> LoopStrategyPlan Boolean)
(def (loop-strategy-local-validation-harness-only? plan)
  (loop-strategy-local-validation-policy-harness-only?
   (loop-strategy-local-validation plan)))

;;; Autonomy ceilings are policy gates, not scheduler readiness checks. They
;;; keep future L3 patterns out of current L1/L2 contract projections.
;;; Boundary: ceiling checks reject unknown autonomy levels instead of guessing.
;; : (-> LoopPatternDescriptor Symbol Boolean)
(def (loop-pattern-within-ceiling? descriptor ceiling)
  (and (loop-pattern-level? ceiling)
       (loop-pattern-level? (loop-pattern-level descriptor))
       (loop-pattern-level<=? (loop-pattern-level descriptor) ceiling)))

;;; Boundary: priority comparison is policy ordering, not scheduler readiness.
;;; Intent: equal priority keeps the more capable autonomy level first because it has more gates.
;; : (-> LoopPatternDescriptor LoopPatternDescriptor Boolean)
(def (loop-pattern-prioritized-before? left right)
  (let ((left-priority (loop-pattern-priority left))
        (right-priority (loop-pattern-priority right)))
    (cond
     ((< left-priority right-priority) #t)
     ((> left-priority right-priority) #f)
     (else
      (> (loop-pattern-level-rank (loop-pattern-level left))
         (loop-pattern-level-rank (loop-pattern-level right)))))))

;;; Strategy helpers keep filtering explicit so policy predicates remain visible
;;; to tests and harness diagnostics.
;; : (forall (a) (-> (-> a Boolean) [a] [a]))
;; : (-> Predicate List List)
(def (loop-filter predicate values)
  (cond
   ((null? values) '())
   ((predicate (car values))
    (cons (car values)
          (loop-filter predicate (cdr values))))
   (else
    (loop-filter predicate (cdr values)))))

;;; Strategy selection uses the stdlib stable sort so large generated policy
;;; plans do not pay quadratic insertion cost during contract projection.
;; : (-> [LoopPatternDescriptor] [LoopPatternDescriptor])
(def (loop-sort-patterns descriptors)
  (list-sort loop-pattern-prioritized-before? descriptors))

;;; Boundary: loop strategy selected patterns from fields is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [LoopPatternDescriptor] Symbol [LoopPatternDescriptor])
(def (loop-strategy-selected-patterns/from-fields patterns ceiling)
  (loop-sort-patterns
   (loop-filter
    (lambda (descriptor)
      (loop-pattern-within-ceiling? descriptor ceiling))
    patterns)))

;;; Boundary: selected patterns are validated, filtered by autonomy ceiling, and sorted.
;;; Selected patterns are the complete pre-runtime candidate set after static
;;; level gating and priority ranking.
;;; Marlin still decides actual execution from the handoff contract.
;; : (-> LoopStrategyPlan [LoopPatternDescriptor])
(def (loop-strategy-selected-patterns plan)
  (let ((name (loop-strategy-name plan))
        (patterns (loop-strategy-patterns plan))
        (level-ceiling (loop-strategy-level-ceiling plan))
        (local-validation (loop-strategy-local-validation plan)))
    (validate-loop-strategy-plan/fields
     plan name patterns level-ceiling local-validation)
    (loop-strategy-selected-patterns/from-fields patterns level-ceiling)))

;;; Actionable patterns exclude L1 report-only loops so strategy plans can show
;;; advisory loops and write-capable loops in separate contract fields.
;;; Boundary: actionable patterns are selected first, then filtered by runtime readiness.
;; : (-> LoopStrategyPlan [LoopPatternDescriptor])
(def (loop-strategy-actionable-patterns plan)
  (loop-filter loop-pattern-actionable?
               (loop-strategy-selected-patterns plan)))

;;; Human-gated projection is a doctor/checker surface: it exposes why a loop
;;; needs review without starting the loop or contacting the external system.
;;; Boundary: human gate filters remain explicit data checks.
;; : (-> LoopStrategyPlan Symbol [LoopPatternDescriptor])
(def (loop-strategy-human-gated-patterns plan gate)
  (loop-filter
   (lambda (descriptor)
     (loop-pattern-human-gate-required? descriptor gate))
   (loop-strategy-selected-patterns plan)))

;;; The next pattern is a policy recommendation for the runtime handoff. It is
;;; deliberately not a wake-up decision and does not mutate loop state.
;;; Boundary: next-pattern is a projection, not a scheduler side effect.
;; : (-> LoopStrategyPlan MaybeLoopPatternDescriptor)
(def (loop-strategy-next-pattern plan)
  (let (patterns (loop-strategy-actionable-patterns plan))
    (if (null? patterns)
      #f
      (car patterns))))

;;; Required-field errors use the same alist shape as nested descriptor errors
;;; so downstream presentation can concatenate findings without translation.
;;; Boundary: required-field errors use structured details for doctor output.
;; : (-> Symbol FieldValue [ValidationError])
(def (loop-strategy-required-field-error/tail field value tail)
  (if value
    tail
    (cons (list (cons 'field field)
                (cons 'code 'required))
          tail)))

;; : (-> Symbol FieldValue [ValidationError])
(def (loop-strategy-required-field-error field value)
  (loop-strategy-required-field-error/tail field value '()))

;;; Boundary: loop strategy field validation error unless is the policy-visible
;;; edge for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Boolean Symbol Symbol FieldValue [ValidationError])
(def (loop-strategy-field-validation-error/unless/tail valid?
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
(def (loop-strategy-field-validation-error/unless valid? field code value)
  (loop-strategy-field-validation-error/unless/tail
   valid?
   field
   code
   value
   '()))

;;; Pattern validation nests descriptor findings under the strategy index so a
;;; downstream doctor can point at the bad loop entry without parsing strings.
;; : (-> [LoopPatternDescriptor] Nat [ValidationError])
(def (loop-strategy-pattern-validation-errors descriptors index)
  (cond
   ((null? descriptors) '())
   (else
    (let ((errors (loop-pattern-validation-errors (car descriptors)))
          (tail-errors
           (loop-strategy-pattern-validation-errors (cdr descriptors)
                                                    (+ index 1))))
      (if (null? errors)
        tail-errors
        (cons (list (cons 'field 'patterns)
                    (cons 'index index)
                    (cons 'code 'invalid-pattern)
                    (cons 'errors errors))
              tail-errors))))))

;;; Boundary: validation errors are structured data so doctor surfaces stay typed.
;;; The aggregate validator keeps local policy mistakes in one alist payload:
;;; shape errors, autonomy ceiling errors, harness violations, and child
;;; descriptor failures all become doctor-friendly data before any handoff.
;; : (-> LoopStrategyPlan [ValidationError])
(def (loop-strategy-validation-errors plan)
  (loop-strategy-validation-errors/fields
   plan
   (loop-strategy-name plan)
   (loop-strategy-patterns plan)
   (loop-strategy-level-ceiling plan)
   (loop-strategy-local-validation plan)))

;;; Boundary: loop strategy validation errors fields is the policy-visible edge
;;; for loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> LoopStrategyPlan Symbol [LoopPatternDescriptor] Symbol Alist [ValidationError])
(def (loop-strategy-validation-errors/fields plan name patterns level-ceiling local-validation)
  (if (loop-strategy-plan? plan)
    (loop-strategy-required-field-error/tail
     'name
     name
     (loop-strategy-field-validation-error/unless/tail
      (list? patterns)
      'patterns
      'not-list
      patterns
      (loop-strategy-field-validation-error/unless/tail
       (loop-pattern-level? level-ceiling)
       'level-ceiling
       'unsupported-level
       level-ceiling
       (loop-strategy-field-validation-error/unless/tail
        (loop-strategy-local-validation-policy-harness-only? local-validation)
        'local-validation
        'local-execution-must-be-harness-only
        local-validation
        (loop-strategy-pattern-validation-errors
         (if (list? patterns) patterns '())
         0)))))
    (list '((field . plan) (code . not-loop-strategy-plan)))))

;;; Boundary: validation is the gate before any strategy projection leaves this owner.
;;; Validation raises the same typed failure shape used by the rest of the
;;; control plane, so test harnesses do not parse ad hoc strategy errors.
;; : (-> LoopStrategyPlan LoopStrategyPlan)
(def (validate-loop-strategy-plan plan)
  (let (errors
        (loop-strategy-validation-errors plan))
    (if (null? errors)
      plan
      (raise-control-plane-failure
       'loop-strategy
       'invalid-loop-strategy-plan
       "invalid loop strategy plan"
       (list (cons 'errors errors))))))

;;; Boundary: validate loop strategy plan fields is the policy-visible edge for
;;; loop behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> LoopStrategyPlan Symbol [LoopPatternDescriptor] Symbol Alist LoopStrategyPlan)
(def (validate-loop-strategy-plan/fields plan name patterns level-ceiling local-validation)
  (let (errors
        (loop-strategy-validation-errors/fields
         plan name patterns level-ceiling local-validation))
    (if (null? errors)
      plan
      (raise-control-plane-failure
       'loop-strategy
       'invalid-loop-strategy-plan
       "invalid loop strategy plan"
       (list (cons 'errors errors))))))

;;; Name projection is the compact user-facing summary for selected patterns.
;; : (-> [LoopPatternDescriptor] [Symbol])
;; : (forall (pattern contract) (-> [pattern] [contract]))
;; : (-> LoopPatternList LoopPatternContractList)
(def (loop-strategy-pattern-contracts->contract descriptors)
  (cond
   ((null? descriptors) '())
   (else
    (cons (loop-pattern-descriptor->contract (car descriptors))
          (loop-strategy-pattern-contracts->contract (cdr descriptors))))))

;; : (forall (pattern name) (-> [pattern] [name]))
;; : (-> LoopPatternList PatternNameList)
(def (loop-strategy-pattern-names->contract descriptors)
  (cond
   ((null? descriptors) '())
   (else
    (cons (loop-pattern-name (car descriptors))
          (loop-strategy-pattern-names->contract (cdr descriptors))))))

(def (loop-pattern-names descriptors)
  (loop-strategy-pattern-names->contract descriptors))

;;; Boundary: projection is the only local "execution" outcome.
;;; Invariant: contract data can be tested locally, but Marlin owns the run.
;; : (-> LoopStrategyPlan Alist)
(def (loop-strategy-plan->contract plan)
  (let* ((name (loop-strategy-name plan))
         (patterns (loop-strategy-patterns plan))
         (selection (loop-strategy-selection plan))
         (level-ceiling (loop-strategy-level-ceiling plan))
         (local-validation (loop-strategy-local-validation plan))
         (handoff (loop-strategy-handoff plan))
         (control-owner (loop-strategy-control-owner plan))
         (execution-owner (loop-strategy-execution-owner plan))
         (metadata (loop-strategy-metadata plan)))
    (validate-loop-strategy-plan/fields
     plan name patterns level-ceiling local-validation)
    (let* ((selected-patterns
            (loop-strategy-selected-patterns/from-fields
             patterns
             level-ceiling))
           (actionable-patterns
            (loop-filter loop-pattern-actionable? selected-patterns))
         (next-pattern (if (null? actionable-patterns)
                         #f
                         (car actionable-patterns))))
      (list (cons 'schema +loop-strategy-plan-schema+)
            (cons 'kind 'loop-strategy-plan)
            (cons 'name name)
            (cons 'selection selection)
            (cons 'level-ceiling level-ceiling)
            (cons 'pattern-count (length patterns))
            (cons 'selected-patterns
                  (loop-strategy-pattern-contracts->contract selected-patterns))
            (cons 'actionable-patterns
                  (loop-pattern-names actionable-patterns))
            (cons 'next-pattern
                  (if next-pattern (loop-pattern-name next-pattern) #f))
            (cons 'local-validation local-validation)
            (cons 'handoff handoff)
            (cons 'runtime-boundary
                  '((local-execution . validation-only)
                    (production-execution . marlin-agent-core)))
            (cons 'control-owner control-owner)
            (cons 'execution-owner execution-owner)
            (cons 'metadata metadata)))))
