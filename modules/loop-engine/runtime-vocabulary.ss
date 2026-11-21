;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine runtime handoff vocabulary and schema ids.
;;; Invariant: constants are data contracts only, not executable callbacks.

(export +agentic-ai-lab-user-loop-engine-handoff-contracts+
        +agentic-ai-lab-user-loop-engine-runtime-command-contract+
        +agentic-ai-lab-user-loop-engine-result-contract+
        +agentic-ai-lab-user-loop-engine-default-result-contract+
        +agentic-ai-lab-user-loop-engine-result-contract-roles+
        +agentic-ai-lab-user-loop-engine-receipt-contracts+
        +agentic-ai-lab-user-loop-engine-runtime-capability-descriptor-contract+
        +agentic-ai-lab-user-loop-engine-policy-profile-packet-contract+
        +agentic-ai-lab-user-loop-engine-runtime-action-packet-contract+
        +agentic-ai-lab-user-loop-engine-runtime-receipt-batch-contract+
        +agentic-ai-lab-user-loop-engine-runtime-packet-contracts+
        +agentic-ai-lab-user-loop-engine-runtime-command-name+
        +agentic-ai-lab-user-loop-engine-runtime-command-executable+
        +agentic-ai-lab-user-loop-engine-runtime-command-arguments+
        +agentic-ai-lab-user-loop-engine-runtime-object-families+)

;;; Runtime handoff contracts are names, not function pointers. Scheme exposes
;;; the command shape that Rust or another runtime can implement later.
;; : [Symbol]
(def +agentic-ai-lab-user-loop-engine-handoff-contracts+
  '(start-workflow-run
    admit-dispatch
    open-agent-session
    execute-agent-operation
    stream-events
    read-runtime-snapshot))

;;; The runtime command contract is a schema identifier shared with Marlin. It
;;; must stay data-only so Scheme never claims runtime implementation ownership.
;; : Symbol
(def +agentic-ai-lab-user-loop-engine-runtime-command-contract+
  'agentic-ai-lab.loop-governor.runtime-command-manifest.v1)

;;; Result contracts are schema identifiers for reviewer output. They stay
;;; separate from the runtime-command manifest so agents can audit structured
;;; result expectations before Marlin executes an operation.
;; : Symbol
(def +agentic-ai-lab-user-loop-engine-result-contract+
  'agentic-ai-lab.loop-governor.result-contract.v1)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-default-result-contract+
  'agentic-ai-lab.loop-governor.node-result.v1)

;; : [Symbol]
(def +agentic-ai-lab-user-loop-engine-result-contract-roles+
  '(default auditor verifier reviewer governor human-audit))

;;; Receipt contracts are stable data schemas that Marlin can consume without
;;; guessing which report-only rows accompany a loop-engine handoff.
;; : Alist
(def +agentic-ai-lab-user-loop-engine-receipt-contracts+
  '((lineage-receipt
     . agentic-ai-lab.loop-engine.lineage-receipt.v1)
    (selector-receipt
     . agentic-ai-lab.loop-engine.selector-receipt.v1)
    (session-agent-graph
     . agentic-ai-lab.modules.session.agent-graph.v1)
    (resource-dispatch-receipt
     . agentic-ai-lab.loop-engine.resource-dispatch-receipt.v1)
    (capability-receipt
     . agentic-ai-lab.loop-engine.capability-receipt.v1)
    (memory-receipt
     . agentic-ai-lab.loop-engine.memory-receipt.v1)
    (compression-receipt
     . agentic-ai-lab.loop-engine.compression-receipt.v1)
    (policy-extension-receipt
     . agentic-ai-lab.loop-engine.policy-extension-receipt.v1)
    (spec-evolution-review
     . agentic-ai-lab.spec-evolution.review-item.v1)
    (spec-evolution-runtime-manifest-row
     . agentic-ai-lab.spec-evolution.runtime-manifest-row.v1)
    (runtime-capability-descriptor
     . agentic-ai-lab.runtime.capability-descriptor.v1)
    (policy-profile-packet
     . agentic-ai-lab.runtime.policy-profile-packet.v1)
    (runtime-action-packet
     . agentic-ai-lab.runtime.action-packet.v1)
    (runtime-receipt-batch
     . agentic-ai-lab.runtime.receipt-batch.v1)
    (sandbox-handoff-agreement
     . agentic-ai-lab.loop-engine.sandbox-handoff-agreement.v1)))

;;; Pressure-relief packet contracts are the Marlin-facing ABI reduction layer:
;;; they describe normalized policy facts, not user-authored POO objects.
;; : Symbol
(def +agentic-ai-lab-user-loop-engine-runtime-capability-descriptor-contract+
  'agentic-ai-lab.runtime.capability-descriptor.v1)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-policy-profile-packet-contract+
  'agentic-ai-lab.runtime.policy-profile-packet.v1)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-runtime-action-packet-contract+
  'agentic-ai-lab.runtime.action-packet.v1)

;; : Symbol
(def +agentic-ai-lab-user-loop-engine-runtime-receipt-batch-contract+
  'agentic-ai-lab.runtime.receipt-batch.v1)

;; : Alist
(def +agentic-ai-lab-user-loop-engine-runtime-packet-contracts+
  `((runtime-capability-descriptor
     . ,+agentic-ai-lab-user-loop-engine-runtime-capability-descriptor-contract+)
    (policy-profile-packet
     . ,+agentic-ai-lab-user-loop-engine-policy-profile-packet-contract+)
    (runtime-action-packet
     . ,+agentic-ai-lab-user-loop-engine-runtime-action-packet-contract+)
    (runtime-receipt-batch
     . ,+agentic-ai-lab-user-loop-engine-runtime-receipt-batch-contract+)))

;;; The command name is stable receipt vocabulary for handoff manifests, not an
;;; executable selector or shell command.
;; : Symbol
(def +agentic-ai-lab-user-loop-engine-runtime-command-name+
  'loop-engine-runtime-handoff)

;; : String
(def +agentic-ai-lab-user-loop-engine-runtime-command-executable+
  "marlin-agent-core")

;; : [String]
(def +agentic-ai-lab-user-loop-engine-runtime-command-arguments+
  '("agentic-ai-lab" "runtime" "loop-engine-handoff"))

;;; Object family names document which control-plane projections the runtime
;;; must understand when it consumes a loop-engine handoff.
;; : [Symbol]
(def +agentic-ai-lab-user-loop-engine-runtime-object-families+
  '(agent-profile
    agent-harness
    agent-session
    session-agent-graph
    workflow-run
    dispatch-receipt
    agent-operation
    lineage-receipt
    selector-receipt
    resource-dispatch-receipt
    capability-receipt
    memory-receipt
    compression-receipt
    policy-extension-receipt
    spec-evolution-review-item
    spec-evolution-runtime-manifest-row
    runtime-capability-descriptor
    policy-profile-packet
    runtime-action-packet
    runtime-receipt-batch
    runtime-snapshot))
