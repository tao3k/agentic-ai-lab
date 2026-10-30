;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: proof-backed AI agent lifecycle gate objects.
;;; Invariant: gates are POO-native; alists appear only as Lean facts.

(import (only-in :clan/poo/object .o .ref object?))

(export agentic-ai-lab-agent-lifecycle-gate-kind
        agentic-ai-lab-agent-lifecycle-receipt-kind
        agentic-ai-lab-agent-lifecycle-gate-fact-keys
        agentic-ai-lab-agent-lifecycle-receipt
        agenticAiLabAgentLifecycleReceipt
        agentic-ai-lab-agent-lifecycle-gate
        agenticAiLabAgentLifecycleGate
        agentic-ai-lab-agent-lifecycle-receipt?
        agentic-ai-lab-agent-lifecycle-gate?
        agentic-ai-lab-agent-lifecycle-gate-name
        agentic-ai-lab-agent-lifecycle-gate-accepted?
        agentic-ai-lab-agent-lifecycle-gate->lean-facts
        agentic-ai-lab-agent-lifecycle-lean-fact-contract-complete?)

;; : (-> Unit AgenticAILabAgentLifecycleGateKind)
(def agentic-ai-lab-agent-lifecycle-gate-kind
  "agentic-ai-lab.modules.agent-lifecycle.gate.v1")

;; : (-> Unit AgenticAILabAgentLifecycleReceiptKind)
(def agentic-ai-lab-agent-lifecycle-receipt-kind
  "agentic-ai-lab.modules.agent-lifecycle.receipt.v1")

;; : (-> Unit AgenticAILabAgentLifecycleLeanFactKeySet)
(def agentic-ai-lab-agent-lifecycle-gate-fact-keys
  '(ai.lifecycle/public-policy
    ai.session/created
    ai.session/parent-bound
    ai.sandbox/attached
    ai.sandbox/scope-contained
    ai.tool/permissions-contained
    ai.loop/start-guarded
    ai.loop/exit-defined
    ai.loop/handoff-guarded
    ai.subagent/parented
    ai.topology/scope-order-sound
    ai.topology/tool-scope-sound
    ai.topology/loop-transition-sound
    ai.topology/subagent-session-sound
    ai.dependency/closed
    ai.receipt/tested
    ai.receipt/has-proof
    ai.receipt/observability-clean
    ai.counterexample/rejected
    ai.lifecycle/reusable-policy-surface
    ai.lifecycle/experimental))

(defstruct agentic-ai-lab-agent-lifecycle-receipt-record
  (kind
   lifecycle-receipt-session-id
   lifecycle-receipt-sandbox-profile-ref
   lifecycle-receipt-loop-policy-ref
   lifecycle-receipt-subagent-refs
   lifecycle-receipt-tool-capability-refs
   lifecycle-receipt-test-receipts
   lifecycle-receipt-proof-receipts
   lifecycle-receipt-session-created
   lifecycle-receipt-parent-session-bound
   lifecycle-receipt-sandbox-attached
   lifecycle-receipt-sandbox-scope-contained
   lifecycle-receipt-tool-permissions-contained
   lifecycle-receipt-loop-start-guarded
   lifecycle-receipt-loop-exit-defined
   lifecycle-receipt-loop-handoff-guarded
   lifecycle-receipt-subagents-parented
   lifecycle-receipt-dependency-closed
   lifecycle-receipt-observability-clean
   lifecycle-receipt-counterexample-rejected)
  transparent: #t)

;;; Receipt predicates stay local to this owner so lifecycle gate validation can
;;; distinguish a missing receipt from a receipt that explicitly rejects safety.
;; : (-> AgenticAILabAgentLifecycleReceiptCandidate Boolean)
(def (agentic-ai-lab-agent-lifecycle-receipt? value)
  (or (agentic-ai-lab-agent-lifecycle-receipt-record? value)
      (and (object? value)
           (equal? (.ref value 'kind)
                   agentic-ai-lab-agent-lifecycle-receipt-kind))))

;; : (-> AgenticAILabAgentLifecycleReceipt Symbol AgenticAILabAgentLifecycleReceiptSlotValue)
(def (agentic-ai-lab-agent-lifecycle-receipt-slot receipt key)
  (if (agentic-ai-lab-agent-lifecycle-receipt-record? receipt)
    (case key
      ((kind)
       (agentic-ai-lab-agent-lifecycle-receipt-record-kind receipt))
      ((lifecycle-receipt-session-id)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-session-id receipt))
      ((lifecycle-receipt-sandbox-profile-ref)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-sandbox-profile-ref receipt))
      ((lifecycle-receipt-loop-policy-ref)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-loop-policy-ref receipt))
      ((lifecycle-receipt-subagent-refs)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-subagent-refs receipt))
      ((lifecycle-receipt-tool-capability-refs)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-tool-capability-refs receipt))
      ((lifecycle-receipt-test-receipts)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-test-receipts receipt))
      ((lifecycle-receipt-proof-receipts)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-proof-receipts receipt))
      ((lifecycle-receipt-session-created)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-session-created receipt))
      ((lifecycle-receipt-parent-session-bound)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-parent-session-bound receipt))
      ((lifecycle-receipt-sandbox-attached)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-sandbox-attached receipt))
      ((lifecycle-receipt-sandbox-scope-contained)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-sandbox-scope-contained receipt))
      ((lifecycle-receipt-tool-permissions-contained)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-tool-permissions-contained receipt))
      ((lifecycle-receipt-loop-start-guarded)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-loop-start-guarded receipt))
      ((lifecycle-receipt-loop-exit-defined)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-loop-exit-defined receipt))
      ((lifecycle-receipt-loop-handoff-guarded)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-loop-handoff-guarded receipt))
      ((lifecycle-receipt-subagents-parented)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-subagents-parented receipt))
      ((lifecycle-receipt-dependency-closed)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-dependency-closed receipt))
      ((lifecycle-receipt-observability-clean)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-observability-clean receipt))
      ((lifecycle-receipt-counterexample-rejected)
       (agentic-ai-lab-agent-lifecycle-receipt-record-lifecycle-receipt-counterexample-rejected receipt))
      (else #f))
    (.ref receipt key)))

