;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable recovery scenario receipts for crash/replay/repair tests.
;;; Invariant: Scheme composes bounded handoff rows only; Rust/Marlin owns
;;; event persistence, replay, repair jobs, leases, and side effects.

(import :core/utilities/final-projection-syntax
        :poo-flow/modules/ai-agentic-context/features/memory/durable/recovery-support)

(export +poo-flow-durable-recovery-scenario-kind+
        +poo-flow-durable-recovery-scenario-schema+
        +poo-flow-durable-recovery-scenario-diagnostic-schema+
        +poo-flow-durable-recovery-observability-schema+
        +poo-flow-durable-recovery-stages+
        make-poo-flow-durable-recovery-scenario-receipt
        poo-flow-durable-recovery-scenario-receipt?
        poo-flow-durable-recovery-scenario-receipt-scenario-id
        poo-flow-durable-recovery-scenario-receipt-project-id
        poo-flow-durable-recovery-scenario-receipt-root-session-id
        poo-flow-durable-recovery-scenario-receipt-session-id
        poo-flow-durable-recovery-scenario-receipt-failure-kind
        poo-flow-durable-recovery-scenario-receipt-recovery-mode
        poo-flow-durable-recovery-scenario-receipt-runtime-store-row
        poo-flow-durable-recovery-scenario-receipt-session-graph-row
        poo-flow-durable-recovery-scenario-receipt-communication-rows
        poo-flow-durable-recovery-scenario-receipt-memory-job-rows
        poo-flow-durable-recovery-scenario-receipt-workflow-task-rows
        poo-flow-durable-recovery-scenario-receipt-sandbox-refs
        poo-flow-durable-recovery-scenario-receipt-checkpoint-ref
        poo-flow-durable-recovery-scenario-receipt-repair-policy-ref
        poo-flow-durable-recovery-scenario-receipt-event-log-ref
        poo-flow-durable-recovery-scenario-receipt-derived-index-ref
        poo-flow-durable-recovery-scenario-receipt-job-lease-ref
        poo-flow-durable-recovery-scenario-receipt-repair-journal-ref
        poo-flow-durable-recovery-scenario-receipt-deterministic-replay?
        poo-flow-durable-recovery-scenario-receipt-observability-rows
        poo-flow-durable-recovery-scenario-receipt-valid?
        poo-flow-durable-recovery-scenario-receipt-diagnostics
        poo-flow-durable-recovery-scenario-receipt-metadata
        poo-flow-durable-recovery-scenario
        poo-flow-durable-recovery-scenario->alist
        poo-flow-durable-recovery-scenarios->alists)

