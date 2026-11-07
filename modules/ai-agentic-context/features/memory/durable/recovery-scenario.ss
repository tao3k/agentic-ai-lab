;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable recovery scenario receipts for crash/replay/repair tests.
;;; Invariant: Scheme composes bounded handoff rows only; Rust/Marlin owns
;;; event persistence, replay, repair jobs, leases, and side effects.

(import :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/recovery-support)

(export +agentic-ai-lab-durable-recovery-scenario-kind+
        +agentic-ai-lab-durable-recovery-scenario-schema+
        +agentic-ai-lab-durable-recovery-scenario-diagnostic-schema+
        +agentic-ai-lab-durable-recovery-observability-schema+
        +agentic-ai-lab-durable-recovery-stages+
        make-agentic-ai-lab-durable-recovery-scenario-receipt
        agentic-ai-lab-durable-recovery-scenario-receipt?
        agentic-ai-lab-durable-recovery-scenario-receipt-scenario-id
        agentic-ai-lab-durable-recovery-scenario-receipt-project-id
        agentic-ai-lab-durable-recovery-scenario-receipt-root-session-id
        agentic-ai-lab-durable-recovery-scenario-receipt-session-id
        agentic-ai-lab-durable-recovery-scenario-receipt-failure-kind
        agentic-ai-lab-durable-recovery-scenario-receipt-recovery-mode
        agentic-ai-lab-durable-recovery-scenario-receipt-runtime-store-row
        agentic-ai-lab-durable-recovery-scenario-receipt-session-graph-row
        agentic-ai-lab-durable-recovery-scenario-receipt-communication-rows
        agentic-ai-lab-durable-recovery-scenario-receipt-memory-job-rows
        agentic-ai-lab-durable-recovery-scenario-receipt-workflow-task-rows
        agentic-ai-lab-durable-recovery-scenario-receipt-sandbox-refs
        agentic-ai-lab-durable-recovery-scenario-receipt-checkpoint-ref
        agentic-ai-lab-durable-recovery-scenario-receipt-repair-policy-ref
        agentic-ai-lab-durable-recovery-scenario-receipt-event-log-ref
        agentic-ai-lab-durable-recovery-scenario-receipt-derived-index-ref
        agentic-ai-lab-durable-recovery-scenario-receipt-job-lease-ref
        agentic-ai-lab-durable-recovery-scenario-receipt-repair-journal-ref
        agentic-ai-lab-durable-recovery-scenario-receipt-deterministic-replay?
        agentic-ai-lab-durable-recovery-scenario-receipt-observability-rows
        agentic-ai-lab-durable-recovery-scenario-receipt-valid?
        agentic-ai-lab-durable-recovery-scenario-receipt-diagnostics
        agentic-ai-lab-durable-recovery-scenario-receipt-metadata
        agentic-ai-lab-durable-recovery-scenario
        agentic-ai-lab-durable-recovery-scenario->alist
        agentic-ai-lab-durable-recovery-scenarios->alists)

