;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scenario-gap intent objects and proof projections.
;;; - Keep user-authored POO scenario intents separate from bounded Lean/proof fact serialization.
(import (only-in :clan/poo/object .o .ref object<-alist))

(export agentic-ai-lab-graph-reducer-intent
        agentic-ai-lab-graph-command-intent
        agentic-ai-lab-graph-fanout-intent
        agentic-ai-lab-graph-barrier-intent
        agentic-ai-lab-checkpoint-cadence-intent
        agentic-ai-lab-checkpoint-before-intent
        agentic-ai-lab-subgraph-node-intent
        agentic-ai-lab-subagent-node-intent
        agentic-ai-lab-stream-intent
        agentic-ai-lab-retry-intent
        agentic-ai-lab-timeout-intent
        agentic-ai-lab-error-route-intent
        agentic-ai-lab-replay-fork-intent
        agentic-ai-lab-store-scope-intent
        agentic-ai-lab-observability-intent
        agentic-ai-lab-state-version-intent
        agentic-ai-lab-scenario-gap-plan
        agentic-ai-lab-scenario-gap-plan-intents
        agentic-ai-lab-scenario-gap-plan-facts
        agentic-ai-lab-scenario-gap-plan-complete?
        agentic-ai-lab-scenario-gap-plan->lean-facts
        agentic-ai-lab-scenario-gap-intent-kinds
        agentic-ai-lab-scenario-gap-receipt-missing-kinds
        agentic-ai-lab-scenario-gap-runtime-row-plan-ok?
        agentic-ai-lab-scenario-gap-runtime-row-rejections-ok?
        agentic-ai-lab-scenario-gap-runtime-row-accepted-ok?
        agentic-ai-lab-scenario-gap-runtime-row-ok?
        agentic-ai-lab-scenario-gap-runtime-row->lean-facts)

