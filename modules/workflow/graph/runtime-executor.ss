;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: pure graph runtime receipts for proof-backed UI cases.
;;; Invariant: this executor records graph semantics; it never calls tools/models.

(import (only-in :clan/poo/object .o .ref object? object<-alist)
        :yuanxu/graph/types-core)

(export +agentic-ai-lab-graph-branch-choice-kind+
        +agentic-ai-lab-graph-runtime-policy-kind+
        +agentic-ai-lab-graph-runtime-receipt-kind+
        agentic-ai-lab-graph-runtime-lean-fact-keys
        agentic-ai-lab-graph-branch-choice
        agentic-ai-lab-graph-branch-choice?
        agentic-ai-lab-graph-runtime-policy
        agentic-ai-lab-graph-runtime-policy?
        agentic-ai-lab-graph-runtime-receipt?
        agentic-ai-lab-graph-runtime-receipt-ref
        agentic-ai-lab-graph-runtime-execute
        agentic-ai-lab-graph-runtime-receipt->lean-facts
        agentic-ai-lab-graph-runtime-receipt->lean-module
        agentic-ai-lab-graph-runtime-lean-fact-contract-complete?)

;; : Symbol
(def +agentic-ai-lab-graph-branch-choice-kind+
  'agentic-ai-lab.graph.branch-choice.v1)

;; : Symbol
(def +agentic-ai-lab-graph-runtime-policy-kind+
  'agentic-ai-lab.graph.runtime-policy.v1)

;; : Symbol
(def +agentic-ai-lab-graph-runtime-receipt-kind+
  'agentic-ai-lab.graph.runtime-receipt.v1)

(defstruct agentic-ai-lab-graph-runtime-receipt-record
  (kind
   schema
   graph-id
   policy-name
   entry-id
   finish-id
   trace
   fuel-before
   fuel-after
   current-id
   finished
   loop-fuel-contained
   handoff-reached
   sandbox-scope-contained
   tool-permissions-contained
   checkpoint-persisted
   human-approval-required
   human-approved
   human-approval-sound
   subagents-parented
   diagnostics
   runtime-executed)
  transparent: #t)

;; : (-> AgenticAILabGraphRuntimeReceipt Symbol Datum)
(def (agentic-ai-lab-graph-runtime-receipt-ref receipt key)
  (if (agentic-ai-lab-graph-runtime-receipt-record? receipt)
    (case key
      ((kind) (agentic-ai-lab-graph-runtime-receipt-record-kind receipt))
      ((schema) (agentic-ai-lab-graph-runtime-receipt-record-schema receipt))
      ((graph-id) (agentic-ai-lab-graph-runtime-receipt-record-graph-id receipt))
      ((policy-name) (agentic-ai-lab-graph-runtime-receipt-record-policy-name receipt))
      ((entry-id) (agentic-ai-lab-graph-runtime-receipt-record-entry-id receipt))
      ((finish-id) (agentic-ai-lab-graph-runtime-receipt-record-finish-id receipt))
      ((trace) (agentic-ai-lab-graph-runtime-receipt-record-trace receipt))
      ((fuel-before) (agentic-ai-lab-graph-runtime-receipt-record-fuel-before receipt))
      ((fuel-after) (agentic-ai-lab-graph-runtime-receipt-record-fuel-after receipt))
      ((current-id) (agentic-ai-lab-graph-runtime-receipt-record-current-id receipt))
      ((finished) (agentic-ai-lab-graph-runtime-receipt-record-finished receipt))
      ((loop-fuel-contained)
       (agentic-ai-lab-graph-runtime-receipt-record-loop-fuel-contained receipt))
      ((handoff-reached)
       (agentic-ai-lab-graph-runtime-receipt-record-handoff-reached receipt))
      ((sandbox-scope-contained)
       (agentic-ai-lab-graph-runtime-receipt-record-sandbox-scope-contained receipt))
      ((tool-permissions-contained)
       (agentic-ai-lab-graph-runtime-receipt-record-tool-permissions-contained receipt))
      ((checkpoint-persisted)
       (agentic-ai-lab-graph-runtime-receipt-record-checkpoint-persisted receipt))
      ((human-approval-required)
       (agentic-ai-lab-graph-runtime-receipt-record-human-approval-required receipt))
      ((human-approved)
       (agentic-ai-lab-graph-runtime-receipt-record-human-approved receipt))
      ((human-approval-sound)
       (agentic-ai-lab-graph-runtime-receipt-record-human-approval-sound receipt))
      ((subagents-parented)
       (agentic-ai-lab-graph-runtime-receipt-record-subagents-parented receipt))
      ((diagnostics) (agentic-ai-lab-graph-runtime-receipt-record-diagnostics receipt))
      ((runtime-executed)
       (agentic-ai-lab-graph-runtime-receipt-record-runtime-executed receipt))
      (else #f))
    (.ref receipt key)))

;; : [Symbol]
(def agentic-ai-lab-graph-runtime-lean-fact-keys
  '(graph.runtime/executed
    graph.runtime/finished
    graph.runtime/loop-fuel-contained
    graph.runtime/handoff-reached
    graph.runtime/sandbox-scope-contained
    graph.runtime/tool-permissions-contained
    graph.runtime/checkpoint-persisted
    graph.runtime/human-approval-sound
    graph.runtime/subagents-parented
    graph.runtime/diagnostics-empty
    graph.runtime/reusable-production-case))

;; : (-> Object Object AgenticAILabGraphBranchChoice)
(def (agentic-ai-lab-graph-branch-choice from to)
  (let ((from-value from)
        (to-value to))
    (.o (kind +agentic-ai-lab-graph-branch-choice-kind+)
        (from from-value)
        (to to-value))))

;; : (-> Object Boolean)
(def (agentic-ai-lab-graph-branch-choice? value)
  (and (object? value)
       (eq? (.ref value 'kind)
            +agentic-ai-lab-graph-branch-choice-kind+)))

;; : (-> Symbol Object Object [AgenticAILabGraphBranchChoice] Nat Boolean Boolean Boolean Boolean Boolean Boolean Boolean AgenticAILabGraphRuntimePolicy)
(def (agentic-ai-lab-graph-runtime-policy name
                                    entry-id
                                    finish-id
                                    branch-choices
                                    fuel
                                    sandbox-scope-contained?
                                    tool-permissions-contained?
                                    checkpoint-persisted?
                                    human-approval-required?
                                    human-approved?
                                    subagents-parented?
                                    handoff-required?)
  (let ((name-value name)
        (entry-id-value entry-id)
        (finish-id-value finish-id)
        (branch-choices-value branch-choices)
        (fuel-value fuel)
        (sandbox-scope-contained-value sandbox-scope-contained?)
        (tool-permissions-contained-value tool-permissions-contained?)
        (checkpoint-persisted-value checkpoint-persisted?)
        (human-approval-required-value human-approval-required?)
        (human-approved-value human-approved?)
        (subagents-parented-value subagents-parented?)
        (handoff-required-value handoff-required?))
    (object<-alist
     (list
      (cons 'kind +agentic-ai-lab-graph-runtime-policy-kind+)
      (cons 'name name-value)
      (cons 'entry-id entry-id-value)
      (cons 'finish-id finish-id-value)
      (cons 'branch-choices branch-choices-value)
      (cons 'fuel fuel-value)
      (cons 'sandbox-scope-contained sandbox-scope-contained-value)
      (cons 'tool-permissions-contained tool-permissions-contained-value)
      (cons 'checkpoint-persisted checkpoint-persisted-value)
      (cons 'human-approval-required human-approval-required-value)
      (cons 'human-approved human-approved-value)
      (cons 'subagents-parented subagents-parented-value)
      (cons 'handoff-required handoff-required-value)))))

;; : (-> Object Boolean)
(def (agentic-ai-lab-graph-runtime-policy? value)
  (and (object? value)
       (eq? (.ref value 'kind)
            +agentic-ai-lab-graph-runtime-policy-kind+)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-graph-runtime-receipt? value)
  (or (agentic-ai-lab-graph-runtime-receipt-record? value)
      (and (object? value)
           (eq? (.ref value 'kind)
                +agentic-ai-lab-graph-runtime-receipt-kind+))))

;; : (-> YuanxuGraph AgenticAILabGraphRuntimePolicy AgenticAILabGraphRuntimeReceipt)
(def (agentic-ai-lab-graph-runtime-execute graph-value policy)
  (let* ((fuel (.ref policy 'fuel))
         (max-steps (+ 1 (* (+ fuel 1)
                            (+ 1 (length (yuanxu-graph-edges graph-value)))))))
    (runtime-walk graph-value
                  policy
                  (.ref policy 'entry-id)
                  (.ref policy 'branch-choices)
                  fuel
                  (list (.ref policy 'entry-id))
                  0
                  max-steps
                  '())))

;; : (-> YuanxuGraph AgenticAILabGraphRuntimePolicy Object [AgenticAILabGraphBranchChoice] Nat [Object] Nat Nat Alist AgenticAILabGraphRuntimeReceipt)
(def (runtime-walk graph-value
                   policy
                   current-id
                   branch-choices
                   fuel
                   trace-rev
                   step-count
                   max-steps
                   diagnostics-rev)
  (cond
   ((> step-count max-steps)
    (runtime-receipt graph-value
                     policy
                     (reverse trace-rev)
                     fuel
                     current-id
                     #f
                     (reverse
                      (cons (cons 'max-steps-exceeded max-steps)
                            diagnostics-rev))))
   ((equal? current-id (.ref policy 'finish-id))
    (runtime-receipt graph-value
                     policy
                     (reverse trace-rev)
                     fuel
                     current-id
                     #t
                     (reverse diagnostics-rev)))
   (else
    (let* ((selection
            (runtime-select-edge current-id
                                 (yuanxu-graph-edges graph-value)
                                 branch-choices))
           (edge (car selection))
           (branch-choices* (cadr selection))
           (diagnostic (caddr selection)))
      (cond
       (diagnostic
        (runtime-receipt graph-value
                         policy
                         (reverse trace-rev)
                         fuel
                         current-id
                         #f
                         (reverse (cons diagnostic diagnostics-rev))))
       ((and (runtime-loop-edge? edge)
             (= fuel 0))
        (runtime-receipt graph-value
                         policy
                         (reverse trace-rev)
                         fuel
                         current-id
                         #f
                         (reverse
                          (cons (cons 'fuel-exhausted current-id)
                                diagnostics-rev))))
       (else
        (let* ((next-id (yuanxu-graph-edge-to edge))
               (fuel* (if (runtime-loop-edge? edge)
                        (- fuel 1)
                        fuel)))
          (runtime-walk graph-value
                        policy
                        next-id
                        branch-choices*
                        fuel*
                        (cons next-id trace-rev)
                        (+ step-count 1)
                        max-steps
                        diagnostics-rev))))))))

;; : (-> Object [YuanxuGraphEdge] [AgenticAILabGraphBranchChoice] [MaybeEdge [AgenticAILabGraphBranchChoice] MaybeDiagnostic])
(def (runtime-select-edge current-id edges branch-choices)
  (let* ((outgoing (runtime-outgoing-edges current-id edges))
         (choice-result
          (runtime-next-branch-choice current-id branch-choices))
         (choice (car choice-result))
         (branch-choices* (cadr choice-result)))
    (cond
     ((null? outgoing)
      (list #f branch-choices (cons 'dead-end current-id)))
     (choice
      (let ((edge (runtime-edge-to (agentic-ai-lab-graph-branch-choice-to choice)
                                   outgoing)))
        (if edge
          (list edge branch-choices* #f)
          (list #f branch-choices*
                (cons 'missing-branch-target
                      (agentic-ai-lab-graph-branch-choice-to choice))))))
     ((runtime-has-conditional-edge? outgoing)
      (list #f branch-choices (cons 'missing-branch-choice current-id)))
     (else
      (list (car outgoing) branch-choices #f)))))

;; : (-> YuanxuGraph AgenticAILabGraphRuntimePolicy [Object] Nat Object Boolean Alist AgenticAILabGraphRuntimeReceipt)
(def (runtime-receipt graph-value
                      policy
                      trace
                      fuel-after
                      current-id
                      finished?
                      diagnostics)
  (let* ((handoff-reached?
          (and finished?
               (or (not (.ref policy 'handoff-required))
                   (equal? current-id (.ref policy 'finish-id)))))
         (human-approval-sound?
          (or (not (.ref policy 'human-approval-required))
              (.ref policy 'human-approved)))
         (loop-fuel-contained?
          (>= fuel-after 0))
         (diagnostics*
          (runtime-final-diagnostics diagnostics
                                     policy
                                     handoff-reached?
                                     human-approval-sound?)))
    (let ((graph-id-value (yuanxu-graph-id graph-value))
          (policy-name-value (.ref policy 'name))
          (entry-id-value (.ref policy 'entry-id))
          (finish-id-value (.ref policy 'finish-id))
          (trace-value trace)
          (fuel-before-value (.ref policy 'fuel))
          (fuel-after-value fuel-after)
          (current-id-value current-id)
          (finished-value finished?)
          (loop-fuel-contained-value loop-fuel-contained?)
          (handoff-reached-value handoff-reached?)
          (sandbox-scope-contained-value
           (.ref policy 'sandbox-scope-contained))
          (tool-permissions-contained-value
           (.ref policy 'tool-permissions-contained))
          (checkpoint-persisted-value
           (.ref policy 'checkpoint-persisted))
          (human-approval-required-value
           (.ref policy 'human-approval-required))
          (human-approved-value (.ref policy 'human-approved))
          (human-approval-sound-value human-approval-sound?)
          (subagents-parented-value (.ref policy 'subagents-parented))
          (diagnostics-value diagnostics*))
      (make-agentic-ai-lab-graph-runtime-receipt-record
       +agentic-ai-lab-graph-runtime-receipt-kind+
       'agentic-ai-lab.graph.runtime-receipt.v1
       graph-id-value
       policy-name-value
       entry-id-value
       finish-id-value
       trace-value
       fuel-before-value
       fuel-after-value
       current-id-value
       finished-value
       loop-fuel-contained-value
       handoff-reached-value
       sandbox-scope-contained-value
       tool-permissions-contained-value
       checkpoint-persisted-value
       human-approval-required-value
       human-approved-value
       human-approval-sound-value
       subagents-parented-value
       diagnostics-value
       #t))))

;; : (-> Alist AgenticAILabGraphRuntimePolicy Boolean Boolean Alist)
(def (runtime-diagnostic-prepend diagnostics ok? code policy-name)
  (if ok?
    diagnostics
    (cons (cons code policy-name) diagnostics)))

(def (runtime-final-diagnostics diagnostics
                                policy
                                handoff-reached?
                                human-approval-sound?)
  (let* ((policy-name (.ref policy 'name))
         (diagnostics
          (runtime-diagnostic-prepend
           diagnostics
           (.ref policy 'sandbox-scope-contained)
           'sandbox-scope-not-contained
           policy-name))
         (diagnostics
          (runtime-diagnostic-prepend
           diagnostics
           (.ref policy 'tool-permissions-contained)
           'tool-permissions-not-contained
           policy-name))
         (diagnostics
          (runtime-diagnostic-prepend
           diagnostics
           (.ref policy 'checkpoint-persisted)
           'checkpoint-not-persisted
           policy-name))
         (diagnostics
          (runtime-diagnostic-prepend
           diagnostics
           human-approval-sound?
           'human-approval-missing
           policy-name))
         (diagnostics
          (runtime-diagnostic-prepend
           diagnostics
           (.ref policy 'subagents-parented)
           'subagents-not-parented
           policy-name))
         (diagnostics
          (runtime-diagnostic-prepend
           diagnostics
           handoff-reached?
           'handoff-not-reached
           policy-name)))
    diagnostics))

;; : (forall (v) (-> v [(Pair Symbol Object)]))
;; : (-> AgenticAILabGraphRuntimeReceipt Alist)
(def (agentic-ai-lab-graph-runtime-receipt->lean-facts receipt)
  (let* ((receipt-ref
          (lambda (key)
            (agentic-ai-lab-graph-runtime-receipt-ref receipt key)))
         (diagnostics-empty? (null? (receipt-ref 'diagnostics)))
         (reusable-production-case?
          (and (receipt-ref 'runtime-executed)
               (receipt-ref 'finished)
               (receipt-ref 'loop-fuel-contained)
               (receipt-ref 'handoff-reached)
               (receipt-ref 'sandbox-scope-contained)
               (receipt-ref 'tool-permissions-contained)
               (receipt-ref 'checkpoint-persisted)
               (receipt-ref 'human-approval-sound)
               (receipt-ref 'subagents-parented)
               diagnostics-empty?)))
    (list
     (cons 'graph.runtime/executed (receipt-ref 'runtime-executed))
     (cons 'graph.runtime/finished (receipt-ref 'finished))
     (cons 'graph.runtime/loop-fuel-contained
           (receipt-ref 'loop-fuel-contained))
     (cons 'graph.runtime/handoff-reached
           (receipt-ref 'handoff-reached))
     (cons 'graph.runtime/sandbox-scope-contained
           (receipt-ref 'sandbox-scope-contained))
     (cons 'graph.runtime/tool-permissions-contained
           (receipt-ref 'tool-permissions-contained))
     (cons 'graph.runtime/checkpoint-persisted
           (receipt-ref 'checkpoint-persisted))
     (cons 'graph.runtime/human-approval-sound
           (receipt-ref 'human-approval-sound))
     (cons 'graph.runtime/subagents-parented
           (receipt-ref 'subagents-parented))
     (cons 'graph.runtime/diagnostics-empty diagnostics-empty?)
     (cons 'graph.runtime/reusable-production-case
           reusable-production-case?))))

;; : (forall (v) (-> [(Pair Symbol v)] Boolean))
;; : (-> Alist Boolean)
(def (agentic-ai-lab-graph-runtime-lean-fact-contract-complete? facts)
  (and (andmap (lambda (key)
                 (and (assq key facts) #t))
               agentic-ai-lab-graph-runtime-lean-fact-keys)
       (andmap (lambda (fact)
                 (and (pair? fact)
                      (memq (car fact)
                            agentic-ai-lab-graph-runtime-lean-fact-keys)
                      #t))
               facts)))

;; : (-> AgenticAILabGraphRuntimeReceipt [String] String)
(def (agentic-ai-lab-graph-runtime-receipt->lean-module receipt
                                                  . maybe-namespace)
  (let* ((namespace (if (null? maybe-namespace)
                     "AgenticAILabProof.Generated.LangChainLangGraphRuntime"
                     (car maybe-namespace)))
         (facts (agentic-ai-lab-graph-runtime-receipt->lean-facts receipt)))
    (string-append
     "import AgenticAILabProof.PooC4.LangChainLangGraph\n\n"
     "namespace " namespace "\n\n"
     "open AgenticAILabProof.PooC4.LangChainLangGraph\n\n"
     "def generatedRuntimeFactRows : List (String × Bool) :=\n"
     (runtime-lean-fact-rows-source facts)
     "\n\n"
     "def generatedProductionRuntimeFacts : ProductionRuntimeFacts where\n"
     "  runtimeExecuted := "
     (runtime-lean-prop (runtime-lean-fact facts 'graph.runtime/executed))
     "\n"
     "  finished := "
     (runtime-lean-prop (runtime-lean-fact facts 'graph.runtime/finished))
     "\n"
     "  loopFuelContained := "
     (runtime-lean-prop
      (runtime-lean-fact facts 'graph.runtime/loop-fuel-contained))
     "\n"
     "  handoffReached := "
     (runtime-lean-prop
      (runtime-lean-fact facts 'graph.runtime/handoff-reached))
     "\n"
     "  sandboxScopeContained := "
     (runtime-lean-prop
      (runtime-lean-fact facts 'graph.runtime/sandbox-scope-contained))
     "\n"
     "  toolPermissionsContained := "
     (runtime-lean-prop
      (runtime-lean-fact facts 'graph.runtime/tool-permissions-contained))
     "\n"
     "  checkpointPersisted := "
     (runtime-lean-prop
      (runtime-lean-fact facts 'graph.runtime/checkpoint-persisted))
     "\n"
     "  humanApprovalSound := "
     (runtime-lean-prop
      (runtime-lean-fact facts 'graph.runtime/human-approval-sound))
     "\n"
     "  subagentsParented := "
     (runtime-lean-prop
      (runtime-lean-fact facts 'graph.runtime/subagents-parented))
     "\n"
     "  diagnosticsEmpty := "
     (runtime-lean-prop
      (runtime-lean-fact facts 'graph.runtime/diagnostics-empty))
     "\n\n"
     "theorem generatedProductionRuntimeReusable :\n"
     "    ReusableProductionRuntime generatedProductionRuntimeFacts := by\n"
     "  repeat constructor\n\n"
     "theorem generatedProductionRuntimeCheckpointAndHumanGate :\n"
     "    generatedProductionRuntimeFacts.checkpointPersisted /\\\n"
     "      generatedProductionRuntimeFacts.humanApprovalSound :=\n"
     "  production_runtime_has_checkpoint_and_human_gate\n"
     "    generatedProductionRuntimeReusable\n\n"
     "theorem generatedProductionRuntimeScopeAndToolContainment :\n"
     "    generatedProductionRuntimeFacts.sandboxScopeContained /\\\n"
     "      generatedProductionRuntimeFacts.toolPermissionsContained :=\n"
     "  production_runtime_has_scope_and_tool_containment\n"
     "    generatedProductionRuntimeReusable\n\n"
     "end " namespace "\n")))

;; : (-> Alist Symbol Boolean)
(def (runtime-lean-fact facts key)
  (let ((cell (assq key facts)))
    (and cell (cdr cell))))

;; : (-> Boolean String)
(def (runtime-lean-prop value)
  (if value "True" "False"))

;; : (-> Boolean String)
(def (runtime-lean-bool value)
  (if value "true" "false"))

;; : (-> Alist String)
(def (runtime-lean-fact-rows-source facts)
  (runtime-lean-fact-rows-source-loop
   agentic-ai-lab-graph-runtime-lean-fact-keys
   facts
   #t))

;; : (-> [Symbol] Alist Boolean String)
(def (runtime-lean-fact-rows-source-loop keys facts first?)
  (cond
   ((null? keys) "  []")
   (else
    (string-append
     "  "
     (if first? "[" ",")
     " (\""
     (symbol->string (car keys))
     "\", "
     (runtime-lean-bool (runtime-lean-fact facts (car keys)))
     ")"
     (runtime-lean-fact-rows-source-tail (cdr keys) facts)))))

;; : (-> [Symbol] Alist String)
(def (runtime-lean-fact-rows-source-tail keys facts)
  (cond
   ((null? keys) "\n  ]")
   (else
    (string-append
     "\n"
     (runtime-lean-fact-rows-source-loop keys facts #f)))))

;; : (-> AgenticAILabGraphBranchChoice Object)
(def (agentic-ai-lab-graph-branch-choice-to choice)
  (.ref choice 'to))

;; : (-> Object [YuanxuGraphEdge] [YuanxuGraphEdge])
(def (runtime-outgoing-edges current-id edges)
  (cond
   ((null? edges) '())
   ((equal? current-id (yuanxu-graph-edge-from (car edges)))
    (cons (car edges)
          (runtime-outgoing-edges current-id (cdr edges))))
   (else
    (runtime-outgoing-edges current-id (cdr edges)))))

;; : (-> Object [YuanxuGraphEdge] MaybeEdge)
(def (runtime-edge-to target-id edges)
  (cond
   ((null? edges) #f)
   ((equal? target-id (yuanxu-graph-edge-to (car edges)))
    (car edges))
   (else
    (runtime-edge-to target-id (cdr edges)))))

;; : (-> YuanxuGraphEdge Boolean)
(def (runtime-loop-edge? edge)
  (memq (yuanxu-graph-edge-kind edge)
        '(loop back-edge retry self-loop)))

;; : (-> YuanxuGraphEdge Boolean)
(def (runtime-conditional-edge? edge)
  (memq (yuanxu-graph-edge-kind edge)
        '(conditional branch router)))

;; : (-> [YuanxuGraphEdge] Boolean)
(def (runtime-has-conditional-edge? edges)
  (cond
   ((null? edges) #f)
   ((runtime-conditional-edge? (car edges)) #t)
   (else
    (runtime-has-conditional-edge? (cdr edges)))))

;; : (-> Object [AgenticAILabGraphBranchChoice] [MaybeChoice [AgenticAILabGraphBranchChoice]])
(def (runtime-next-branch-choice current-id branch-choices)
  (runtime-next-branch-choice/rev current-id branch-choices '()))

;; : (-> Object [AgenticAILabGraphBranchChoice] [AgenticAILabGraphBranchChoice] [MaybeChoice [AgenticAILabGraphBranchChoice]])
(def (runtime-next-branch-choice/rev current-id branch-choices prefix-rev)
  (cond
   ((null? branch-choices)
    (list #f (reverse prefix-rev)))
   ((equal? current-id (.ref (car branch-choices) 'from))
    (list (car branch-choices)
          (append (reverse prefix-rev) (cdr branch-choices))))
   (else
    (runtime-next-branch-choice/rev current-id
                                    (cdr branch-choices)
                                    (cons (car branch-choices)
                                          prefix-rev)))))