;; : AgenticAILabDurableRecoveryScenarioKind
(def +agentic-ai-lab-durable-recovery-scenario-kind+
  'agentic-ai-lab.durable.recovery-scenario)

;; : AgenticAILabDurableRecoveryScenarioSchemaId
(def +agentic-ai-lab-durable-recovery-scenario-schema+
  'agentic-ai-lab.module-system.durable-recovery-scenario.v1)

;; : PooDurableRecoveryScenarioReceiptStruct
(defstruct agentic-ai-lab-durable-recovery-scenario-receipt
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
(def (agentic-ai-lab-durable-recovery-scenario scenario-id
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
          (agentic-ai-lab-durable-recovery-runtime-store-row runtime-store-receipt))
         (failure-kind
          (agentic-ai-lab-durable-recovery-option
           options
           'failure-kind
           'process-crash))
         (recovery-mode
          (agentic-ai-lab-durable-recovery-option options 'recovery-mode 'replay))
         (event-log-ref
          (agentic-ai-lab-durable-recovery-option
           options
           'event-log-ref
           (agentic-ai-lab-durable-recovery-runtime-store-ref runtime-store-row
                                                        'fact-log-ref)))
         (checkpoint-ref
          (agentic-ai-lab-durable-recovery-option
           options
           'checkpoint-ref
           (agentic-ai-lab-durable-recovery-runtime-store-ref
            runtime-store-row
            'checkpoint-store-ref)))
         (derived-index-ref
          (agentic-ai-lab-durable-recovery-option
           options
           'derived-index-ref
           (agentic-ai-lab-durable-recovery-runtime-store-ref
            runtime-store-row
            'derived-index-ref)))
         (job-lease-ref
          (agentic-ai-lab-durable-recovery-option
           options
           'job-lease-ref
           (agentic-ai-lab-durable-recovery-runtime-store-ref runtime-store-row
                                                        'job-store-ref)))
         (repair-journal-ref
          (agentic-ai-lab-durable-recovery-option
           options
           'repair-journal-ref
           (agentic-ai-lab-durable-recovery-runtime-store-ref
            runtime-store-row
            'repair-journal-ref)))
         (repair-policy-ref
          (agentic-ai-lab-durable-recovery-option
           options
           'repair-policy-ref
           'repair/fail-closed))
         (metadata
          (agentic-ai-lab-durable-recovery-option options 'metadata '()))
         (runtime-owner
          (agentic-ai-lab-durable-recovery-option
           options
           'runtime-owner
           "marlin-agent-core"))
         (diagnostics
          (agentic-ai-lab-durable-recovery-diagnostics
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
          (agentic-ai-lab-durable-recovery-observability-rows
           scenario-id
           (if valid? 'ready 'blocked)
           (list (cons 'failure-kind failure-kind)
                 (cons 'recovery-mode recovery-mode)
                 (cons 'diagnostic-count (length diagnostics)))
           runtime-owner)))
    (make-agentic-ai-lab-durable-recovery-scenario-receipt
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
  agentic-ai-lab-durable-recovery-scenario->alist (receipt)
  (bindings ((diagnostics
              (agentic-ai-lab-durable-recovery-scenario-receipt-diagnostics
               receipt))))
  (fields ((kind +agentic-ai-lab-durable-recovery-scenario-kind+)
           (schema +agentic-ai-lab-durable-recovery-scenario-schema+)
           (scenario-id
            (agentic-ai-lab-durable-recovery-scenario-receipt-scenario-id receipt))
           (project-id
            (agentic-ai-lab-durable-recovery-scenario-receipt-project-id receipt))
           (root-session-id
            (agentic-ai-lab-durable-recovery-scenario-receipt-root-session-id
             receipt))
           (session-id
            (agentic-ai-lab-durable-recovery-scenario-receipt-session-id receipt))
           (failure-kind
            (agentic-ai-lab-durable-recovery-scenario-receipt-failure-kind receipt))
           (recovery-mode
            (agentic-ai-lab-durable-recovery-scenario-receipt-recovery-mode receipt))
           (runtime-store
            (agentic-ai-lab-durable-recovery-scenario-receipt-runtime-store-row
             receipt))
           (session-graph
            (agentic-ai-lab-durable-recovery-scenario-receipt-session-graph-row
             receipt))
           (communication-rows
            (agentic-ai-lab-durable-recovery-scenario-receipt-communication-rows
             receipt))
           (memory-job-rows
            (agentic-ai-lab-durable-recovery-scenario-receipt-memory-job-rows
             receipt))
           (workflow-task-rows
            (agentic-ai-lab-durable-recovery-scenario-receipt-workflow-task-rows
             receipt))
           (sandbox-refs
            (agentic-ai-lab-durable-recovery-scenario-receipt-sandbox-refs receipt))
           (checkpoint-ref
            (agentic-ai-lab-durable-recovery-scenario-receipt-checkpoint-ref
             receipt))
           (repair-policy-ref
            (agentic-ai-lab-durable-recovery-scenario-receipt-repair-policy-ref
             receipt))
           (event-log-ref
            (agentic-ai-lab-durable-recovery-scenario-receipt-event-log-ref receipt))
           (derived-index-ref
            (agentic-ai-lab-durable-recovery-scenario-receipt-derived-index-ref
             receipt))
           (job-lease-ref
            (agentic-ai-lab-durable-recovery-scenario-receipt-job-lease-ref receipt))
           (repair-journal-ref
            (agentic-ai-lab-durable-recovery-scenario-receipt-repair-journal-ref
             receipt))
           (deterministic-replay?
            (agentic-ai-lab-durable-recovery-scenario-receipt-deterministic-replay?
             receipt))
           (observability-rows
            (agentic-ai-lab-durable-recovery-scenario-receipt-observability-rows
             receipt))
           (valid?
            (agentic-ai-lab-durable-recovery-scenario-receipt-valid? receipt))
           (diagnostics diagnostics)
           (diagnostic-count (length diagnostics))
           (metadata
            (agentic-ai-lab-durable-recovery-scenario-receipt-metadata receipt))
           (runtime-owner
            (agentic-ai-lab-durable-recovery-scenario-receipt-runtime-owner receipt))
           (handoff-required
            (agentic-ai-lab-durable-recovery-scenario-receipt-handoff-required
             receipt))
           (runtime-executed
            (agentic-ai-lab-durable-recovery-scenario-receipt-runtime-executed
             receipt)))))

;; : (-> [PooDurableRecoveryScenarioReceipt] [PooDurableRecoveryScenarioReceiptRow])
(defpoo-final-projection-batch
  agentic-ai-lab-durable-recovery-scenarios->alists (receipts)
  (projector agentic-ai-lab-durable-recovery-scenario->alist)
  (error-message "durable recovery scenario serialization requires a list"))
