;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/workflow/graph/scenario-gap-intent)

(import (only-in :std/test test-suite))

(def langgraph-scenario-gap-intent-test
  (test-suite "LangGraph scenario gap intent"
    (yuanxu-test-case "projects exact runtime and Lean facts"

(def (check-equal label actual expected)
  (unless (equal? actual expected)
    (error "check failed" label actual expected)))

(def (check-true label value)
  (unless value
    (error "check failed" label value #t)))

(def (contains-string? text needle)
  (let ((text-len (string-length text))
        (needle-len (string-length needle)))
    (let loop ((index 0))
      (cond
       ((> (+ index needle-len) text-len) #f)
       ((equal? (substring text index (+ index needle-len)) needle) #t)
       (else (loop (+ index 1)))))))

(def (remove-symbol value values)
  (let loop ((rest values) (kept '()))
    (cond
     ((null? rest) (reverse kept))
     ((eq? value (car rest)) (loop (cdr rest) kept))
     (else (loop (cdr rest) (cons (car rest) kept))))))

(def p0-intents
  (list
   (agentic-ai-lab-graph-reducer-intent
    'messages-append 'messages 'append 'message-list 'message-list)
   (agentic-ai-lab-graph-command-intent
    'router-command 'router '(messages) '(tool-node final))
   (agentic-ai-lab-graph-fanout-intent
    'retriever-fanout 'router 'queries 'retriever 'documents)
   (agentic-ai-lab-graph-barrier-intent
    'retriever-join '(retriever) 'agent-node '(documents))
   (agentic-ai-lab-checkpoint-cadence-intent
    'checkpoint-each-superstep 'superstep 'thread)
   (agentic-ai-lab-checkpoint-before-intent
    'checkpoint-before-approval 'human-approval 'thread-checkpoint)
   (agentic-ai-lab-subgraph-node-intent
    'research-subgraph 'research-node 'research-graph '(query) '(query docs))
   (agentic-ai-lab-subagent-node-intent
    'analysis-subagent 'analysis-node 'session-id 'sandbox-scope 'marlin)))

(def p1-intents
  (list
   (agentic-ai-lab-stream-intent
    'typed-stream '(messages values subgraphs output) '(ui audit))
   (agentic-ai-lab-retry-intent
    'tool-retry 'tool-node 3 'exponential)
   (agentic-ai-lab-timeout-intent
    'tool-timeout 'tool-node 30000)
   (agentic-ai-lab-error-route-intent
    'tool-error-route 'tool-node 'after-retries 'human-approval)
   (agentic-ai-lab-replay-fork-intent
    'checkpoint-fork 'thread-checkpoint 'fork-id 'explicit-approval)
   (agentic-ai-lab-store-scope-intent
    'profile-store 'store-id 'user-profile '(read write))
   (agentic-ai-lab-observability-intent
    'runtime-observability '(graph-node checkpoint retry timeout)
    '(plan-id receipt-id trace-id))))

(def p2-intents
  (list
   (agentic-ai-lab-state-version-intent
    'messages-v1-v2 'messages 'v1 'v2 'drain-before-remove)))

(def plan
  (agentic-ai-lab-scenario-gap-plan
   'langgraph-like-gap-plan
   p0-intents
   p1-intents
   p2-intents))

(def facts (agentic-ai-lab-scenario-gap-plan-facts plan))

(displayln "Test suite: LangGraph scenario gap intent")

(check-equal 'plan-kind (.ref plan 'kind) 'scenario.gap-plan)
(check-equal 'phase0-count (.ref facts 'phase0-count) 8)
(check-equal 'phase1-count (.ref facts 'phase1-count) 7)
(check-equal 'phase2-count (.ref facts 'phase2-count) 1)

(for-each
 (lambda (slot)
   (check-true slot (.ref facts slot)))
 '(reducer?
   command?
   fanout?
   barrier?
   checkpoint-before?
   checkpoint-cadence?
   subgraph-node?
   subagent-node?
   stream?
   retry?
   timeout?
   error-route?
   replay-fork?
   store-scope?
   observability?
   state-version?))

(check-true 'complete? (agentic-ai-lab-scenario-gap-plan-complete? plan))

(def accepted-kinds
  (agentic-ai-lab-scenario-gap-intent-kinds plan))

(check-equal 'missing-kinds-none
             (agentic-ai-lab-scenario-gap-receipt-missing-kinds plan accepted-kinds)
             '())

(check-equal 'missing-kinds-error-route
             (agentic-ai-lab-scenario-gap-receipt-missing-kinds
              plan
              (remove-symbol 'runtime.error-route accepted-kinds))
             '(runtime.error-route))

(def runtime-row
  (list (cons 'kind 'scenario.receipt)
        (cons 'receipt-id 'receipt-1)
        (cons 'runtime 'marlin)
        (cons 'plan-id 'langgraph-like-gap-plan)
        (cons 'accepted-kinds accepted-kinds)
        (cons 'rejected-kinds '())))

(check-true 'runtime-row-plan-ok
            (agentic-ai-lab-scenario-gap-runtime-row-plan-ok? plan runtime-row))
(check-true 'runtime-row-rejections-ok
            (agentic-ai-lab-scenario-gap-runtime-row-rejections-ok? runtime-row))
(check-true 'runtime-row-accepted-ok
            (agentic-ai-lab-scenario-gap-runtime-row-accepted-ok? plan runtime-row))
(check-true 'runtime-row-ok
            (agentic-ai-lab-scenario-gap-runtime-row-ok? plan runtime-row))

(def missing-kind-row
  (list (cons 'kind 'scenario.receipt)
        (cons 'receipt-id 'receipt-2)
        (cons 'runtime 'marlin)
        (cons 'plan-id 'langgraph-like-gap-plan)
        (cons 'accepted-kinds
              (remove-symbol 'runtime.error-route accepted-kinds))
        (cons 'rejected-kinds '())))

(check-equal 'runtime-row-missing-kind-rejected
             (agentic-ai-lab-scenario-gap-runtime-row-ok? plan missing-kind-row)
             #f)

(def wrong-plan-row
  (list (cons 'kind 'scenario.receipt)
        (cons 'receipt-id 'receipt-3)
        (cons 'runtime 'marlin)
        (cons 'plan-id 'other-plan)
        (cons 'accepted-kinds accepted-kinds)
        (cons 'rejected-kinds '())))

(check-equal 'runtime-row-wrong-plan-rejected
             (agentic-ai-lab-scenario-gap-runtime-row-ok? plan wrong-plan-row)
             #f)

(def rejected-kind-row
  (list (cons 'kind 'scenario.receipt)
        (cons 'receipt-id 'receipt-4)
        (cons 'runtime 'marlin)
        (cons 'plan-id 'langgraph-like-gap-plan)
        (cons 'accepted-kinds accepted-kinds)
        (cons 'rejected-kinds '(runtime.timeout))))

(check-equal 'runtime-row-rejected-kind-rejected
             (agentic-ai-lab-scenario-gap-runtime-row-ok? plan rejected-kind-row)
             #f)

(def runtime-row-lean-source
  (agentic-ai-lab-scenario-gap-runtime-row->lean-facts
   plan
   runtime-row
   "GeneratedScenarioGap"))

(check-true 'runtime-row-lean-facts
            (contains-string?
             runtime-row-lean-source
             "def GeneratedScenarioGapRuntimeRowFacts"))
(check-true 'runtime-row-lean-matches
            (contains-string?
             runtime-row-lean-source
             "theorem GeneratedScenarioGapRuntimeRowMatches"))

(def expected-runtime-row-lean-source
  (string-append
   "import AgenticAILabProof.PooC4.ScenarioGap\n\n"
   "namespace AgenticAILabProof\n\n"
   "def GeneratedScenarioGapRuntimeRowFacts : ScenarioRuntimeRowFacts :=\n"
   "  { planOk := true\n"
   "    rejectionsOk := true\n"
   "    acceptedOk := true }\n\n"
   "def GeneratedScenarioGapRuntimeRowComplete : Bool := true\n\n"
   "theorem GeneratedScenarioGapRuntimeRowComplete_ok : "
   "GeneratedScenarioGapRuntimeRowComplete = true := by\n"
   "  rfl\n\n"
   "theorem GeneratedScenarioGapRuntimeRowMatches :\n"
   "    runtimeRowMatchesPlan GeneratedScenarioGapRuntimeRowFacts := by\n"
   "  unfold runtimeRowMatchesPlan GeneratedScenarioGapRuntimeRowFacts\n"
   "  decide\n\n"
   "end AgenticAILabProof\n"))

(check-equal 'runtime-row-lean-source-exact
             runtime-row-lean-source
             expected-runtime-row-lean-source)

(def invalid-row-lean-source
  (agentic-ai-lab-scenario-gap-runtime-row->lean-facts
   plan
   missing-kind-row
   "GeneratedScenarioGapInvalid"))

(check-true 'invalid-row-lean-false
            (contains-string?
             invalid-row-lean-source
             "def GeneratedScenarioGapInvalidRuntimeRowComplete : Bool := false"))
(check-equal 'invalid-row-no-matches-theorem
             (contains-string?
              invalid-row-lean-source
              "theorem GeneratedScenarioGapInvalidRuntimeRowMatches")
             #f)

(def lean-source
  (agentic-ai-lab-scenario-gap-plan->lean-facts plan "GeneratedScenarioGap"))

(check-true 'lean-complete
            (contains-string? lean-source "GeneratedScenarioGapComplete_ok"))
(check-true 'lean-p0
            (contains-string? lean-source "GeneratedScenarioGapP0Count : Nat := 8")))))