;; : (-> Symbol Symbol Symbol Alist PooScenarioGapIntent)
(def (agentic-ai-lab-scenario-gap-intent kind priority name fields)
  (object<-alist
   (append
    (list (cons 'kind kind)
          (cons 'priority priority)
          (cons 'name name))
    fields)))

;; P0: graph/platform primitives.
;; : (-> Symbol Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-graph-reducer-intent name state-key reducer value-type update-type)
  (agentic-ai-lab-scenario-gap-intent
   'graph.reducer
   'P0
   name
   (list (cons 'state-key state-key)
         (cons 'reducer reducer)
         (cons 'value-type value-type)
         (cons 'update-type update-type))))

;; : (-> Symbol Symbol [Symbol] [Symbol] PooScenarioGapIntent)
(def (agentic-ai-lab-graph-command-intent name from-node update-keys goto-targets)
  (agentic-ai-lab-scenario-gap-intent
   'graph.command
   'P0
   name
   (list (cons 'from-node from-node)
         (cons 'update-keys update-keys)
         (cons 'goto-targets goto-targets))))

;; : (-> Symbol Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-graph-fanout-intent name from-node task-key target-node result-key)
  (agentic-ai-lab-scenario-gap-intent
   'graph.fanout
   'P0
   name
   (list (cons 'from-node from-node)
         (cons 'task-key task-key)
         (cons 'target-node target-node)
         (cons 'result-key result-key))))

;; : (-> Symbol [Symbol] Symbol [Symbol] PooScenarioGapIntent)
(def (agentic-ai-lab-graph-barrier-intent name wait-for join-node merge-keys)
  (agentic-ai-lab-scenario-gap-intent
   'graph.barrier
   'P0
   name
   (list (cons 'wait-for wait-for)
         (cons 'join-node join-node)
         (cons 'merge-keys merge-keys))))

;; : (-> Symbol Symbol Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-checkpoint-cadence-intent name cadence scope)
  (agentic-ai-lab-scenario-gap-intent
   'checkpoint.cadence
   'P0
   name
   (list (cons 'cadence cadence)
         (cons 'scope scope))))

;; : (-> Symbol Symbol Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-checkpoint-before-intent name before-node checkpoint-key)
  (agentic-ai-lab-scenario-gap-intent
   'checkpoint.before
   'P0
   name
   (list (cons 'before-node before-node)
         (cons 'checkpoint-key checkpoint-key))))

;; : (-> Symbol Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-subgraph-node-intent name node child-graph parent-state child-state)
  (agentic-ai-lab-scenario-gap-intent
   'graph.subgraph-node
   'P0
   name
   (list (cons 'node node)
         (cons 'child-graph child-graph)
         (cons 'parent-state parent-state)
         (cons 'child-state child-state))))

;; : (-> Symbol Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-subagent-node-intent name node session-key scope-key handoff-target)
  (agentic-ai-lab-scenario-gap-intent
   'graph.subagent-node
   'P0
   name
   (list (cons 'node node)
         (cons 'session-key session-key)
         (cons 'scope-key scope-key)
         (cons 'handoff-target handoff-target))))

;; P1: runtime-owned, Scheme-declared primitives.
;; : (-> Symbol [Symbol] [Symbol] PooScenarioGapIntent)
(def (agentic-ai-lab-stream-intent name-value event-classes-value projection-labels-value)
  (.o kind: 'runtime.stream
      priority: 'P1
      name: name-value
      event-classes: event-classes-value
      projection-labels: projection-labels-value))

;; : (-> Symbol Symbol Integer Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-retry-intent name-value node-value attempts-value backoff-value)
  (.o kind: 'runtime.retry
      priority: 'P1
      name: name-value
      node: node-value
      attempts: attempts-value
      backoff: backoff-value))

;; : (-> Symbol Symbol Integer PooScenarioGapIntent)
(def (agentic-ai-lab-timeout-intent name-value node-value timeout-ms-value)
  (.o kind: 'runtime.timeout
      priority: 'P1
      name: name-value
      node: node-value
      timeout-ms: timeout-ms-value))

;; : (-> Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-error-route-intent name-value node-value after-retries-value target-value)
  (.o kind: 'runtime.error-route
      priority: 'P1
      name: name-value
      node: node-value
      after-retries: after-retries-value
      target: target-value))

;; : (-> Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-replay-fork-intent name-value checkpoint-key-value fork-key-value policy-value)
  (.o kind: 'runtime.replay-fork
      priority: 'P1
      name: name-value
      checkpoint-key: checkpoint-key-value
      fork-key: fork-key-value
      policy: policy-value))

;; : (-> Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-store-scope-intent name-value store-key-value scope-value access-value)
  (.o kind: 'runtime.store-scope
      priority: 'P1
      name: name-value
      store-key: store-key-value
      scope: scope-value
      access: access-value))

;; : (-> Symbol [Symbol] [Symbol] PooScenarioGapIntent)
(def (agentic-ai-lab-observability-intent name-value labels-value receipt-keys-value)
  (.o kind: 'runtime.observability
      priority: 'P1
      name: name-value
      labels: labels-value
      receipt-keys: receipt-keys-value))

;; P2: production evolution hardening.
;; : (-> Symbol Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (agentic-ai-lab-state-version-intent name-value state-key-value from-version-value to-version-value drain-policy-value)
  (.o kind: 'profile.state-version
      priority: 'P2
      name: name-value
      state-key: state-key-value
      from-version: from-version-value
      to-version: to-version-value
      drain-policy: drain-policy-value))

;; : (-> Symbol [PooScenarioGapIntent] [PooScenarioGapIntent] [PooScenarioGapIntent] PooScenarioGapPlan)
(def (agentic-ai-lab-scenario-gap-plan name p0 p1 p2)
  (.o kind: 'scenario.gap-plan
      plan-id: name
      phase0: p0
      phase1: p1
      phase2: p2))

;; : (-> PooScenarioGapPlan [PooScenarioGapIntent])
(def (agentic-ai-lab-scenario-gap-plan-intents plan)
  (append (.ref plan 'phase0)
          (.ref plan 'phase1)
          (.ref plan 'phase2)))

;; : (-> [PooScenarioGapIntent] Symbol Integer)
(def (agentic-ai-lab-count-priority intents priority)
  (length
   (filter (lambda (intent) (eq? (.ref intent 'priority) priority))
           intents)))

;; : (-> [PooScenarioGapIntent] Symbol Boolean)
(def (agentic-ai-lab-kind-present? intents kind)
  (ormap (lambda (intent) (eq? (.ref intent 'kind) kind))
         intents))

;; : (-> PooScenarioGapPlan PooScenarioGapFacts)
(def (agentic-ai-lab-scenario-gap-plan-facts plan)
  (let* ((intents (agentic-ai-lab-scenario-gap-plan-intents plan))
         (p0-count (agentic-ai-lab-count-priority intents 'P0))
         (p1-count (agentic-ai-lab-count-priority intents 'P1))
         (p2-count (agentic-ai-lab-count-priority intents 'P2)))
    (object<-alist
     (list
      (cons 'kind 'scenario.gap-facts)
      (cons 'plan (.ref plan 'plan-id))
      (cons 'phase0-count p0-count)
      (cons 'phase1-count p1-count)
      (cons 'phase2-count p2-count)
      (cons 'reducer? (agentic-ai-lab-kind-present? intents 'graph.reducer))
      (cons 'command? (agentic-ai-lab-kind-present? intents 'graph.command))
      (cons 'fanout? (agentic-ai-lab-kind-present? intents 'graph.fanout))
      (cons 'barrier? (agentic-ai-lab-kind-present? intents 'graph.barrier))
      (cons 'checkpoint-before?
            (agentic-ai-lab-kind-present? intents 'checkpoint.before))
      (cons 'checkpoint-cadence?
            (agentic-ai-lab-kind-present? intents 'checkpoint.cadence))
      (cons 'subgraph-node?
            (agentic-ai-lab-kind-present? intents 'graph.subgraph-node))
      (cons 'subagent-node?
            (agentic-ai-lab-kind-present? intents 'graph.subagent-node))
      (cons 'stream? (agentic-ai-lab-kind-present? intents 'runtime.stream))
      (cons 'retry? (agentic-ai-lab-kind-present? intents 'runtime.retry))
      (cons 'timeout? (agentic-ai-lab-kind-present? intents 'runtime.timeout))
      (cons 'error-route?
            (agentic-ai-lab-kind-present? intents 'runtime.error-route))
      (cons 'replay-fork?
            (agentic-ai-lab-kind-present? intents 'runtime.replay-fork))
      (cons 'store-scope?
            (agentic-ai-lab-kind-present? intents 'runtime.store-scope))
      (cons 'observability?
            (agentic-ai-lab-kind-present? intents 'runtime.observability))
      (cons 'state-version?
            (agentic-ai-lab-kind-present? intents 'profile.state-version))))))

;; : (-> PooScenarioGapPlan Boolean)
(def (agentic-ai-lab-scenario-gap-plan-complete? plan)
  (let ((facts (agentic-ai-lab-scenario-gap-plan-facts plan)))
    (and (> (.ref facts 'phase0-count) 0)
         (> (.ref facts 'phase1-count) 0)
         (> (.ref facts 'phase2-count) 0)
         (.ref facts 'reducer?)
         (.ref facts 'command?)
         (.ref facts 'fanout?)
         (.ref facts 'barrier?)
         (.ref facts 'checkpoint-before?)
         (.ref facts 'checkpoint-cadence?)
         (.ref facts 'subgraph-node?)
         (.ref facts 'subagent-node?)
         (.ref facts 'stream?)
         (.ref facts 'retry?)
         (.ref facts 'timeout?)
         (.ref facts 'error-route?)
         (.ref facts 'replay-fork?)
         (.ref facts 'store-scope?)
         (.ref facts 'observability?)
         (.ref facts 'state-version?))))

;; : (-> PooScenarioGapPlan [Symbol])
(def (agentic-ai-lab-scenario-gap-intent-kinds plan)
  (map (lambda (intent) (.ref intent 'kind))
       (agentic-ai-lab-scenario-gap-plan-intents plan)))

;; : (-> Symbol [Symbol] Boolean)
(def (agentic-ai-lab-symbol-member? value values)
  (if (memq value values) #t #f))

;; : (-> PooScenarioGapPlan [Symbol] [Symbol])
(def (agentic-ai-lab-scenario-gap-receipt-missing-kinds plan accepted-kinds)
  (filter
   (lambda (kind)
     (not (agentic-ai-lab-symbol-member? kind accepted-kinds)))
   (agentic-ai-lab-scenario-gap-intent-kinds plan)))

;; : (-> Alist Symbol Value)
(def (agentic-ai-lab-scenario-gap-runtime-row-value row key)
  (let ((cell (assq key row)))
    (if cell (cdr cell) #f)))

;; : (-> Alist Symbol [Value])
(def (agentic-ai-lab-scenario-gap-runtime-row-list row key)
  (let ((value (agentic-ai-lab-scenario-gap-runtime-row-value row key)))
    (if (list? value) value '())))

;; : (-> PooScenarioGapPlan Alist Boolean)
(def (agentic-ai-lab-scenario-gap-runtime-row-plan-ok? plan row)
  (eq? (agentic-ai-lab-scenario-gap-runtime-row-value row 'plan-id)
       (.ref plan 'plan-id)))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-scenario-gap-runtime-row-rejections-ok? row)
  (null? (agentic-ai-lab-scenario-gap-runtime-row-list row 'rejected-kinds)))

;; : (-> PooScenarioGapPlan Alist Boolean)
(def (agentic-ai-lab-scenario-gap-runtime-row-accepted-ok? plan row)
  (null? (agentic-ai-lab-scenario-gap-receipt-missing-kinds
          plan
          (agentic-ai-lab-scenario-gap-runtime-row-list row 'accepted-kinds))))

;; : (-> PooScenarioGapPlan Alist Boolean)
(def (agentic-ai-lab-scenario-gap-runtime-row-ok? plan row)
  (and (agentic-ai-lab-scenario-gap-runtime-row-plan-ok? plan row)
       (agentic-ai-lab-scenario-gap-runtime-row-rejections-ok? row)
       (agentic-ai-lab-scenario-gap-runtime-row-accepted-ok? plan row)))

;; : (-> Boolean String)
(def (agentic-ai-lab-lean-bool value)
  (if value "true" "false"))

;; : (-> PooScenarioGapPlan String String)
(def (agentic-ai-lab-scenario-gap-plan->lean-facts plan module-name)
  (let ((facts (agentic-ai-lab-scenario-gap-plan-facts plan)))
    (string-append
     "import AgenticAILabProof.PooC4.LangChainLangGraph\n\n"
     "namespace AgenticAILabProof\n\n"
     "def " module-name "P0Count : Nat := "
     (number->string (.ref facts 'phase0-count)) "\n"
     "def " module-name "P1Count : Nat := "
     (number->string (.ref facts 'phase1-count)) "\n"
     "def " module-name "P2Count : Nat := "
     (number->string (.ref facts 'phase2-count)) "\n"
     "def " module-name "HasReducer : Bool := "
     (agentic-ai-lab-lean-bool (.ref facts 'reducer?)) "\n"
     "def " module-name "HasCommand : Bool := "
     (agentic-ai-lab-lean-bool (.ref facts 'command?)) "\n"
     "def " module-name "HasCheckpointBefore : Bool := "
     (agentic-ai-lab-lean-bool (.ref facts 'checkpoint-before?)) "\n"
     "def " module-name "Complete : Bool := "
     (agentic-ai-lab-lean-bool (agentic-ai-lab-scenario-gap-plan-complete? plan)) "\n\n"
     "theorem " module-name "Complete_ok : "
     module-name "Complete = true := by\n"
     "  rfl\n\n"
     "end AgenticAILabProof\n")))

;; : (-> PooScenarioGapPlan Alist String String)
(def (agentic-ai-lab-scenario-gap-runtime-row->lean-facts plan row module-name)
  (let ((plan-ok
         (agentic-ai-lab-scenario-gap-runtime-row-plan-ok? plan row))
        (rejections-ok
         (agentic-ai-lab-scenario-gap-runtime-row-rejections-ok? row))
        (accepted-ok
         (agentic-ai-lab-scenario-gap-runtime-row-accepted-ok? plan row))
        (row-ok
         (agentic-ai-lab-scenario-gap-runtime-row-ok? plan row)))
    (string-append
     "import AgenticAILabProof.PooC4.ScenarioGap\n\n"
     "namespace AgenticAILabProof\n\n"
     "def " module-name "RuntimeRowFacts : ScenarioRuntimeRowFacts :=\n"
     "  { planOk := " (agentic-ai-lab-lean-bool plan-ok) "\n"
     "    rejectionsOk := " (agentic-ai-lab-lean-bool rejections-ok) "\n"
     "    acceptedOk := " (agentic-ai-lab-lean-bool accepted-ok) " }\n\n"
     "def " module-name "RuntimeRowComplete : Bool := "
     (agentic-ai-lab-lean-bool row-ok) "\n\n"
     "theorem " module-name "RuntimeRowComplete_ok : "
     module-name "RuntimeRowComplete = true := by\n"
     "  rfl\n\n"
     (if row-ok
       (string-append
        "theorem " module-name "RuntimeRowMatches :\n"
        "    runtimeRowMatchesPlan " module-name "RuntimeRowFacts := by\n"
        "  unfold runtimeRowMatchesPlan " module-name "RuntimeRowFacts\n"
        "  decide\n\n")
       "")
     "end AgenticAILabProof\n")))
