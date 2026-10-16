;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scenario-gap intent objects and proof projections.
;;; - Keep user-authored POO scenario intents separate from bounded Lean/proof fact serialization.
(import (only-in :clan/poo/object .o .ref object<-alist))

(export poo-flow-graph-reducer-intent
        poo-flow-graph-command-intent
        poo-flow-graph-fanout-intent
        poo-flow-graph-barrier-intent
        poo-flow-checkpoint-cadence-intent
        poo-flow-checkpoint-before-intent
        poo-flow-subgraph-node-intent
        poo-flow-subagent-node-intent
        poo-flow-stream-intent
        poo-flow-retry-intent
        poo-flow-timeout-intent
        poo-flow-error-route-intent
        poo-flow-replay-fork-intent
        poo-flow-store-scope-intent
        poo-flow-observability-intent
        poo-flow-state-version-intent
        poo-flow-scenario-gap-plan
        poo-flow-scenario-gap-plan-intents
        poo-flow-scenario-gap-plan-facts
        poo-flow-scenario-gap-plan-complete?
        poo-flow-scenario-gap-plan->lean-facts
        poo-flow-scenario-gap-intent-kinds
        poo-flow-scenario-gap-receipt-missing-kinds
        poo-flow-scenario-gap-runtime-row-plan-ok?
        poo-flow-scenario-gap-runtime-row-rejections-ok?
        poo-flow-scenario-gap-runtime-row-accepted-ok?
        poo-flow-scenario-gap-runtime-row-ok?
        poo-flow-scenario-gap-runtime-row->lean-facts)

