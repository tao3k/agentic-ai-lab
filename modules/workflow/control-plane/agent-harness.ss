;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: inert agent harness/session/run object families.
;;; Invariant: constructors and projections never execute runtime work.

(import :poo-flow/modules/workflow/control-plane/agent-harness-vocabulary
        :poo-flow/modules/workflow/control-plane/receipt
        :poo-flow/modules/workflow/control-plane/projection-syntax)

(export (import: :poo-flow/modules/workflow/control-plane/agent-harness-vocabulary)
        make-poo-flow-agent-profile
        poo-flow-agent-profile?
        poo-flow-agent-profile-name
        poo-flow-agent-profile-model-policy
        poo-flow-agent-profile-instructions
        poo-flow-agent-profile-tools
        poo-flow-agent-profile-skills
        poo-flow-agent-profile-sandbox-profile
        poo-flow-agent-profile-loop-policy
        poo-flow-agent-profile-compaction-policy
        poo-flow-agent-profile-budget-policy
        poo-flow-agent-profile-observability-policy
        poo-flow-agent-profile-metadata
        poo-flow-agent-profile->alist
        make-poo-flow-agent-harness
        poo-flow-agent-harness?
        poo-flow-agent-harness-id
        poo-flow-agent-harness-profile
        poo-flow-agent-harness-sandbox-profile
        poo-flow-agent-harness-runtime-adapter-intent
        poo-flow-agent-harness-capabilities
        poo-flow-agent-harness-session-namespace
        poo-flow-agent-harness-observability-sink
        poo-flow-agent-harness-runtime-executed?
        poo-flow-agent-harness-metadata
        poo-flow-agent-harness->alist
        make-poo-flow-agent-session
        poo-flow-agent-session?
        poo-flow-agent-session-name
        poo-flow-agent-session-harness-id
        poo-flow-agent-session-status
        poo-flow-agent-session-active-operation-id
        poo-flow-agent-session-conversation-state-ref
        poo-flow-agent-session-retention-policy
        poo-flow-agent-session-operation-history
        poo-flow-agent-session-metadata
        poo-flow-agent-session->alist
        make-poo-flow-agent-operation
        poo-flow-agent-operation?
        poo-flow-agent-operation-id
        poo-flow-agent-operation-kind
        poo-flow-agent-operation-parent-session
        poo-flow-agent-operation-parent-run
        poo-flow-agent-operation-request
        poo-flow-agent-operation-result-contract
        poo-flow-agent-operation-runtime-intent
        poo-flow-agent-operation-status
        poo-flow-agent-operation-receipt
        poo-flow-agent-operation-metadata
        poo-flow-agent-operation-delegated-task?
        poo-flow-agent-operation->alist
        make-poo-flow-workflow-run
        poo-flow-workflow-run?
        poo-flow-workflow-run-run-id
        poo-flow-workflow-run-workflow-ref
        poo-flow-workflow-run-payload-ref
        poo-flow-workflow-run-status
        poo-flow-workflow-run-harness-refs
        poo-flow-workflow-run-event-stream-ref
        poo-flow-workflow-run-logs
        poo-flow-workflow-run-result
        poo-flow-workflow-run-error
        poo-flow-workflow-run-terminal-receipt
        poo-flow-workflow-run-metadata
        poo-flow-workflow-run->alist
        make-poo-flow-dispatch-receipt
        poo-flow-dispatch-receipt?
        poo-flow-dispatch-receipt-dispatch-id
        poo-flow-dispatch-receipt-target-agent
        poo-flow-dispatch-receipt-target-instance-id
        poo-flow-dispatch-receipt-target-session-id
        poo-flow-dispatch-receipt-payload-ref
        poo-flow-dispatch-receipt-accepted-at
        poo-flow-dispatch-receipt-admission-status
        poo-flow-dispatch-receipt-runtime-queue-intent
        poo-flow-dispatch-receipt-metadata
        poo-flow-dispatch-receipt->alist
        make-poo-flow-runtime-snapshot
        poo-flow-runtime-snapshot?
        poo-flow-runtime-snapshot-subject-kind
        poo-flow-runtime-snapshot-subject-id
        poo-flow-runtime-snapshot-status
        poo-flow-runtime-snapshot-last-event-index
        poo-flow-runtime-snapshot-result-summary
        poo-flow-runtime-snapshot-error-summary
        poo-flow-runtime-snapshot-presentation-trace
        poo-flow-runtime-snapshot-metadata
        poo-flow-runtime-snapshot->alist
        poo-flow-receipt->workflow-run
        poo-flow-workflow-run->snapshot
        poo-flow-agent-session->snapshot
        poo-flow-dispatch-receipt->snapshot)