;;; Optional receipt access is intentionally private. Missing receipt facts
;;; project to false values instead of becoming partial public accessors.
;; : (-> AgenticAILabAgentLifecycleReceiptCandidate Symbol AgenticAILabAgentLifecycleReceiptSlotValue AgenticAILabAgentLifecycleReceiptSlotValue)
(def (agentic-ai-lab-agent-lifecycle-receipt-slot/default receipt key default-value)
  (if (agentic-ai-lab-agent-lifecycle-receipt? receipt)
    (agentic-ai-lab-agent-lifecycle-receipt-slot receipt key)
    default-value))

;; : (-> AgenticAILabAgentLifecycleReceiptSlotValue Boolean)
(def (agentic-ai-lab-agent-lifecycle-non-empty-list? value)
  (and (list? value) (not (null? value))))

;; agentic-ai-lab-agent-lifecycle-receipt
;;   : (-> Symbol Symbol Symbol [Symbol] [Symbol] [Symbol] [Symbol] Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean POOObject)
;;   | contract: POO receipt for session/sandbox/loop/subagent policy gates
;; : (-> Symbol Symbol Symbol [Symbol] [Symbol] [Symbol] [Symbol] Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean POOObject)
(def (agentic-ai-lab-agent-lifecycle-receipt session-id
                                       sandbox-profile-ref
                                       loop-policy-ref
                                       subagent-refs
                                       tool-capability-refs
                                       test-receipts
                                       proof-receipts
                                       session-created?
                                       parent-session-bound?
                                       sandbox-attached?
                                       sandbox-scope-contained?
                                       tool-permissions-contained?
                                       loop-start-guarded?
                                       loop-exit-defined?
                                       loop-handoff-guarded?
                                       subagents-parented?
                                       dependency-closed?
                                       observability-clean?
                                       counterexample-rejected?)
  (make-agentic-ai-lab-agent-lifecycle-receipt-record
   agentic-ai-lab-agent-lifecycle-receipt-kind
   session-id
   sandbox-profile-ref
   loop-policy-ref
   subagent-refs
   tool-capability-refs
   test-receipts
   proof-receipts
   session-created?
   parent-session-bound?
   sandbox-attached?
   sandbox-scope-contained?
   tool-permissions-contained?
   loop-start-guarded?
   loop-exit-defined?
   loop-handoff-guarded?
   subagents-parented?
   dependency-closed?
   observability-clean?
   counterexample-rejected?))