;; : (-> Symbol Symbol Symbol Alist PooScenarioGapIntent)
(def (poo-flow-scenario-gap-intent kind priority name fields)
  (object<-alist
   (append
    (list (cons 'kind kind)
          (cons 'priority priority)
          (cons 'name name))
    fields)))

;; P0: graph/platform primitives.
;; : (-> Symbol Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (poo-flow-graph-reducer-intent name state-key reducer value-type update-type)
  (poo-flow-scenario-gap-intent
   'graph.reducer
   'P0
   name
   (list (cons 'state-key state-key)
         (cons 'reducer reducer)
         (cons 'value-type value-type)
         (cons 'update-type update-type))))

;; : (-> Symbol Symbol [Symbol] [Symbol] PooScenarioGapIntent)
(def (poo-flow-graph-command-intent name from-node update-keys goto-targets)
  (poo-flow-scenario-gap-intent
   'graph.command
   'P0
   name
   (list (cons 'from-node from-node)
         (cons 'update-keys update-keys)
         (cons 'goto-targets goto-targets))))

;; : (-> Symbol Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (poo-flow-graph-fanout-intent name from-node task-key target-node result-key)
  (poo-flow-scenario-gap-intent
   'graph.fanout
   'P0
   name
   (list (cons 'from-node from-node)
         (cons 'task-key task-key)
         (cons 'target-node target-node)
         (cons 'result-key result-key))))

;; : (-> Symbol [Symbol] Symbol [Symbol] PooScenarioGapIntent)
(def (poo-flow-graph-barrier-intent name wait-for join-node merge-keys)
  (poo-flow-scenario-gap-intent
   'graph.barrier
   'P0
   name
   (list (cons 'wait-for wait-for)
         (cons 'join-node join-node)
         (cons 'merge-keys merge-keys))))

;; : (-> Symbol Symbol Symbol PooScenarioGapIntent)
(def (poo-flow-checkpoint-cadence-intent name cadence scope)
  (poo-flow-scenario-gap-intent
   'checkpoint.cadence
   'P0
   name
   (list (cons 'cadence cadence)
         (cons 'scope scope))))

;; : (-> Symbol Symbol Symbol PooScenarioGapIntent)
(def (poo-flow-checkpoint-before-intent name before-node checkpoint-key)
  (poo-flow-scenario-gap-intent
   'checkpoint.before
   'P0
   name
   (list (cons 'before-node before-node)
         (cons 'checkpoint-key checkpoint-key))))

;; : (-> Symbol Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (poo-flow-subgraph-node-intent name node child-graph parent-state child-state)
  (poo-flow-scenario-gap-intent
   'graph.subgraph-node
   'P0
   name
   (list (cons 'node node)
         (cons 'child-graph child-graph)
         (cons 'parent-state parent-state)
         (cons 'child-state child-state))))

;; : (-> Symbol Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (poo-flow-subagent-node-intent name node session-key scope-key handoff-target)
  (poo-flow-scenario-gap-intent
   'graph.subagent-node
   'P0
   name
   (list (cons 'node node)
         (cons 'session-key session-key)
         (cons 'scope-key scope-key)
         (cons 'handoff-target handoff-target))))

;; P1: runtime-owned, Scheme-declared primitives.
;; : (-> Symbol [Symbol] [Symbol] PooScenarioGapIntent)
(def (poo-flow-stream-intent name-value event-classes-value projection-labels-value)
  (.o kind: 'runtime.stream
      priority: 'P1
      name: name-value
      event-classes: event-classes-value
      projection-labels: projection-labels-value))

;; : (-> Symbol Symbol Integer Symbol PooScenarioGapIntent)
(def (poo-flow-retry-intent name-value node-value attempts-value backoff-value)
  (.o kind: 'runtime.retry
      priority: 'P1
      name: name-value
      node: node-value
      attempts: attempts-value
      backoff: backoff-value))

;; : (-> Symbol Symbol Integer PooScenarioGapIntent)
(def (poo-flow-timeout-intent name-value node-value timeout-ms-value)
  (.o kind: 'runtime.timeout
      priority: 'P1
      name: name-value
      node: node-value
      timeout-ms: timeout-ms-value))

;; : (-> Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (poo-flow-error-route-intent name-value node-value after-retries-value target-value)
  (.o kind: 'runtime.error-route
      priority: 'P1
      name: name-value
      node: node-value
      after-retries: after-retries-value
      target: target-value))

;; : (-> Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (poo-flow-replay-fork-intent name-value checkpoint-key-value fork-key-value policy-value)
  (.o kind: 'runtime.replay-fork
      priority: 'P1
      name: name-value
      checkpoint-key: checkpoint-key-value
      fork-key: fork-key-value
      policy: policy-value))

;; : (-> Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (poo-flow-store-scope-intent name-value store-key-value scope-value access-value)
  (.o kind: 'runtime.store-scope
      priority: 'P1
      name: name-value
      store-key: store-key-value
      scope: scope-value
      access: access-value))

;; : (-> Symbol [Symbol] [Symbol] PooScenarioGapIntent)
(def (poo-flow-observability-intent name-value labels-value receipt-keys-value)
  (.o kind: 'runtime.observability
      priority: 'P1
      name: name-value
      labels: labels-value
      receipt-keys: receipt-keys-value))

;; P2: production evolution hardening.
;; : (-> Symbol Symbol Symbol Symbol Symbol PooScenarioGapIntent)
(def (poo-flow-state-version-intent name-value state-key-value from-version-value to-version-value drain-policy-value)
  (.o kind: 'profile.state-version
      priority: 'P2
      name: name-value
      state-key: state-key-value
      from-version: from-version-value
      to-version: to-version-value
      drain-policy: drain-policy-value))

;; : (-> Symbol [PooScenarioGapIntent] [PooScenarioGapIntent] [PooScenarioGapIntent] PooScenarioGapPlan)
(def (poo-flow-scenario-gap-plan name p0 p1 p2)
  (.o kind: 'scenario.gap-plan
      plan-id: name
      phase0: p0
      phase1: p1
      phase2: p2))

;; : (-> PooScenarioGapPlan [PooScenarioGapIntent])
(def (poo-flow-scenario-gap-plan-intents plan)
  (append (.ref plan 'phase0)
          (.ref plan 'phase1)
          (.ref plan 'phase2)))

;; : (-> [PooScenarioGapIntent] Symbol Integer)
(def (poo-flow-count-priority intents priority)
  (length
   (filter (lambda (intent) (eq? (.ref intent 'priority) priority))
           intents)))

;; : (-> [PooScenarioGapIntent] Symbol Boolean)
(def (poo-flow-kind-present? intents kind)
  (ormap (lambda (intent) (eq? (.ref intent 'kind) kind))
         intents))

;; : (-> PooScenarioGapPlan PooScenarioGapFacts)
(def (poo-flow-scenario-gap-plan-facts plan)
  (let* ((intents (poo-flow-scenario-gap-plan-intents plan))
         (p0-count (poo-flow-count-priority intents 'P0))
         (p1-count (poo-flow-count-priority intents 'P1))
         (p2-count (poo-flow-count-priority intents 'P2)))
    (object<-alist
     (list
      (cons 'kind 'scenario.gap-facts)
      (cons 'plan (.ref plan 'plan-id))
      (cons 'phase0-count p0-count)
      (cons 'phase1-count p1-count)
      (cons 'phase2-count p2-count)
      (cons 'reducer? (poo-flow-kind-present? intents 'graph.reducer))
      (cons 'command? (poo-flow-kind-present? intents 'graph.command))
      (cons 'fanout? (poo-flow-kind-present? intents 'graph.fanout))
      (cons 'barrier? (poo-flow-kind-present? intents 'graph.barrier))
      (cons 'checkpoint-before?
            (poo-flow-kind-present? intents 'checkpoint.before))
      (cons 'checkpoint-cadence?
            (poo-flow-kind-present? intents 'checkpoint.cadence))
      (cons 'subgraph-node?
            (poo-flow-kind-present? intents 'graph.subgraph-node))
      (cons 'subagent-node?
            (poo-flow-kind-present? intents 'graph.subagent-node))
      (cons 'stream? (poo-flow-kind-present? intents 'runtime.stream))
      (cons 'retry? (poo-flow-kind-present? intents 'runtime.retry))
      (cons 'timeout? (poo-flow-kind-present? intents 'runtime.timeout))
      (cons 'error-route?
            (poo-flow-kind-present? intents 'runtime.error-route))
      (cons 'replay-fork?
            (poo-flow-kind-present? intents 'runtime.replay-fork))
      (cons 'store-scope?
            (poo-flow-kind-present? intents 'runtime.store-scope))
      (cons 'observability?
            (poo-flow-kind-present? intents 'runtime.observability))
      (cons 'state-version?
            (poo-flow-kind-present? intents 'profile.state-version))))))

;; : (-> PooScenarioGapPlan Boolean)
(def (poo-flow-scenario-gap-plan-complete? plan)
  (let ((facts (poo-flow-scenario-gap-plan-facts plan)))
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
(def (poo-flow-scenario-gap-intent-kinds plan)
  (map (lambda (intent) (.ref intent 'kind))
       (poo-flow-scenario-gap-plan-intents plan)))

;; : (-> Symbol [Symbol] Boolean)
(def (poo-flow-symbol-member? value values)
  (if (memq value values) #t #f))

;; : (-> PooScenarioGapPlan [Symbol] [Symbol])
(def (poo-flow-scenario-gap-receipt-missing-kinds plan accepted-kinds)
  (filter
   (lambda (kind)
     (not (poo-flow-symbol-member? kind accepted-kinds)))
   (poo-flow-scenario-gap-intent-kinds plan)))

;; : (-> Alist Symbol Value)
(def (poo-flow-scenario-gap-runtime-row-value row key)
  (let ((cell (assq key row)))
    (if cell (cdr cell) #f)))

;; : (-> Alist Symbol [Value])
(def (poo-flow-scenario-gap-runtime-row-list row key)
  (let ((value (poo-flow-scenario-gap-runtime-row-value row key)))
    (if (list? value) value '())))

;; : (-> PooScenarioGapPlan Alist Boolean)
(def (poo-flow-scenario-gap-runtime-row-plan-ok? plan row)
  (eq? (poo-flow-scenario-gap-runtime-row-value row 'plan-id)
       (.ref plan 'plan-id)))

;; : (-> Alist Boolean)
(def (poo-flow-scenario-gap-runtime-row-rejections-ok? row)
  (null? (poo-flow-scenario-gap-runtime-row-list row 'rejected-kinds)))

;; : (-> PooScenarioGapPlan Alist Boolean)
(def (poo-flow-scenario-gap-runtime-row-accepted-ok? plan row)
  (null? (poo-flow-scenario-gap-receipt-missing-kinds
          plan
          (poo-flow-scenario-gap-runtime-row-list row 'accepted-kinds))))

;; : (-> PooScenarioGapPlan Alist Boolean)
(def (poo-flow-scenario-gap-runtime-row-ok? plan row)
  (and (poo-flow-scenario-gap-runtime-row-plan-ok? plan row)
       (poo-flow-scenario-gap-runtime-row-rejections-ok? row)
       (poo-flow-scenario-gap-runtime-row-accepted-ok? plan row)))

;; : (-> Boolean String)
(def (poo-flow-lean-bool value)
  (if value "true" "false"))

;; : (-> PooScenarioGapPlan String String)
(def (poo-flow-scenario-gap-plan->lean-facts plan module-name)
  (let ((facts (poo-flow-scenario-gap-plan-facts plan)))
    (string-append
     "import PooFlowProof.PooC4.LangChainLangGraph\n\n"
     "namespace PooFlowProof\n\n"
     "def " module-name "P0Count : Nat := "
     (number->string (.ref facts 'phase0-count)) "\n"
     "def " module-name "P1Count : Nat := "
     (number->string (.ref facts 'phase1-count)) "\n"
     "def " module-name "P2Count : Nat := "
     (number->string (.ref facts 'phase2-count)) "\n"
     "def " module-name "HasReducer : Bool := "
     (poo-flow-lean-bool (.ref facts 'reducer?)) "\n"
     "def " module-name "HasCommand : Bool := "
     (poo-flow-lean-bool (.ref facts 'command?)) "\n"
     "def " module-name "HasCheckpointBefore : Bool := "
     (poo-flow-lean-bool (.ref facts 'checkpoint-before?)) "\n"
     "def " module-name "Complete : Bool := "
     (poo-flow-lean-bool (poo-flow-scenario-gap-plan-complete? plan)) "\n\n"
     "theorem " module-name "Complete_ok : "
     module-name "Complete = true := by\n"
     "  rfl\n\n"
     "end PooFlowProof\n")))

;; : (-> PooScenarioGapPlan Alist String String)
(def (poo-flow-scenario-gap-runtime-row->lean-facts plan row module-name)
  (let ((plan-ok
         (poo-flow-scenario-gap-runtime-row-plan-ok? plan row))
        (rejections-ok
         (poo-flow-scenario-gap-runtime-row-rejections-ok? row))
        (accepted-ok
         (poo-flow-scenario-gap-runtime-row-accepted-ok? plan row))
        (row-ok
         (poo-flow-scenario-gap-runtime-row-ok? plan row)))
    (string-append
     "import PooFlowProof.PooC4.ScenarioGap\n\n"
     "namespace PooFlowProof\n\n"
     "def " module-name "RuntimeRowFacts : ScenarioRuntimeRowFacts :=\n"
     "  { planOk := " (poo-flow-lean-bool plan-ok) "\n"
     "    rejectionsOk := " (poo-flow-lean-bool rejections-ok) "\n"
     "    acceptedOk := " (poo-flow-lean-bool accepted-ok) " }\n\n"
     "def " module-name "RuntimeRowComplete : Bool := "
     (poo-flow-lean-bool row-ok) "\n\n"
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
     "end PooFlowProof\n")))
