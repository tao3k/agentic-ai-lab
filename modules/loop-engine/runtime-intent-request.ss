;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Materializes one shared runtime request graph from accepted intent.
;;; Runtime execution remains outside the Scheme control plane.
(import :yuanxu/modules/funflow/control-plane/runtime-protocol
        "core.ss"
        "runtime-base.ss"
        "runtime-capability.ss"
        "runtime-agent.ss"
        "result-contract.ss"
        "runtime-intent-receipts.ss"
        "runtime-intent-snapshot.ss")

(export agentic-ai-lab-user-loop-engine-intent-runtime-request
        agentic-ai-lab-user-loop-engine-intent-runtime-envelope
        agentic-ai-lab-user-loop-engine-runtime-envelope/from-request)

;;; Materialize each expensive runtime projection once. The returned request
;;; deliberately shares its component values with higher-level projections;
;;; presentation must not rebuild the whole request for every report field.
(def (agentic-ai-lab-user-loop-engine-intent-runtime-request intent)
  (let* ((runtime-capability-descriptor
          (agentic-ai-lab-user-loop-engine-intent-runtime-capability-descriptor
           intent))
         (policy-profile-packet
          (agentic-ai-lab-user-loop-engine-intent-policy-profile-packet intent))
         (runtime-action-packets
          (list
           (agentic-ai-lab-user-loop-engine-intent-runtime-action-packet intent)))
         (runtime-receipt-batch-template
          (agentic-ai-lab-user-loop-engine-intent-runtime-receipt-batch-template
           intent))
         (workflow-agreement
          (agentic-ai-lab-user-loop-engine-intent-workflow-agreement intent))
         (result-contract
          (agentic-ai-lab-user-loop-engine-intent-result-contract intent))
         (agent-profiles
          (agentic-ai-lab-user-loop-engine-intent-agent-profiles intent))
         (agent-harnesses
          (agentic-ai-lab-user-loop-engine-intent-agent-harnesses intent))
         (agent-sessions
          (agentic-ai-lab-user-loop-engine-intent-agent-sessions intent))
         (session-agent-graph
          (agentic-ai-lab-user-loop-engine-intent-session-agent-graph intent))
         (session-agent-topology-trace
          (agentic-ai-lab-user-loop-engine-intent-session-agent-topology-trace
           intent))
         (workflow-run
          (agentic-ai-lab-user-loop-engine-intent-workflow-run intent))
         (dispatch-receipt
          (agentic-ai-lab-user-loop-engine-intent-dispatch-receipt intent))
         (agent-operation
          (agentic-ai-lab-user-loop-engine-intent-agent-operation intent))
         (delegated-operation
          (agentic-ai-lab-user-loop-engine-intent-delegated-operation intent))
         (lineage-receipt
          (agentic-ai-lab-user-loop-engine-intent-lineage-receipt intent))
         (selector-receipt
          (agentic-ai-lab-user-loop-engine-intent-selector-receipt intent))
         (resource-dispatch-receipt
          (agentic-ai-lab-user-loop-engine-intent-resource-dispatch-receipt intent))
         (capability-receipt
          (agentic-ai-lab-user-loop-engine-capability-receipt->alist
           (agentic-ai-lab-user-loop-engine-intent-capability-receipt intent)))
         (memory-receipt
          (agentic-ai-lab-user-loop-engine-intent-memory-receipt intent))
         (compression-receipt
          (agentic-ai-lab-user-loop-engine-intent-compression-receipt intent))
         (sandbox-agreement
          (agentic-ai-lab-user-loop-engine-intent-sandbox-handoff-agreement intent))
         (runtime-snapshot
          (agentic-ai-lab-user-loop-engine-runtime-snapshot/from-components
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
                  +agentic-ai-lab-user-loop-engine-runtime-command-contract+)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'object-families
                  +agentic-ai-lab-user-loop-engine-runtime-object-families+)
            (cons 'receipt-contracts
                  +agentic-ai-lab-user-loop-engine-receipt-contracts+)
            (cons 'runtime-packet-contracts
                  +agentic-ai-lab-user-loop-engine-runtime-packet-contracts+)
            (cons 'runtime-capability-descriptor
                  runtime-capability-descriptor)
            (cons 'policy-profile-packet
                  policy-profile-packet)
            (cons 'runtime-action-packets
                  runtime-action-packets)
            (cons 'runtime-receipt-batch-template
                  runtime-receipt-batch-template)
            (cons 'use-case
                  (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-case '()))
            (cons 'use-cases
                  (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-cases '()))
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
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   intent
                   'session-selector-receipts
                   '()))
            (cons 'session-materialization-receipts
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   intent
                   'session-materialization-receipts
                   '()))
            (cons 'policy-extension-receipts
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   intent
                   'policy-extension-receipts
                   '()))
            (cons 'spec-evolution-reviews
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   intent
                   'spec-evolution-reviews
                   '()))
            (cons 'spec-evolution-human-audit-review-items
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   intent
                   'spec-evolution-human-audit-review-items
                   '()))
            (cons 'spec-evolution-runtime-manifest-rows
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   intent
                   'spec-evolution-runtime-manifest-rows
                   '()))
            (cons 'runtime-snapshot
                  runtime-snapshot)
            (cons 'sandbox-profile-refs
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   intent
                   'sandbox-profile-refs
                   '()))
            (cons 'sandbox-runtime-summaries
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   intent
                   'sandbox-runtime-summaries
                   '()))
            (cons 'sandbox-handoff-summaries
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   intent
                   'sandbox-handoff-summaries
                   '()))
            (cons 'sandbox-handoff-agreement
                  sandbox-agreement)
            (cons 'sandbox-unresolved-profile-refs
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   intent
                   'sandbox-unresolved-profile-refs
                   '()))
            (cons 'runtime-executed #f))))

(def (agentic-ai-lab-user-loop-engine-runtime-envelope/from-request intent request)
  (let ((use-case-name
         (agentic-ai-lab-user-loop-engine-intent-use-case-name intent)))
    (list
     (cons 'schema +runtime-request-schema+)
     (cons 'runtime 'manifest)
     (cons 'operation 'loop-engine-handoff)
     (cons 'request-id
           (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "request"))
     (cons 'artifact-handle
           (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "artifact"))
     (cons 'request request)
     (cons 'policy
           (agentic-ai-lab-user-loop-engine-intent-policy intent))
     (cons 'plan-id
           (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "plan"))
     (cons 'node-id
           (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "node"))
     (cons 'frontier
           (agentic-ai-lab-user-loop-engine-intent-ref intent 'agent-judges '())))))

;;; Handoff boundary: package stable request identities and evidence without executing the runtime operation.
(def (agentic-ai-lab-user-loop-engine-intent-runtime-envelope intent)
  (agentic-ai-lab-user-loop-engine-runtime-envelope/from-request
   intent
   (agentic-ai-lab-user-loop-engine-intent-runtime-request intent)))