;; : (-> Symbol Symbol Symbol [Symbol] [Symbol] [Symbol] [Symbol] Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean POOObject)
(def (agenticAiLabAgentLifecycleReceipt session-id
                                   sandbox-profile-ref
                                   loop-policy-ref
                                   subagent-refs
                                   tool-capability-refs
                                   test-receipts
                                   proof-receipts
                                   session-created?
                                   parent-session-bound?
                                   sandbox-attached?
                                   sandbox-scope-contained?
                                   tool-permissions-contained?
                                   loop-start-guarded?
                                   loop-exit-defined?
                                   loop-handoff-guarded?
                                   subagents-parented?
                                   dependency-closed?
                                   observability-clean?
                                   counterexample-rejected?)
  (agentic-ai-lab-agent-lifecycle-receipt
   session-id
   sandbox-profile-ref
   loop-policy-ref
   subagent-refs
   tool-capability-refs
   test-receipts
   proof-receipts
   session-created?
   parent-session-bound?
   sandbox-attached?
   sandbox-scope-contained?
   tool-permissions-contained?
   loop-start-guarded?
   loop-exit-defined?
   loop-handoff-guarded?
   subagents-parented?
   dependency-closed?
   observability-clean?
   counterexample-rejected?))

;; agentic-ai-lab-agent-lifecycle-gate
;;   : (-> Symbol Symbol POOObject Alist POOObject)
;;   | contract: constructs a POO-native lifecycle proof gate
;; : (-> Symbol Symbol POOObject Alist POOObject)
(def (agentic-ai-lab-agent-lifecycle-gate name status receipt metadata)
  (.o kind: agentic-ai-lab-agent-lifecycle-gate-kind
      lifecycle-gate-name: name
      lifecycle-gate-status: status
      lifecycle-gate-receipt: receipt
      lifecycle-gate-metadata: metadata))

;; : (-> Symbol Symbol POOObject Alist POOObject)
(def (agenticAiLabAgentLifecycleGate name status receipt metadata)
  (agentic-ai-lab-agent-lifecycle-gate name status receipt metadata))