;; : PooFlowDurableRecoveryScenarioKind
(def +poo-flow-durable-recovery-scenario-kind+
  'poo-flow.durable.recovery-scenario)

;; : PooFlowDurableRecoveryScenarioSchemaId
(def +poo-flow-durable-recovery-scenario-schema+
  'poo-flow.module-system.durable-recovery-scenario.v1)

;; : PooDurableRecoveryScenarioReceiptStruct
(defstruct poo-flow-durable-recovery-scenario-receipt
  (scenario-id
   project-id
   root-session-id
   session-id
   failure-kind
   recovery-mode
   runtime-store-row
   session-graph-row
   communication-rows
   memory-job-rows
   workflow-task-rows
   sandbox-refs
   checkpoint-ref
   repair-policy-ref
   event-log-ref
   derived-index-ref
   job-lease-ref
   repair-journal-ref
   deterministic-replay?
   observability-rows
   valid?
   diagnostics
   metadata
   runtime-owner
   handoff-required
   runtime-executed)
  transparent: #t)

;;; Scenario construction folds heterogeneous durable rows into one receipt
;;; boundary so tests can cover replay and repair handoff without executing
;;; runtime side effects.
;; : (-> PooDurableRecoveryScenarioId PooDurableRecoveryProjectId PooDurableRecoveryRootSessionId PooDurableRecoverySessionId PooDurableRecoveryFailureKind PooDurableRecoveryRuntimeStoreRow [PooDurableRecoverySessionGraphRow] [PooDurableRecoveryCommunicationRow] [PooDurableRecoveryMemoryJobRow] [PooDurableRecoverySandboxRef] [PooDurableRecoveryWorkflowTaskRow] PooDurableRecoveryScenarioReceipt)
(def (poo-flow-durable-recovery-scenario scenario-id
                                          project-id
                                          root-session-id
                                          session-id
                                          runtime-store-receipt
                                          session-graph-row
                                          communication-rows
                                          memory-job-rows
                                          workflow-task-rows
                                          sandbox-refs
                                          . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (runtime-store-row
          (poo-flow-durable-recovery-runtime-store-row runtime-store-receipt))
         (failure-kind
          (poo-flow-durable-recovery-option
           options
           'failure-kind
           'process-crash))
         (recovery-mode
          (poo-flow-durable-recovery-option options 'recovery-mode 'replay))
         (event-log-ref
          (poo-flow-durable-recovery-option
           options
           'event-log-ref
           (poo-flow-durable-recovery-runtime-store-ref runtime-store-row
                                                        'fact-log-ref)))
         (checkpoint-ref
          (poo-flow-durable-recovery-option
           options
           'checkpoint-ref
           (poo-flow-durable-recovery-runtime-store-ref
            runtime-store-row
            'checkpoint-store-ref)))
         (derived-index-ref
          (poo-flow-durable-recovery-option
           options
           'derived-index-ref
           (poo-flow-durable-recovery-runtime-store-ref
            runtime-store-row
            'derived-index-ref)))
         (job-lease-ref
          (poo-flow-durable-recovery-option
           options
           'job-lease-ref
           (poo-flow-durable-recovery-runtime-store-ref runtime-store-row
                                                        'job-store-ref)))
         (repair-journal-ref
          (poo-flow-durable-recovery-option
           options
           'repair-journal-ref
           (poo-flow-durable-recovery-runtime-store-ref
            runtime-store-row
            'repair-journal-ref)))
         (repair-policy-ref
          (poo-flow-durable-recovery-option
           options
           'repair-policy-ref
           'repair/fail-closed))
         (metadata
          (poo-flow-durable-recovery-option options 'metadata '()))
         (runtime-owner
          (poo-flow-durable-recovery-option
           options
           'runtime-owner
           "marlin-agent-core"))
         (diagnostics
          (poo-flow-durable-recovery-diagnostics
           scenario-id
           project-id
           root-session-id
           session-id
           runtime-store-row
           communication-rows
           memory-job-rows
           workflow-task-rows
           sandbox-refs))
         (valid? (null? diagnostics))
         (observability-rows
          (poo-flow-durable-recovery-observability-rows
           scenario-id
           (if valid? 'ready 'blocked)
           (list (cons 'failure-kind failure-kind)
                 (cons 'recovery-mode recovery-mode)
                 (cons 'diagnostic-count (length diagnostics)))
           runtime-owner)))
    (make-poo-flow-durable-recovery-scenario-receipt
     scenario-id
     project-id
     root-session-id
     session-id
     failure-kind
     recovery-mode
     runtime-store-row
     session-graph-row
     communication-rows
     memory-job-rows
     workflow-task-rows
     sandbox-refs
     checkpoint-ref
     repair-policy-ref
     event-log-ref
     derived-index-ref
     job-lease-ref
     repair-journal-ref
     valid?
     observability-rows
     valid?
     diagnostics
     metadata
     runtime-owner
     #t
     #f)))

;; : (-> PooDurableRecoveryScenarioReceipt PooDurableRecoveryScenarioReceiptRow)
(defpoo-final-projection
  poo-flow-durable-recovery-scenario->alist (receipt)
  (bindings ((diagnostics
              (poo-flow-durable-recovery-scenario-receipt-diagnostics
               receipt))))
  (fields ((kind +poo-flow-durable-recovery-scenario-kind+)
           (schema +poo-flow-durable-recovery-scenario-schema+)
           (scenario-id
            (poo-flow-durable-recovery-scenario-receipt-scenario-id receipt))
           (project-id
            (poo-flow-durable-recovery-scenario-receipt-project-id receipt))
           (root-session-id
            (poo-flow-durable-recovery-scenario-receipt-root-session-id
             receipt))
           (session-id
            (poo-flow-durable-recovery-scenario-receipt-session-id receipt))
           (failure-kind
            (poo-flow-durable-recovery-scenario-receipt-failure-kind receipt))
           (recovery-mode
            (poo-flow-durable-recovery-scenario-receipt-recovery-mode receipt))
           (runtime-store
            (poo-flow-durable-recovery-scenario-receipt-runtime-store-row
             receipt))
           (session-graph
            (poo-flow-durable-recovery-scenario-receipt-session-graph-row
             receipt))
           (communication-rows
            (poo-flow-durable-recovery-scenario-receipt-communication-rows
             receipt))
           (memory-job-rows
            (poo-flow-durable-recovery-scenario-receipt-memory-job-rows
             receipt))
           (workflow-task-rows
            (poo-flow-durable-recovery-scenario-receipt-workflow-task-rows
             receipt))
           (sandbox-refs
            (poo-flow-durable-recovery-scenario-receipt-sandbox-refs receipt))
           (checkpoint-ref
            (poo-flow-durable-recovery-scenario-receipt-checkpoint-ref
             receipt))
           (repair-policy-ref
            (poo-flow-durable-recovery-scenario-receipt-repair-policy-ref
             receipt))
           (event-log-ref
            (poo-flow-durable-recovery-scenario-receipt-event-log-ref receipt))
           (derived-index-ref
            (poo-flow-durable-recovery-scenario-receipt-derived-index-ref
             receipt))
           (job-lease-ref
            (poo-flow-durable-recovery-scenario-receipt-job-lease-ref receipt))
           (repair-journal-ref
            (poo-flow-durable-recovery-scenario-receipt-repair-journal-ref
             receipt))
           (deterministic-replay?
            (poo-flow-durable-recovery-scenario-receipt-deterministic-replay?
             receipt))
           (observability-rows
            (poo-flow-durable-recovery-scenario-receipt-observability-rows
             receipt))
           (valid?
            (poo-flow-durable-recovery-scenario-receipt-valid? receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata
            (poo-flow-durable-recovery-scenario-receipt-metadata receipt))
           (runtime-owner
            (poo-flow-durable-recovery-scenario-receipt-runtime-owner receipt))
           (handoff-required
            (poo-flow-durable-recovery-scenario-receipt-handoff-required
             receipt))
           (runtime-executed
            (poo-flow-durable-recovery-scenario-receipt-runtime-executed
             receipt)))))

;; : (-> [PooDurableRecoveryScenarioReceipt] [PooDurableRecoveryScenarioReceiptRow])
(defpoo-final-projection-batch
  poo-flow-durable-recovery-scenarios->alists (receipts)
  (projector poo-flow-durable-recovery-scenario->alist)
  (error-message "durable recovery scenario serialization requires a list"))
