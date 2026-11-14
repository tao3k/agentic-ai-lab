;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure bounded snapshot projection for one accepted runtime intent.
;;; Snapshot construction consumes already materialized receipts.
(import "core.ss"
        "runtime-base.ss"
        "runtime-capability.ss"
        "runtime-intent-receipts.ss")

(export agentic-ai-lab-user-loop-engine-intent-runtime-snapshot
        agentic-ai-lab-user-loop-engine-runtime-snapshot/from-components)

;;; Runtime intent snapshots are already serialized as bounded alists at this
;;; boundary; avoid depending on the heavier runtime snapshot projection owner.
(def (agentic-ai-lab-user-loop-engine-runtime-snapshot/from-components
      intent
      workflow-agreement
      lineage-receipt
      selector-receipt
      resource-dispatch-receipt
      capability-receipt
      memory-receipt
      compression-receipt
      sandbox-agreement)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (workflow-ref
          (agentic-ai-lab-user-loop-engine-intent-workflow-ref intent))
         (spec-evolution-human-audit-review-items
          (agentic-ai-lab-user-loop-engine-intent-ref
           intent
           'spec-evolution-human-audit-review-items
           '()))
         (spec-evolution-runtime-manifest-rows
          (agentic-ai-lab-user-loop-engine-intent-ref
           intent
           'spec-evolution-runtime-manifest-rows
           '()))
         (handoff-ready?
          (and
           (agentic-ai-lab-user-loop-engine-intent-ref
            sandbox-agreement
            'handoff-ready?
            #f)
           (agentic-ai-lab-user-loop-engine-intent-ref
            workflow-agreement
            'valid?
            #f)))
         (handoff-summary
          (list (cons 'workflow-ref workflow-ref)
                (cons 'handoff-ready? handoff-ready?)
                (cons 'workflow-agreement workflow-agreement)
                (cons 'lineage-receipt lineage-receipt)
                (cons 'selector-receipt selector-receipt)
                (cons 'resource-dispatch-receipt resource-dispatch-receipt)
                (cons 'capability-receipt capability-receipt)
                (cons 'memory-receipt memory-receipt)
                (cons 'compression-receipt compression-receipt)
                (cons 'spec-evolution-human-audit-review-items
                      spec-evolution-human-audit-review-items)
                (cons 'spec-evolution-runtime-manifest-rows
                      spec-evolution-runtime-manifest-rows)
                (cons 'sandbox-handoff-agreement sandbox-agreement)
                (cons 'runtime-executed #f))))
    (list
     (cons 'kind 'runtime-snapshot)
     (cons 'subject-kind 'loop-engine)
     (cons 'subject-id use-case-name)
     (cons 'engine 'loop-engine)
     (cons 'use-case-name use-case-name)
     (cons 'status (agentic-ai-lab-user-loop-engine-intent-status intent))
     (cons 'result #f)
     (cons 'handoff-summary handoff-summary)
     (cons 'error #f)
     (cons 'metadata
           (list
            (cons 'stage 'user-config-loop-engine-runtime-snapshot)
            (cons 'workflow-agreement workflow-agreement)
            (cons 'handoff-ready? handoff-ready?)
            (cons 'runtime-executed #f)))
     (cons 'details
           (append
            handoff-summary
            (list (cons 'contract 'agentic-ai-lab.loop-governor.v1)
                  (cons 'runtime-owner "marlin-agent-core")))))))

(def (agentic-ai-lab-user-loop-engine-intent-runtime-snapshot intent)
  (agentic-ai-lab-user-loop-engine-runtime-snapshot/from-components
   intent
   (agentic-ai-lab-user-loop-engine-intent-workflow-agreement intent)
   (agentic-ai-lab-user-loop-engine-intent-lineage-receipt intent)
   (agentic-ai-lab-user-loop-engine-intent-selector-receipt intent)
   (agentic-ai-lab-user-loop-engine-intent-resource-dispatch-receipt intent)
   (agentic-ai-lab-user-loop-engine-capability-receipt->alist
    (agentic-ai-lab-user-loop-engine-intent-capability-receipt intent))
   (agentic-ai-lab-user-loop-engine-intent-memory-receipt intent)
   (agentic-ai-lab-user-loop-engine-intent-compression-receipt intent)
   (agentic-ai-lab-user-loop-engine-intent-sandbox-handoff-agreement intent)))
