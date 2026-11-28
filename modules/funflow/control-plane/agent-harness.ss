;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: inert agent harness/session/run object families.
;;; Invariant: constructors and projections never execute runtime work.

(import :tao3k/agentic-ai-lab/modules/funflow/control-plane/agent-harness-vocabulary
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/receipt
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/projection-syntax)

(export (import: :tao3k/agentic-ai-lab/modules/funflow/control-plane/agent-harness-vocabulary)
        make-yuanxu-agent-profile
        yuanxu-agent-profile?
        yuanxu-agent-profile-name
        yuanxu-agent-profile-model-policy
        yuanxu-agent-profile-instructions
        yuanxu-agent-profile-tools
        yuanxu-agent-profile-skills
        yuanxu-agent-profile-sandbox-profile
        yuanxu-agent-profile-loop-policy
        yuanxu-agent-profile-compaction-policy
        yuanxu-agent-profile-budget-policy
        yuanxu-agent-profile-observability-policy
        yuanxu-agent-profile-metadata
        yuanxu-agent-profile->alist
        make-yuanxu-agent-harness
        yuanxu-agent-harness?
        yuanxu-agent-harness-id
        yuanxu-agent-harness-profile
        yuanxu-agent-harness-sandbox-profile
        yuanxu-agent-harness-runtime-adapter-intent
        yuanxu-agent-harness-capabilities
        yuanxu-agent-harness-session-namespace
        yuanxu-agent-harness-observability-sink
        yuanxu-agent-harness-runtime-executed?
        yuanxu-agent-harness-metadata
        yuanxu-agent-harness->alist
        make-yuanxu-agent-session
        yuanxu-agent-session?
        yuanxu-agent-session-name
        yuanxu-agent-session-harness-id
        yuanxu-agent-session-status
        yuanxu-agent-session-active-operation-id
        yuanxu-agent-session-conversation-state-ref
        yuanxu-agent-session-retention-policy
        yuanxu-agent-session-operation-history
        yuanxu-agent-session-metadata
        yuanxu-agent-session->alist
        make-yuanxu-agent-operation
        yuanxu-agent-operation?
        yuanxu-agent-operation-id
        yuanxu-agent-operation-kind
        yuanxu-agent-operation-parent-session
        yuanxu-agent-operation-parent-run
        yuanxu-agent-operation-request
        yuanxu-agent-operation-result-contract
        yuanxu-agent-operation-runtime-intent
        yuanxu-agent-operation-status
        yuanxu-agent-operation-receipt
        yuanxu-agent-operation-metadata
        yuanxu-agent-operation-delegated-task?
        yuanxu-agent-operation->alist
        make-yuanxu-workflow-run
        yuanxu-workflow-run?
        yuanxu-workflow-run-run-id
        yuanxu-workflow-run-workflow-ref
        yuanxu-workflow-run-payload-ref
        yuanxu-workflow-run-status
        yuanxu-workflow-run-harness-refs
        yuanxu-workflow-run-event-stream-ref
        yuanxu-workflow-run-logs
        yuanxu-workflow-run-result
        yuanxu-workflow-run-error
        yuanxu-workflow-run-terminal-receipt
        yuanxu-workflow-run-metadata
        yuanxu-workflow-run->alist
        make-yuanxu-dispatch-receipt
        yuanxu-dispatch-receipt?
        yuanxu-dispatch-receipt-dispatch-id
        yuanxu-dispatch-receipt-target-agent
        yuanxu-dispatch-receipt-target-instance-id
        yuanxu-dispatch-receipt-target-session-id
        yuanxu-dispatch-receipt-payload-ref
        yuanxu-dispatch-receipt-accepted-at
        yuanxu-dispatch-receipt-admission-status
        yuanxu-dispatch-receipt-runtime-queue-intent
        yuanxu-dispatch-receipt-metadata
        yuanxu-dispatch-receipt->alist
        make-yuanxu-runtime-snapshot
        yuanxu-runtime-snapshot?
        yuanxu-runtime-snapshot-subject-kind
        yuanxu-runtime-snapshot-subject-id
        yuanxu-runtime-snapshot-status
        yuanxu-runtime-snapshot-last-event-index
        yuanxu-runtime-snapshot-result-summary
        yuanxu-runtime-snapshot-error-summary
        yuanxu-runtime-snapshot-presentation-trace
        yuanxu-runtime-snapshot-metadata
        yuanxu-runtime-snapshot->alist
        yuanxu-receipt->workflow-run
        yuanxu-workflow-run->snapshot
        yuanxu-agent-session->snapshot
        yuanxu-dispatch-receipt->snapshot)