;;; Boundary: agent harness alist ref is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Alist Symbol Value Value)
(def (poo-flow-agent-harness-alist-ref entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;;; Profiles are reusable policy objects. The fields are deliberately shallow:
;;; concrete model, tool, skill, sandbox, and loop details are references that
;;; later layers validate and lower.
;; : PooFlowAgentProfile
(defstruct poo-flow-agent-profile
  (name
   model-policy
   instructions
   tools
   skills
   sandbox-profile
   loop-policy
   compaction-policy
   budget-policy
   observability-policy
   metadata)
  transparent: #t)

;; : PooFlowAgentHarness
(defstruct poo-flow-agent-harness
  (id
   profile
   sandbox-profile
   runtime-adapter-intent
   capabilities
   session-namespace
   observability-sink
   runtime-executed?
   metadata)
  transparent: #t)

;; : PooFlowAgentSession
(defstruct poo-flow-agent-session
  (name
   harness-id
   status
   active-operation-id
   conversation-state-ref
   retention-policy
   operation-history
   metadata)
  transparent: #t)

;; : PooFlowAgentOperation
(defstruct poo-flow-agent-operation
  (id
   kind
   parent-session
   parent-run
   request
   result-contract
   runtime-intent
   status
   receipt
   metadata)
  transparent: #t)

;; : PooFlowWorkflowRun
(defstruct poo-flow-workflow-run
  (run-id
   workflow-ref
   payload-ref
   status
   harness-refs
   event-stream-ref
   logs
   result
   error
   terminal-receipt
   metadata)
  transparent: #t)

;;; Dispatch admission is separate from workflow run completion. It records
;;; that input was accepted for a continuing agent/session.
;; : PooFlowDispatchReceipt
(defstruct poo-flow-dispatch-receipt
  (dispatch-id
   target-agent
   target-instance-id
   target-session-id
   payload-ref
   accepted-at
   admission-status
   runtime-queue-intent
   metadata)
  transparent: #t)

;; : PooFlowRuntimeSnapshot
(defstruct poo-flow-runtime-snapshot
  (subject-kind
   subject-id
   status
   last-event-index
   result-summary
   error-summary
   presentation-trace
   metadata)
  transparent: #t)

;; : (-> PooFlowAgentProfile Alist)
(defpoo-core-receipt-projection
  poo-flow-agent-profile->alist (profile)
  (bindings ())
  (fields ((kind 'agent-profile)
           (name (poo-flow-agent-profile-name profile))
           (model-policy (poo-flow-agent-profile-model-policy profile))
           (instructions (poo-flow-agent-profile-instructions profile))
           (tools (poo-flow-agent-profile-tools profile))
           (skills (poo-flow-agent-profile-skills profile))
           (sandbox-profile (poo-flow-agent-profile-sandbox-profile profile))
           (loop-policy (poo-flow-agent-profile-loop-policy profile))
           (compaction-policy
            (poo-flow-agent-profile-compaction-policy profile))
           (budget-policy (poo-flow-agent-profile-budget-policy profile))
           (observability-policy
            (poo-flow-agent-profile-observability-policy profile))
           (metadata (poo-flow-agent-profile-metadata profile))
           (runtime-executed #f))))

;; : (-> PooFlowAgentHarness Alist)
(defpoo-core-receipt-projection
  poo-flow-agent-harness->alist (harness)
  (bindings ())
  (fields ((kind 'agent-harness)
           (id (poo-flow-agent-harness-id harness))
           (profile (poo-flow-agent-harness-profile harness))
           (sandbox-profile (poo-flow-agent-harness-sandbox-profile harness))
           (runtime-adapter-intent
            (poo-flow-agent-harness-runtime-adapter-intent harness))
           (capabilities (poo-flow-agent-harness-capabilities harness))
           (session-namespace
            (poo-flow-agent-harness-session-namespace harness))
           (observability-sink
            (poo-flow-agent-harness-observability-sink harness))
           (runtime-executed
            (poo-flow-agent-harness-runtime-executed? harness))
           (metadata (poo-flow-agent-harness-metadata harness)))))

;; : (-> PooFlowAgentSession Alist)
(defpoo-core-receipt-projection
  poo-flow-agent-session->alist (session)
  (bindings ())
  (fields ((kind 'agent-session)
           (name (poo-flow-agent-session-name session))
           (harness-id (poo-flow-agent-session-harness-id session))
           (status (poo-flow-agent-session-status session))
           (active-operation-id
            (poo-flow-agent-session-active-operation-id session))
           (conversation-state-ref
            (poo-flow-agent-session-conversation-state-ref session))
           (retention-policy
            (poo-flow-agent-session-retention-policy session))
           (operation-history
            (poo-flow-agent-session-operation-history session))
           (metadata (poo-flow-agent-session-metadata session))
           (workflow-run? #f))))

;; : (-> PooFlowAgentOperation Boolean)
(def (poo-flow-agent-operation-delegated-task? operation)
  (eq? (poo-flow-agent-operation-kind operation) 'task))

;; : (-> PooFlowAgentOperation Alist)
(defpoo-core-receipt-projection
  poo-flow-agent-operation->alist (operation)
  (bindings ())
  (fields ((kind 'agent-operation)
           (operation-kind (poo-flow-agent-operation-kind operation))
           (id (poo-flow-agent-operation-id operation))
           (parent-session
            (poo-flow-agent-operation-parent-session operation))
           (parent-run (poo-flow-agent-operation-parent-run operation))
           (request (poo-flow-agent-operation-request operation))
           (result-contract
            (poo-flow-agent-operation-result-contract operation))
           (runtime-intent
            (poo-flow-agent-operation-runtime-intent operation))
           (status (poo-flow-agent-operation-status operation))
           (receipt (poo-flow-agent-operation-receipt operation))
           (delegated-task?
            (poo-flow-agent-operation-delegated-task? operation))
           (metadata (poo-flow-agent-operation-metadata operation)))))

;; : (-> PooFlowWorkflowRun Alist)
(defpoo-core-receipt-projection
  poo-flow-workflow-run->alist (run)
  (bindings ())
  (fields ((kind 'workflow-run)
           (run-id (poo-flow-workflow-run-run-id run))
           (workflow-ref (poo-flow-workflow-run-workflow-ref run))
           (payload-ref (poo-flow-workflow-run-payload-ref run))
           (status (poo-flow-workflow-run-status run))
           (harness-refs (poo-flow-workflow-run-harness-refs run))
           (event-stream-ref
            (poo-flow-workflow-run-event-stream-ref run))
           (logs (poo-flow-workflow-run-logs run))
           (result (poo-flow-workflow-run-result run))
           (error (poo-flow-workflow-run-error run))
           (terminal-receipt
            (poo-flow-workflow-run-terminal-receipt run))
           (metadata (poo-flow-workflow-run-metadata run)))))

;; : (-> PooFlowDispatchReceipt Alist)
(defpoo-core-receipt-projection
  poo-flow-dispatch-receipt->alist (receipt)
  (bindings ())
  (fields ((kind 'dispatch-receipt)
           (dispatch-id (poo-flow-dispatch-receipt-dispatch-id receipt))
           (target-agent (poo-flow-dispatch-receipt-target-agent receipt))
           (target-instance-id
            (poo-flow-dispatch-receipt-target-instance-id receipt))
           (target-session-id
            (poo-flow-dispatch-receipt-target-session-id receipt))
           (payload-ref (poo-flow-dispatch-receipt-payload-ref receipt))
           (accepted-at (poo-flow-dispatch-receipt-accepted-at receipt))
           (admission-status
            (poo-flow-dispatch-receipt-admission-status receipt))
           (runtime-queue-intent
            (poo-flow-dispatch-receipt-runtime-queue-intent receipt))
           (workflow-run-id #f)
           (metadata (poo-flow-dispatch-receipt-metadata receipt)))))

;; : (-> PooFlowRuntimeSnapshot Alist)
(defpoo-core-receipt-projection
  poo-flow-runtime-snapshot->alist (snapshot)
  (bindings ())
  (fields ((kind 'runtime-snapshot)
           (subject-kind
            (poo-flow-runtime-snapshot-subject-kind snapshot))
           (subject-id (poo-flow-runtime-snapshot-subject-id snapshot))
           (status (poo-flow-runtime-snapshot-status snapshot))
           (last-event-index
            (poo-flow-runtime-snapshot-last-event-index snapshot))
           (result-summary
            (poo-flow-runtime-snapshot-result-summary snapshot))
           (error-summary
            (poo-flow-runtime-snapshot-error-summary snapshot))
           (presentation-trace
            (poo-flow-runtime-snapshot-presentation-trace snapshot))
           (metadata (poo-flow-runtime-snapshot-metadata snapshot)))))

;;; Boundary: receipt workflow status is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Symbol Symbol)
(def (poo-flow-receipt-workflow-status status)
  (cond
   ((eq? status 'ok) 'completed)
   ((eq? status 'failed) 'errored)
   (else status)))

;;; Existing runner receipts can be projected into the new workflow-run object
;;; family without making the runner import this module. The caller supplies the
;;; run id because durable id ownership belongs to the admission/runtime layer.
;; : (-> Receipt Alist)
(defpoo-core-receipt-projection
  poo-flow-receipt-workflow-run-metadata (receipt)
  (bindings ())
  (fields ((source 'receipt)
           (strategy (receipt-strategy receipt))
           (policy (receipt-policy receipt))
           (frontier (receipt-frontier receipt))
           (event-count (receipt-event-count receipt))
           (adapter-request-count
            (receipt-adapter-request-count receipt)))))

;; : (-> Receipt RunId PooFlowWorkflowRun)
(def (poo-flow-receipt->workflow-run receipt run-id)
  (make-poo-flow-workflow-run
   run-id
   (receipt-flow receipt)
   (receipt-input receipt)
   (poo-flow-receipt-workflow-status (receipt-status receipt))
   '()
   (list 'receipt-events run-id)
   '()
   (receipt-output receipt)
   (receipt-error receipt)
   receipt
   (poo-flow-receipt-workflow-run-metadata receipt)))

;; : (-> PooFlowWorkflowRun PooFlowRuntimeSnapshot)
(defpoo-core-receipt-projection
  poo-flow-workflow-run-snapshot-details (run)
  (bindings ())
  (fields ((workflow-ref (poo-flow-workflow-run-workflow-ref run))
           (event-stream-ref
            (poo-flow-workflow-run-event-stream-ref run)))))

;; : (-> PooFlowWorkflowRun PooFlowRuntimeSnapshot)
(def (poo-flow-workflow-run->snapshot run)
  (make-poo-flow-runtime-snapshot
   'workflow-run
   (poo-flow-workflow-run-run-id run)
   (poo-flow-workflow-run-status run)
   (poo-flow-agent-harness-alist-ref
    (poo-flow-workflow-run-metadata run)
    'last-event-index
    #f)
   (poo-flow-workflow-run-result run)
   (poo-flow-workflow-run-error run)
   '((stage . workflow-run->snapshot)
     (runtime-executed . #f))
   (poo-flow-workflow-run-snapshot-details run)))

;; : (-> PooFlowAgentSession PooFlowRuntimeSnapshot)
(defpoo-core-receipt-projection
  poo-flow-agent-session-snapshot-details (session)
  (bindings ())
  (fields ((harness-id (poo-flow-agent-session-harness-id session))
           (active-operation-id
            (poo-flow-agent-session-active-operation-id session)))))

;; : (-> PooFlowAgentSession PooFlowRuntimeSnapshot)
(def (poo-flow-agent-session->snapshot session)
  (make-poo-flow-runtime-snapshot
   'agent-session
   (poo-flow-agent-session-name session)
   (poo-flow-agent-session-status session)
   (length (poo-flow-agent-session-operation-history session))
   #f
   #f
   '((stage . agent-session->snapshot)
     (runtime-executed . #f))
   (poo-flow-agent-session-snapshot-details session)))

;; : (-> PooFlowDispatchReceipt PooFlowRuntimeSnapshot)
(defpoo-core-receipt-projection
  poo-flow-dispatch-receipt-snapshot-details (receipt)
  (bindings ())
  (fields ((target-agent
            (poo-flow-dispatch-receipt-target-agent receipt))
           (target-session-id
            (poo-flow-dispatch-receipt-target-session-id receipt)))))

;; : (-> PooFlowDispatchReceipt PooFlowRuntimeSnapshot)
(def (poo-flow-dispatch-receipt->snapshot receipt)
  (make-poo-flow-runtime-snapshot
   'dispatch-receipt
   (poo-flow-dispatch-receipt-dispatch-id receipt)
   (poo-flow-dispatch-receipt-admission-status receipt)
   #f
   #f
   #f
   '((stage . dispatch-receipt->snapshot)
     (runtime-executed . #f))
   (poo-flow-dispatch-receipt-snapshot-details receipt)))
