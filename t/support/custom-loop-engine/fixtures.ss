;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Shared fixtures for custom loop-engine user-interface tests.

(import (only-in :clan/poo/object .ref .slot? object?)
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        (only-in :agentic-ai-lab/modules/loop-engine/runtime
                 loop-engine-capability-receipt?
                 agentic-ai-lab-user-loop-engine-capability-receipt-ref)
        (only-in :agentic-ai-lab/modules/cubeSandbox/config
                 agentic-ai-lab-cubeSandbox-module-bundles)
        (only-in :agentic-ai-lab/modules/nono-sandbox/config
                 agentic-ai-lab-nono-sandbox-module-bundles)
        (only-in "../../../user-interface/custom/my-module/cases/loop-engine-owner"
                 agentic-ai-lab-custom-my-module-loop-engine-case))

(export test-ref
        test-field-values
        expected-loop-engine-agent-names
        expected-loop-engine-session-ids
        expected-loop-engine-lineage-edge-pairs
        expected-loop-engine-durable-policy-refs
        expected-loop-engine-channel-refs
        expected-loop-engine-receipt-contracts
        expected-loop-engine-human-audit-result-contract
        expected-loop-engine-required-result-fields
        expected-loop-engine-spec-evolution-proposal-id
        expected-loop-engine-spec-evolution-target-ref
        custom-loop-presentation/bundles
        custom-loop-presentation
        custom-loop-concrete-context)

;;; Intent rows are public presentation values. Generated capability receipts
;;; are fixed structs; runtime ABI payloads serialize to alists.
;; | LoopEngineIntentRow = (Or POOObject Alist)
;; | LoopEngineIntentKey = Symbol
;; : (-> LoopEngineIntentRow LoopEngineIntentKey MaybeValue)
(def (test-ref value key)
  (cond
   ((loop-engine-capability-receipt? value)
    (agentic-ai-lab-user-loop-engine-capability-receipt-ref value key #f))
   ((and (object? value) (.slot? value key)) (.ref value key))
   ((pair? value)
    (let (entry (assoc key value))
      (if entry (cdr entry) #f)))
   (else #f)))

;;; Name extraction keeps repeated profile/harness assertions about the object
;;; graph shape instead of duplicating alist traversal at each check site.
;; : (-> [Alist] Symbol [Value])
(def (test-field-values rows key)
  (map (lambda (row) (test-ref row key)) rows))

;; : [Symbol]
(def expected-loop-engine-agent-names
  '(ci-audit-agent
    build-verifier-agent
    ci-loop-governor
    human-audit))

;; : [Symbol]
(def expected-loop-engine-session-ids
  '(incoming-ci-request-session
    loop-engine/current-system-build-loop/session
    loop-engine/current-system-build-loop/auditor-session
    loop-engine/current-system-build-loop/verifier-session
    loop-engine/current-system-build-loop/governor-session
    loop-engine/current-system-build-loop/human-audit-session))

;; : [Pair]
(def expected-loop-engine-lineage-edge-pairs
  '((loop-engine/current-system-build-loop/session
     . loop-engine/current-system-build-loop/auditor-session)
    (loop-engine/current-system-build-loop/session
     . loop-engine/current-system-build-loop/verifier-session)
    (loop-engine/current-system-build-loop/session
     . loop-engine/current-system-build-loop/governor-session)
    (loop-engine/current-system-build-loop/session
     . loop-engine/current-system-build-loop/human-audit-session)))

;; : [Symbol]
(def expected-loop-engine-durable-policy-refs
  '(ci-audit-agent/durable-policy
    build-verifier-agent/durable-policy
    ci-loop-governor/durable-policy
    human-audit/durable-policy))

;; : [Symbol]
(def expected-loop-engine-channel-refs
  '(loop-engine/current-system-build-loop/auditor-channel
    loop-engine/current-system-build-loop/verifier-channel
    loop-engine/current-system-build-loop/governor-channel
    loop-engine/current-system-build-loop/human-audit-channel))

;; : Alist
(def expected-loop-engine-receipt-contracts
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

;; : Symbol
(def expected-loop-engine-human-audit-result-contract
  'agentic-ai-lab.loop-governor.human-audit-decision.v1)

;; : [Symbol]
(def expected-loop-engine-required-result-fields
  '(decision summary evidence))

;; : Symbol
(def expected-loop-engine-spec-evolution-proposal-id
  'sandbox-profile-human-audit-before-ci-change)

;; : Symbol
(def expected-loop-engine-spec-evolution-target-ref
  'ci/build)

;;; Custom loop fixtures are tested through the same config presentation used
;;; by downstream user declarations. This helper avoids constructing a module
;;; descriptor or executing loop runtime code in the test.
;; : (-> [PooUserModuleSelection] POOObject)
(def (custom-loop-presentation/bundles module-bundles)
  (agenticAiLabUserConfigPresentation
   (yuanxuUserConfig
    (yuanxu-user-module-bundles->modules module-bundles)
    (yuanxu-settings))))

;; : (-> [PooUserModuleSelection] POOObject)
(def (custom-loop-presentation module-bundle)
  (custom-loop-presentation/bundles
   (append agentic-ai-lab-nono-sandbox-module-bundles
           agentic-ai-lab-cubeSandbox-module-bundles
           (list module-bundle))))

;;; The concrete context centralizes projection setup so each assertion helper
;;; stays under one boundary: declaration shape, agent graph, operation rows,
;;; or presentation aggregation.
;; : (-> Alist)
(def (custom-loop-concrete-context)
  (let* ((presentation
          (custom-loop-presentation
           agentic-ai-lab-custom-my-module-loop-engine-case))
         (intent
          (car (.ref presentation 'loop-engine-intents))))
    (list (cons 'presentation presentation)
          (cons 'intent intent)
          (cons 'runtime-snapshot
                (test-ref intent 'runtime-snapshot)))))