;;; Boundary: agent harness alist ref is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Alist Symbol Value Value)
(def (yuanxu-agent-harness-alist-ref entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;;; Profiles are reusable policy objects. The fields are deliberately shallow:
;;; concrete model, tool, skill, sandbox, and loop details are references that
;;; later layers validate and lower.
;; : YuanxuAgentProfile
(defstruct yuanxu-agent-profile
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
  transparent: #t
  final: #t)

;; : YuanxuAgentHarness
(defstruct yuanxu-agent-harness
  (id
   profile
   sandbox-profile
   runtime-adapter-intent
   capabilities
   session-namespace
   observability-sink
   runtime-executed?
   metadata)
  transparent: #t
  final: #t)

;; : YuanxuAgentSession
(defstruct yuanxu-agent-session
  (name
   harness-id
   status
   active-operation-id
   conversation-state-ref
   retention-policy
   operation-history
   metadata)
  transparent: #t
  final: #t)

;; : YuanxuAgentOperation
(defstruct yuanxu-agent-operation
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
  transparent: #t
  final: #t)

;; : YuanxuWorkflowRun
(defstruct yuanxu-workflow-run
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
  transparent: #t
  final: #t)

;;; Dispatch admission is separate from workflow run completion. It records
;;; that input was accepted for a continuing agent/session.
;; : YuanxuDispatchReceipt
(defstruct yuanxu-dispatch-receipt
  (dispatch-id
   target-agent
   target-instance-id
   target-session-id
   payload-ref
   accepted-at
   admission-status
   runtime-queue-intent
   metadata)
  transparent: #t
  final: #t)

;; : YuanxuRuntimeSnapshot
(defstruct yuanxu-runtime-snapshot
  (subject-kind
   subject-id
   status
   last-event-index
   result-summary
   error-summary
   presentation-trace
   metadata)
  transparent: #t
  final: #t)

;; : (-> YuanxuAgentProfile Alist)
(defpoo-core-receipt-projection
  yuanxu-agent-profile->alist (profile)
  (bindings ())
  (fields ((kind 'agent-profile)
           (name (yuanxu-agent-profile-name profile))
           (model-policy (yuanxu-agent-profile-model-policy profile))
           (instructions (yuanxu-agent-profile-instructions profile))
           (tools (yuanxu-agent-profile-tools profile))
           (skills (yuanxu-agent-profile-skills profile))
           (sandbox-profile (yuanxu-agent-profile-sandbox-profile profile))
           (loop-policy (yuanxu-agent-profile-loop-policy profile))
           (compaction-policy
            (yuanxu-agent-profile-compaction-policy profile))
           (budget-policy (yuanxu-agent-profile-budget-policy profile))
           (observability-policy
            (yuanxu-agent-profile-observability-policy profile))
           (metadata (yuanxu-agent-profile-metadata profile))
           (runtime-executed #f))))

;; : (-> YuanxuAgentHarness Alist)
(defpoo-core-receipt-projection
  yuanxu-agent-harness->alist (harness)
  (bindings ())
  (fields ((kind 'agent-harness)
           (id (yuanxu-agent-harness-id harness))
           (profile (yuanxu-agent-harness-profile harness))
           (sandbox-profile (yuanxu-agent-harness-sandbox-profile harness))
           (runtime-adapter-intent
            (yuanxu-agent-harness-runtime-adapter-intent harness))
           (capabilities (yuanxu-agent-harness-capabilities harness))
           (session-namespace
            (yuanxu-agent-harness-session-namespace harness))
           (observability-sink
            (yuanxu-agent-harness-observability-sink harness))
           (runtime-executed
            (yuanxu-agent-harness-runtime-executed? harness))
           (metadata (yuanxu-agent-harness-metadata harness)))))

;; : (-> YuanxuAgentSession Alist)
(defpoo-core-receipt-projection
  yuanxu-agent-session->alist (session)
  (bindings ())
  (fields ((kind 'agent-session)
           (name (yuanxu-agent-session-name session))
           (harness-id (yuanxu-agent-session-harness-id session))
           (status (yuanxu-agent-session-status session))
           (active-operation-id
            (yuanxu-agent-session-active-operation-id session))
           (conversation-state-ref
            (yuanxu-agent-session-conversation-state-ref session))
           (retention-policy
            (yuanxu-agent-session-retention-policy session))
           (operation-history
            (yuanxu-agent-session-operation-history session))
           (metadata (yuanxu-agent-session-metadata session))
           (workflow-run? #f))))

;; : (-> YuanxuAgentOperation Boolean)
(def (yuanxu-agent-operation-delegated-task? operation)
  (eq? (yuanxu-agent-operation-kind operation) 'task))

;; : (-> YuanxuAgentOperation Alist)
(defpoo-core-receipt-projection
  yuanxu-agent-operation->alist (operation)
  (bindings ())
  (fields ((kind 'agent-operation)
           (operation-kind (yuanxu-agent-operation-kind operation))
           (id (yuanxu-agent-operation-id operation))
           (parent-session
            (yuanxu-agent-operation-parent-session operation))
           (parent-run (yuanxu-agent-operation-parent-run operation))
           (request (yuanxu-agent-operation-request operation))
           (result-contract
            (yuanxu-agent-operation-result-contract operation))
           (runtime-intent
            (yuanxu-agent-operation-runtime-intent operation))
           (status (yuanxu-agent-operation-status operation))
           (receipt (yuanxu-agent-operation-receipt operation))
           (delegated-task?
            (yuanxu-agent-operation-delegated-task? operation))
           (metadata (yuanxu-agent-operation-metadata operation)))))

;; : (-> YuanxuWorkflowRun Alist)
(defpoo-core-receipt-projection
  yuanxu-workflow-run->alist (run)
  (bindings ())
  (fields ((kind 'workflow-run)
           (run-id (yuanxu-workflow-run-run-id run))
           (workflow-ref (yuanxu-workflow-run-workflow-ref run))
           (payload-ref (yuanxu-workflow-run-payload-ref run))
           (status (yuanxu-workflow-run-status run))
           (harness-refs (yuanxu-workflow-run-harness-refs run))
           (event-stream-ref
            (yuanxu-workflow-run-event-stream-ref run))
           (logs (yuanxu-workflow-run-logs run))
           (result (yuanxu-workflow-run-result run))
           (error (yuanxu-workflow-run-error run))
           (terminal-receipt
            (yuanxu-workflow-run-terminal-receipt run))
           (metadata (yuanxu-workflow-run-metadata run)))))

;; : (-> YuanxuDispatchReceipt Alist)
(defpoo-core-receipt-projection
  yuanxu-dispatch-receipt->alist (receipt)
  (bindings ())
  (fields ((kind 'dispatch-receipt)
           (dispatch-id (yuanxu-dispatch-receipt-dispatch-id receipt))
           (target-agent (yuanxu-dispatch-receipt-target-agent receipt))
           (target-instance-id
            (yuanxu-dispatch-receipt-target-instance-id receipt))
           (target-session-id
            (yuanxu-dispatch-receipt-target-session-id receipt))
           (payload-ref (yuanxu-dispatch-receipt-payload-ref receipt))
           (accepted-at (yuanxu-dispatch-receipt-accepted-at receipt))
           (admission-status
            (yuanxu-dispatch-receipt-admission-status receipt))
           (runtime-queue-intent
            (yuanxu-dispatch-receipt-runtime-queue-intent receipt))
           (workflow-run-id #f)
           (metadata (yuanxu-dispatch-receipt-metadata receipt)))))

;; : (-> YuanxuRuntimeSnapshot Alist)
(defpoo-core-receipt-projection
  yuanxu-runtime-snapshot->alist (snapshot)
  (bindings ())
  (fields ((kind 'runtime-snapshot)
           (subject-kind
            (yuanxu-runtime-snapshot-subject-kind snapshot))
           (subject-id (yuanxu-runtime-snapshot-subject-id snapshot))
           (status (yuanxu-runtime-snapshot-status snapshot))
           (last-event-index
            (yuanxu-runtime-snapshot-last-event-index snapshot))
           (result-summary
            (yuanxu-runtime-snapshot-result-summary snapshot))
           (error-summary
            (yuanxu-runtime-snapshot-error-summary snapshot))
           (presentation-trace
            (yuanxu-runtime-snapshot-presentation-trace snapshot))
           (metadata (yuanxu-runtime-snapshot-metadata snapshot)))))

;;; Boundary: receipt workflow status is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Symbol Symbol)
(def (yuanxu-receipt-workflow-status status)
  (cond
   ((eq? status 'ok) 'completed)
   ((eq? status 'failed) 'errored)
   (else status)))

;;; Existing runner receipts can be projected into the new workflow-run object
;;; family without making the runner import this module. The caller supplies the
;;; run id because durable id ownership belongs to the admission/runtime layer.
;; : (-> Receipt Alist)
(defpoo-core-receipt-projection
  yuanxu-receipt-workflow-run-metadata (receipt)
  (bindings ())
  (fields ((source 'receipt)
           (strategy (receipt-strategy receipt))
           (policy (receipt-policy receipt))
           (frontier (receipt-frontier receipt))
           (event-count (receipt-event-count receipt))
           (adapter-request-count
            (receipt-adapter-request-count receipt)))))

;; : (-> Receipt RunId YuanxuWorkflowRun)
(def (yuanxu-receipt->workflow-run receipt run-id)
  (make-yuanxu-workflow-run
   run-id
   (receipt-flow receipt)
   (receipt-input receipt)
   (yuanxu-receipt-workflow-status (receipt-status receipt))
   '()
   (list 'receipt-events run-id)
   '()
   (receipt-output receipt)
   (receipt-error receipt)
   receipt
   (yuanxu-receipt-workflow-run-metadata receipt)))

;; : (-> YuanxuWorkflowRun YuanxuRuntimeSnapshot)
(defpoo-core-receipt-projection
  yuanxu-workflow-run-snapshot-details (run)
  (bindings ())
  (fields ((workflow-ref (yuanxu-workflow-run-workflow-ref run))
           (event-stream-ref
            (yuanxu-workflow-run-event-stream-ref run)))))

;; : (-> YuanxuWorkflowRun YuanxuRuntimeSnapshot)
(def (yuanxu-workflow-run->snapshot run)
  (make-yuanxu-runtime-snapshot
   'workflow-run
   (yuanxu-workflow-run-run-id run)
   (yuanxu-workflow-run-status run)
   (yuanxu-agent-harness-alist-ref
    (yuanxu-workflow-run-metadata run)
    'last-event-index
    #f)
   (yuanxu-workflow-run-result run)
   (yuanxu-workflow-run-error run)
   '((stage . workflow-run->snapshot)
     (runtime-executed . #f))
   (yuanxu-workflow-run-snapshot-details run)))

;; : (-> YuanxuAgentSession YuanxuRuntimeSnapshot)
(defpoo-core-receipt-projection
  yuanxu-agent-session-snapshot-details (session)
  (bindings ())
  (fields ((harness-id (yuanxu-agent-session-harness-id session))
           (active-operation-id
            (yuanxu-agent-session-active-operation-id session)))))

;; : (-> YuanxuAgentSession YuanxuRuntimeSnapshot)
(def (yuanxu-agent-session->snapshot session)
  (make-yuanxu-runtime-snapshot
   'agent-session
   (yuanxu-agent-session-name session)
   (yuanxu-agent-session-status session)
   (length (yuanxu-agent-session-operation-history session))
   #f
   #f
   '((stage . agent-session->snapshot)
     (runtime-executed . #f))
   (yuanxu-agent-session-snapshot-details session)))

;; : (-> YuanxuDispatchReceipt YuanxuRuntimeSnapshot)
(defpoo-core-receipt-projection
  yuanxu-dispatch-receipt-snapshot-details (receipt)
  (bindings ())
  (fields ((target-agent
            (yuanxu-dispatch-receipt-target-agent receipt))
           (target-session-id
            (yuanxu-dispatch-receipt-target-session-id receipt)))))

;; : (-> YuanxuDispatchReceipt YuanxuRuntimeSnapshot)
(def (yuanxu-dispatch-receipt->snapshot receipt)
  (make-yuanxu-runtime-snapshot
   'dispatch-receipt
   (yuanxu-dispatch-receipt-dispatch-id receipt)
   (yuanxu-dispatch-receipt-admission-status receipt)
   #f
   #f
   #f
   '((stage . dispatch-receipt->snapshot)
     (runtime-executed . #f))
   (yuanxu-dispatch-receipt-snapshot-details receipt)))
