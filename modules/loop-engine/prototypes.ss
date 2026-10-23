;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public loop-engine POO prototype objects.
;;; Invariant: prototypes are declaration data and never execute runtime work.

(import (only-in :clan/poo/object .o object<-alist))

(export +agentic-ai-lab-user-loop-engine-use-case-prototype-kind+
        +agentic-ai-lab-user-loop-engine-governor-prototype-kind+
        +agentic-ai-lab-user-loop-engine-agent-judges-prototype-kind+
        +agentic-ai-lab-user-loop-engine-human-audit-prototype-kind+
        +agentic-ai-lab-user-loop-engine-schedule-prototype-kind+
        +agentic-ai-lab-user-loop-engine-state-prototype-kind+
        +agentic-ai-lab-user-loop-engine-sandbox-prototype-kind+
        +agentic-ai-lab-user-loop-engine-budget-prototype-kind+
        +agentic-ai-lab-user-loop-engine-result-prototype-kind+
        +agentic-ai-lab-user-loop-engine-observability-prototype-kind+
        +agentic-ai-lab-user-loop-engine-runtime-prototype-kind+
        +agentic-ai-lab-user-loop-engine-lineage-policy-prototype-kind+
        +agentic-ai-lab-user-loop-engine-selector-policy-prototype-kind+
        +agentic-ai-lab-user-loop-engine-resource-policy-prototype-kind+
        +agentic-ai-lab-user-loop-engine-capability-policy-prototype-kind+
        +agentic-ai-lab-user-loop-engine-memory-policy-prototype-kind+
        +agentic-ai-lab-user-loop-engine-compression-policy-prototype-kind+
        +agentic-ai-lab-user-loop-engine-profile-prototype-kind+
        loop-engine-use-case
        loop-engine-governor
        loop-engine-agent-judges
        loop-engine-human-audit
        loop-engine-schedule
        loop-engine-state
        loop-engine-sandbox
        loop-engine-budget
        loop-engine-result
        loop-engine-observability
        loop-engine-runtime
        loop-engine-lineage-policy
        loop-engine-selector-policy
        loop-engine-resource-policy
        loop-engine-capability-policy
        loop-engine-memory-policy
        loop-engine-compression-policy
        loop-engine-profile)

