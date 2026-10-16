;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Materializes one shared runtime request graph from accepted intent.
;;; Runtime execution remains outside the Scheme control plane.
(import :poo-flow/modules/workflow/control-plane/runtime-protocol
        "core.ss"
        "runtime-base.ss"
        "runtime-capability.ss"
        "runtime-agent.ss"
        "result-contract.ss"
        "runtime-intent-receipts.ss"
        "runtime-intent-snapshot.ss")

(export poo-flow-user-loop-engine-intent-runtime-request
        poo-flow-user-loop-engine-intent-runtime-envelope
        poo-flow-user-loop-engine-runtime-envelope/from-request)

;;; Materialize each expensive runtime projection once. The returned request
;;; deliberately shares its component values with higher-level projections;
;;; presentation must not rebuild the whole request for every report field.
(def (poo-flow-user-loop-engine-intent-runtime-request intent)
  (let* ((runtime-capability-descriptor
          (poo-flow-user-loop-engine-intent-runtime-capability-descriptor
           intent))
         (policy-profile-packet
          (poo-flow-user-loop-engine-intent-policy-profile-packet intent))
         (runtime-action-packets
          (list
           (poo-flow-user-loop-engine-intent-runtime-action-packet intent)))
         (runtime-receipt-batch-template
          (poo-flow-user-loop-engine-intent-runtime-receipt-batch-template
           intent))
         (workflow-agreement
          (poo-flow-user-loop-engine-intent-workflow-agreement intent))
         (result-contract
          (poo-flow-user-loop-engine-intent-result-contract intent))
         (agent-profiles
          (poo-flow-user-loop-engine-intent-agent-profiles intent))
         (agent-harnesses
          (poo-flow-user-loop-engine-intent-agent-harnesses intent))
         (agent-sessions
          (poo-flow-user-loop-engine-intent-agent-sessions intent))
         (session-agent-graph
          (poo-flow-user-loop-engine-intent-session-agent-graph intent))
         (session-agent-topology-trace
          (poo-flow-user-loop-engine-intent-session-agent-topology-trace
           intent))
         (workflow-run
          (poo-flow-user-loop-engine-intent-workflow-run intent))
         (dispatch-receipt
          (poo-flow-user-loop-engine-intent-dispatch-receipt intent))
         (agent-operation
          (poo-flow-user-loop-engine-intent-agent-operation intent))
         (delegated-operation
          (poo-flow-user-loop-engine-intent-delegated-operation intent))
         (lineage-receipt
          (poo-flow-user-loop-engine-intent-lineage-receipt intent))
         (selector-receipt
          (poo-flow-user-loop-engine-intent-selector-receipt intent))
         (resource-dispatch-receipt
          (poo-flow-user-loop-engine-intent-resource-dispatch-receipt intent))
         (capability-receipt
          (poo-flow-user-loop-engine-capability-receipt->alist
           (poo-flow-user-loop-engine-intent-capability-receipt intent)))
         (memory-receipt
          (poo-flow-user-loop-engine-intent-memory-receipt intent))
         (compression-receipt
          (poo-flow-user-loop-engine-intent-compression-receipt intent))
         (sandbox-agreement
          (poo-flow-user-loop-engine-intent-sandbox-handoff-agreement intent))
         (runtime-snapshot
          (poo-flow-user-loop-engine-runtime-snapshot/from-components
           intent
           workflow-agreement
           lineage-receipt
           selector-receipt
           resource-dispatch-receipt
           capability-receipt
           memory-receipt
           compression-receipt
           sandbox-agreement)))
    (list
            (cons 'kind 'loop-engine-runtime-handoff-request)
            (cons 'contract
                  +poo-flow-user-loop-engine-runtime-command-contract+)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'object-families
                  +poo-flow-user-loop-engine-runtime-object-families+)
            (cons 'receipt-contracts
                  +poo-flow-user-loop-engine-receipt-contracts+)
            (cons 'runtime-packet-contracts
                  +poo-flow-user-loop-engine-runtime-packet-contracts+)
            (cons 'runtime-capability-descriptor
                  runtime-capability-descriptor)
            (cons 'policy-profile-packet
                  policy-profile-packet)
            (cons 'runtime-action-packets
                  runtime-action-packets)
            (cons 'runtime-receipt-batch-template
                  runtime-receipt-batch-template)
            (cons 'use-case
                  (poo-flow-user-loop-engine-intent-ref intent 'use-case '()))
            (cons 'use-cases
                  (poo-flow-user-loop-engine-intent-ref intent 'use-cases '()))
            (cons 'workflow-agreement
                  workflow-agreement)
            (cons 'result-contract
                  result-contract)
            (cons 'agent-profiles
                  agent-profiles)
            (cons 'agent-harnesses
                  agent-harnesses)
            (cons 'agent-sessions
                  agent-sessions)
            (cons 'session-agent-graph
                  session-agent-graph)
            (cons 'session-agent-topology-trace
                  session-agent-topology-trace)
            (cons 'workflow-run
                  workflow-run)
            (cons 'dispatch-receipt
                  dispatch-receipt)
            (cons 'agent-operation
                  agent-operation)
            (cons 'delegated-operation
                  delegated-operation)
            (cons 'lineage-receipt
                  lineage-receipt)
            (cons 'selector-receipt
                  selector-receipt)
            (cons 'resource-dispatch-receipt
                  resource-dispatch-receipt)
            (cons 'capability-receipt
                  capability-receipt)
            (cons 'memory-receipt
                  memory-receipt)
            (cons 'compression-receipt
                  compression-receipt)
            (cons 'session-selector-receipts
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'session-selector-receipts
                   '()))
            (cons 'session-materialization-receipts
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'session-materialization-receipts
                   '()))
            (cons 'policy-extension-receipts
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'policy-extension-receipts
                   '()))
            (cons 'spec-evolution-reviews
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'spec-evolution-reviews
                   '()))
            (cons 'spec-evolution-human-audit-review-items
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'spec-evolution-human-audit-review-items
                   '()))
            (cons 'spec-evolution-runtime-manifest-rows
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'spec-evolution-runtime-manifest-rows
                   '()))
            (cons 'runtime-snapshot
                  runtime-snapshot)
            (cons 'sandbox-profile-refs
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'sandbox-profile-refs
                   '()))
            (cons 'sandbox-runtime-summaries
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'sandbox-runtime-summaries
                   '()))
            (cons 'sandbox-handoff-summaries
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'sandbox-handoff-summaries
                   '()))
            (cons 'sandbox-handoff-agreement
                  sandbox-agreement)
            (cons 'sandbox-unresolved-profile-refs
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'sandbox-unresolved-profile-refs
                   '()))
            (cons 'runtime-executed #f))))

(def (poo-flow-user-loop-engine-runtime-envelope/from-request intent request)
  (let ((use-case-name
         (poo-flow-user-loop-engine-intent-use-case-name intent)))
    (list
     (cons 'schema +runtime-request-schema+)
     (cons 'runtime 'manifest)
     (cons 'operation 'loop-engine-handoff)
     (cons 'request-id
           (poo-flow-user-loop-engine-runtime-id use-case-name "request"))
     (cons 'artifact-handle
           (poo-flow-user-loop-engine-runtime-id use-case-name "artifact"))
     (cons 'request request)
     (cons 'policy
           (poo-flow-user-loop-engine-intent-policy intent))
     (cons 'plan-id
           (poo-flow-user-loop-engine-runtime-id use-case-name "plan"))
     (cons 'node-id
           (poo-flow-user-loop-engine-runtime-id use-case-name "node"))
     (cons 'frontier
           (poo-flow-user-loop-engine-intent-ref intent 'agent-judges '())))))

;;; Handoff boundary: package stable request identities and evidence without executing the runtime operation.
(def (poo-flow-user-loop-engine-intent-runtime-envelope intent)
  (poo-flow-user-loop-engine-runtime-envelope/from-request
   intent
   (poo-flow-user-loop-engine-intent-runtime-request intent)))