;; : (-> AgenticAILabAgentLifecycleGateCandidate Boolean)
(def (agentic-ai-lab-agent-lifecycle-gate? value)
  (and (object? value)
       (equal? (.ref value 'kind)
               agentic-ai-lab-agent-lifecycle-gate-kind)))

;; : (-> AgenticAILabAgentLifecycleGate Symbol AgenticAILabAgentLifecycleGateSlotValue)
(def (agentic-ai-lab-agent-lifecycle-gate-slot gate key)
  (.ref gate key))

;; : (-> AgenticAILabAgentLifecycleGate Symbol)
(def (agentic-ai-lab-agent-lifecycle-gate-name gate)
  (agentic-ai-lab-agent-lifecycle-gate-slot gate 'lifecycle-gate-name))

;; : (-> AgenticAILabAgentLifecycleGate AgenticAILabAgentLifecycleReceiptCandidate)
(def (agentic-ai-lab-agent-lifecycle-gate-receipt gate)
  (agentic-ai-lab-agent-lifecycle-gate-slot gate 'lifecycle-gate-receipt))

;;; Acceptance is the prevention boundary for agent-authored lifecycle policy.
;;; A proof receipt alone is insufficient: the public surface also requires
;;; session lineage, sandbox scope, tool permissions, loop guards, subagent
;;; parentage, dependency closure, observability, and rejected bad cases.
;; : (-> AgenticAILabAgentLifecycleGate Boolean)
(def (agentic-ai-lab-agent-lifecycle-gate-accepted? gate)
  (let* ((status
          (agentic-ai-lab-agent-lifecycle-gate-slot gate 'lifecycle-gate-status))
         (receipt (agentic-ai-lab-agent-lifecycle-gate-receipt gate))
         (test-receipts
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-test-receipts
           '()))
         (proof-receipts
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-proof-receipts
           '())))
    (and (eq? status 'public)
         (agentic-ai-lab-agent-lifecycle-receipt? receipt)
         (agentic-ai-lab-agent-lifecycle-non-empty-list? test-receipts)
         (agentic-ai-lab-agent-lifecycle-non-empty-list? proof-receipts)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-session-created)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-parent-session-bound)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-sandbox-attached)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-sandbox-scope-contained)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-tool-permissions-contained)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-loop-start-guarded)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-loop-exit-defined)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-loop-handoff-guarded)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-subagents-parented)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-dependency-closed)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
          receipt
          'lifecycle-receipt-observability-clean)
         (agentic-ai-lab-agent-lifecycle-receipt-slot
         receipt
         'lifecycle-receipt-counterexample-rejected))))

;;; Lean fact projection is the only alist boundary. Callers author and extend
;;; POO gates; the proof layer receives stable fact rows that mirror the gate.
;; : (-> AgenticAILabAgentLifecycleGate Alist)
(def (agentic-ai-lab-agent-lifecycle-gate->lean-facts gate)
  (let* ((status
          (agentic-ai-lab-agent-lifecycle-gate-slot gate 'lifecycle-gate-status))
         (receipt (agentic-ai-lab-agent-lifecycle-gate-receipt gate))
         (test-receipts
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-test-receipts
           '()))
         (proof-receipts
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-proof-receipts
           '()))
         (public? (eq? status 'public))
         (tested?
          (agentic-ai-lab-agent-lifecycle-non-empty-list? test-receipts))
         (proof-backed?
          (agentic-ai-lab-agent-lifecycle-non-empty-list? proof-receipts))
         (session-created?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-session-created
           #f))
         (parent-session-bound?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-parent-session-bound
           #f))
         (sandbox-attached?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-sandbox-attached
           #f))
         (sandbox-scope-contained?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-sandbox-scope-contained
           #f))
         (tool-permissions-contained?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-tool-permissions-contained
           #f))
         (loop-start-guarded?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-loop-start-guarded
           #f))
         (loop-exit-defined?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-loop-exit-defined
           #f))
         (loop-handoff-guarded?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-loop-handoff-guarded
           #f))
         (subagents-parented?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-subagents-parented
           #f))
         (dependency-closed?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-dependency-closed
           #f))
         (observability-clean?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-observability-clean
           #f))
         (counterexample-rejected?
          (agentic-ai-lab-agent-lifecycle-receipt-slot/default
           receipt
           'lifecycle-receipt-counterexample-rejected
           #f)))
    (list
     (cons 'ai.lifecycle/public-policy public?)
     (cons 'ai.session/created session-created?)
     (cons 'ai.session/parent-bound parent-session-bound?)
     (cons 'ai.sandbox/attached sandbox-attached?)
     (cons 'ai.sandbox/scope-contained sandbox-scope-contained?)
     (cons 'ai.tool/permissions-contained tool-permissions-contained?)
     (cons 'ai.loop/start-guarded loop-start-guarded?)
     (cons 'ai.loop/exit-defined loop-exit-defined?)
     (cons 'ai.loop/handoff-guarded loop-handoff-guarded?)
     (cons 'ai.subagent/parented subagents-parented?)
     (cons 'ai.topology/scope-order-sound sandbox-scope-contained?)
     (cons 'ai.topology/tool-scope-sound
           (and sandbox-scope-contained?
                tool-permissions-contained?))
     (cons 'ai.topology/loop-transition-sound
           (and loop-start-guarded?
                loop-exit-defined?
                loop-handoff-guarded?))
     (cons 'ai.topology/subagent-session-sound
           (and parent-session-bound?
                subagents-parented?))
     (cons 'ai.dependency/closed dependency-closed?)
     (cons 'ai.receipt/tested tested?)
     (cons 'ai.receipt/has-proof proof-backed?)
     (cons 'ai.receipt/observability-clean observability-clean?)
     (cons 'ai.counterexample/rejected counterexample-rejected?)
     (cons 'ai.lifecycle/reusable-policy-surface
           (and public?
                tested?
                proof-backed?
                session-created?
                parent-session-bound?
                sandbox-attached?
                sandbox-scope-contained?
                tool-permissions-contained?
                loop-start-guarded?
                loop-exit-defined?
                loop-handoff-guarded?
                subagents-parented?
                dependency-closed?
                observability-clean?
                counterexample-rejected?))
     (cons 'ai.lifecycle/experimental
           (eq? status 'experimental)))))

;; : (forall (k v) (-> [(Pair k v)] Boolean))
;; : (-> Alist Boolean)
(def (agentic-ai-lab-agent-lifecycle-lean-fact-contract-complete? facts)
  (and (andmap (lambda (key)
                 (and (assq key facts) #t))
               agentic-ai-lab-agent-lifecycle-gate-fact-keys)
       (andmap (lambda (fact)
                 (and (pair? fact)
                      (memq (car fact)
                            agentic-ai-lab-agent-lifecycle-gate-fact-keys)
                      #t))
               facts)))