;;; Prototype kind symbols are the inheritance anchors used by POO slot
;;; validation and report lowering. They are intentionally separate from schema
;;; contract ids consumed by Marlin.
;; : Symbol
(def +agentic-ai-lab-user-loop-engine-use-case-prototype-kind+
  'agentic-ai-lab.loop-engine.use-case.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-governor-prototype-kind+
  'agentic-ai-lab.loop-engine.governor.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-agent-judges-prototype-kind+
  'agentic-ai-lab.loop-engine.agent-judges.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-human-audit-prototype-kind+
  'agentic-ai-lab.loop-engine.human-audit.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-schedule-prototype-kind+
  'agentic-ai-lab.loop-engine.schedule.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-state-prototype-kind+
  'agentic-ai-lab.loop-engine.state.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-sandbox-prototype-kind+
  'agentic-ai-lab.loop-engine.sandbox.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-budget-prototype-kind+
  'agentic-ai-lab.loop-engine.budget.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-result-prototype-kind+
  'agentic-ai-lab.loop-engine.result.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-observability-prototype-kind+
  'agentic-ai-lab.loop-engine.observability.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-runtime-prototype-kind+
  'agentic-ai-lab.loop-engine.runtime.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-lineage-policy-prototype-kind+
  'agentic-ai-lab.loop-engine.lineage-policy.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-selector-policy-prototype-kind+
  'agentic-ai-lab.loop-engine.selector-policy.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-resource-policy-prototype-kind+
  'agentic-ai-lab.loop-engine.resource-policy.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-capability-policy-prototype-kind+
  'agentic-ai-lab.loop-engine.capability-policy.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-memory-policy-prototype-kind+
  'agentic-ai-lab.loop-engine.memory-policy.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-compression-policy-prototype-kind+
  'agentic-ai-lab.loop-engine.compression-policy.prototype)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-profile-prototype-kind+
  'agentic-ai-lab.loop-engine.profile.prototype)

;;; A use-case object is the named work item in a loop profile. The workflow ref
;;; stays optional because not every loop is backed by a Funflow DAG yet.
;; : AgenticAILabLoopEngineUseCasePrototype
(def loop-engine-use-case
  (.o kind: +agentic-ai-lab-user-loop-engine-use-case-prototype-kind+
      name: #f
      level: #f
      mode: #f
      goal: #f
      workflow: #f
      metadata: '()
      runtime-executed: #f))

;;; Governor capabilities are strategy knobs. They are not executable handlers.
;; : AgenticAILabLoopEngineGovernorPrototype
(def loop-engine-governor
  (.o kind: +agentic-ai-lab-user-loop-engine-governor-prototype-kind+
      capabilities: '()
      metadata: '()
      runtime-executed: #f))

;;; Agent judge objects name roles and profile refs used by Marlin later.
;; : AgenticAILabLoopEngineAgentJudgesPrototype
(def loop-engine-agent-judges
  (.o kind: +agentic-ai-lab-user-loop-engine-agent-judges-prototype-kind+
      auditor: #f
      verifier: #f
      reviewer: #f
      governor: #f
      metadata: '()
      runtime-executed: #f))

;; : AgenticAILabLoopEngineHumanAuditPrototype
(def loop-engine-human-audit
  (.o kind: +agentic-ai-lab-user-loop-engine-human-audit-prototype-kind+
      actions: '()
      metadata: '()
      runtime-executed: #f))

;; : AgenticAILabLoopEngineSchedulePrototype
(def loop-engine-schedule
  (.o kind: +agentic-ai-lab-user-loop-engine-schedule-prototype-kind+
      trigger: #f
      cadence: #f
      entries: '()
      runtime-executed: #f))

;; : AgenticAILabLoopEngineStatePrototype
(def loop-engine-state
  (.o kind: +agentic-ai-lab-user-loop-engine-state-prototype-kind+
      store: #f
      path: #f
      acting-on: #f
      entries: '()
      runtime-executed: #f))

;;; Sandbox refs can be global profile refs or per-use-case profile refs.
;; : AgenticAILabLoopEngineSandboxPrototype
(def loop-engine-sandbox
  (.o kind: +agentic-ai-lab-user-loop-engine-sandbox-prototype-kind+
      profile: #f
      isolation: #f
      profile-refs: '()
      case-profile-refs: '()
      entries: '()
      runtime-executed: #f))

;; : AgenticAILabLoopEngineBudgetPrototype
(def loop-engine-budget
  (.o kind: +agentic-ai-lab-user-loop-engine-budget-prototype-kind+
      max-actionable: #f
      max-attempts: #f
      weekly-runs: #f
      entries: '()
      runtime-executed: #f))

;; : AgenticAILabLoopEngineResultPrototype
(def loop-engine-result
  (.o kind: +agentic-ai-lab-user-loop-engine-result-prototype-kind+
      default: #f
      auditor: #f
      verifier: #f
      reviewer: #f
      governor: #f
      human-audit: #f
      format: 'structured-alist
      required-fields: '(decision summary evidence)
      entries: '()
      runtime-executed: #f))

;; : AgenticAILabLoopEngineObservabilityPrototype
(def loop-engine-observability
  (.o kind: +agentic-ai-lab-user-loop-engine-observability-prototype-kind+
      receipt: #f
      run-log: #f
      entries: '()
      runtime-executed: #f))

;; : AgenticAILabLoopEngineRuntimePrototype
(def loop-engine-runtime
  (.o kind: +agentic-ai-lab-user-loop-engine-runtime-prototype-kind+
      capabilities: '(+manifest-handoff)
      handoff: 'loop-governor-marlin-runtime-manifest
      owner: "marlin-agent-core"
      entries: '()
      runtime-executed: #f))

;;; Lineage policy mirrors OpenRath's session-first audit trail without making
;;; Scheme persist sessions. It only describes the report-only receipt shape.
;; : AgenticAILabLoopEngineLineagePolicyPrototype
(def loop-engine-lineage-policy
  (.o kind: +agentic-ai-lab-user-loop-engine-lineage-policy-prototype-kind+
      parent-session-refs: '()
      lineage-kind: #f
      lineage-operator: #f
      journal: #f
      export: #f
      entries: '()
      runtime-executed: #f))

;;; Selector policy keeps branch selection inspectable while model scoring and
;;; runtime routing stay Marlin-owned.
;; : AgenticAILabLoopEngineSelectorPolicyPrototype
(def loop-engine-selector-policy
  (.o kind: +agentic-ai-lab-user-loop-engine-selector-policy-prototype-kind+
      candidates: '()
      judge-inputs: '()
      fallback: #f
      selected-branch: #f
      entries: '()
      runtime-executed: #f))

;;; Resource policy models OpenRath-style resource keys as declaration data.
;;; The Scheme side may project serial/parallel groups but never schedules them.
;; : AgenticAILabLoopEngineResourcePolicyPrototype
(def loop-engine-resource-policy
  (.o kind: +agentic-ai-lab-user-loop-engine-resource-policy-prototype-kind+
      tool-refs: '()
      resource-keys: '()
      collision-classes: '()
      dispatch-groups: '()
      entries: '()
      runtime-executed: #f))

;;; Capability policy declares backend and sandbox capability expectations.
;;; Marlin owns probing and enforcement; Scheme only projects report receipts.
;; : AgenticAILabLoopEngineCapabilityPolicyPrototype
(def loop-engine-capability-policy
  (.o kind: +agentic-ai-lab-user-loop-engine-capability-policy-prototype-kind+
      backend: #f
      isolation: #f
      required: '()
      optional: '()
      unsupported-behavior: #f
      entries: '()
      runtime-executed: #f))

;;; Memory policy declares recall/commit intent as report-only loop facts.
;;; Marlin owns storage, ranking, retention, and all memory mutation.
;; : AgenticAILabLoopEngineMemoryPolicyPrototype
(def loop-engine-memory-policy
  (.o kind: +agentic-ai-lab-user-loop-engine-memory-policy-prototype-kind+
      use-case: #f
      store: #f
      state-path: #f
      scope: #f
      recall: '()
      commit: '()
      ranking: #f
      retention: #f
      entries: '()
      runtime-executed: #f))

;;; Compression policy declares summary/session compaction expectations as
;;; report-only facts. Marlin owns transcript compression and session creation.
;; : AgenticAILabLoopEngineCompressionPolicyPrototype
(def loop-engine-compression-policy
  (.o kind: +agentic-ai-lab-user-loop-engine-compression-policy-prototype-kind+
      strategy: #f
      trigger: #f
      summary-format: #f
      lineage-kind: #f
      retention: #f
      entries: '()
      runtime-executed: #f))

;;; The profile object is the single public root accepted by loop-engine
;;; `:config`; all other objects feed slots on this profile.
;; : AgenticAILabLoopEngineProfilePrototype
(def loop-engine-profile
  (object<-alist
   (list
    (cons 'kind +agentic-ai-lab-user-loop-engine-profile-prototype-kind+)
    (cons 'profile-name #f)
    (cons 'use-case #f)
    (cons 'use-cases '())
    (cons 'governor #f)
    (cons 'agent-judges #f)
    (cons 'human-audit #f)
    (cons 'schedule #f)
    (cons 'state #f)
    (cons 'sandbox #f)
    (cons 'budget #f)
    (cons 'result #f)
    (cons 'observability #f)
    (cons 'runtime #f)
    (cons 'lineage-policy #f)
    (cons 'selector-policy #f)
    (cons 'resource-policy #f)
    (cons 'capability-policy #f)
    (cons 'memory-policies '())
    (cons 'compression-policy #f)
    (cons 'session-selector-receipts '())
    (cons 'session-materialization-receipts '())
    (cons 'policy-extensions '())
    (cons 'spec-evolution-review-items '())
    (cons 'metadata '())
    (cons 'runtime-executed #f))))
