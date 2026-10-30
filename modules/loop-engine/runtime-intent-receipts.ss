;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure receipt and packet projection from an accepted loop-engine intent.
;;; No runtime work is executed by this owner.
(import "core.ss"
        "runtime-base.ss"
        "runtime-capability.ss"
        "runtime-agent.ss"
        "result-contract.ss")

(export agentic-ai-lab-user-loop-engine-intent-runtime-action-kind
        agentic-ai-lab-user-loop-engine-intent-runtime-capability-descriptor
        agentic-ai-lab-user-loop-engine-intent-policy-profile-packet
        agentic-ai-lab-user-loop-engine-intent-runtime-action-packet
        agentic-ai-lab-user-loop-engine-intent-runtime-receipt-batch-template
        agentic-ai-lab-user-loop-engine-intent-lineage-receipt
        agentic-ai-lab-user-loop-engine-intent-selector-receipt
        agentic-ai-lab-user-loop-engine-intent-resource-dispatch-receipt
        agentic-ai-lab-user-loop-engine-intent-memory-receipt
        agentic-ai-lab-user-loop-engine-intent-compression-receipt)

(def (agentic-ai-lab-user-loop-engine-intent-runtime-action-kind intent)
  (if (null? (agentic-ai-lab-user-loop-engine-intent-ref intent 'human-audit '()))
    'run
    'ask-owner))

(def (agentic-ai-lab-user-loop-engine-intent-use-case-refs intent)
  (let ((selected (agentic-ai-lab-user-loop-engine-intent-use-case-name intent)))
    (reverse
     (foldl
      (lambda (entry refs)
        (if (and (pair? entry) (not (memq (car entry) refs)))
          (cons (car entry) refs)
          refs))
      (if selected (list selected) '())
      (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-cases '())))))

(def (agentic-ai-lab-user-loop-engine-intent-runtime-readiness-receipts
      intent
      sandbox-agreement)
  (list
   (list
    (cons 'kind 'loop-engine-runtime-action-readiness-receipt)
    (cons 'status 'ready)
    (cons 'action-kind
          (agentic-ai-lab-user-loop-engine-intent-runtime-action-kind intent))
    (cons 'sandbox-handoff-ready?
          (agentic-ai-lab-user-loop-engine-intent-ref
           sandbox-agreement
           'handoff-ready?
           #f))
    (cons 'runtime-owner "marlin-agent-core")
    (cons 'runtime-executed #f))))

(def (agentic-ai-lab-user-loop-engine-intent-runtime-receipt-contract kind)
  (case kind
    ((loop-engine-lineage-receipt)
     'agentic-ai-lab.loop-engine.lineage-receipt.v1)
    ((loop-engine-selector-receipt)
     'agentic-ai-lab.loop-engine.selector-receipt.v1)
    ((loop-engine-resource-dispatch-receipt)
     'agentic-ai-lab.loop-engine.resource-dispatch-receipt.v1)
    ((loop-engine-memory-receipt)
     'agentic-ai-lab.loop-engine.memory-receipt.v1)
    ((loop-engine-compression-receipt)
     'agentic-ai-lab.loop-engine.compression-receipt.v1)
    (else #f)))

(def (agentic-ai-lab-user-loop-engine-intent-runtime-receipt kind suffix intent fields)
  (let ((use-case-name
         (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
        (workflow-ref
         (agentic-ai-lab-user-loop-engine-intent-workflow-ref intent)))
    (append
     (list
      (cons 'kind kind)
      (cons 'contract
            (agentic-ai-lab-user-loop-engine-intent-runtime-receipt-contract kind))
      (cons 'receipt-id
            (agentic-ai-lab-user-loop-engine-runtime-id use-case-name suffix))
      (cons 'use-case-name use-case-name)
      (cons 'workflow-ref workflow-ref)
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'runtime-executed #f))
     fields)))

(def (agentic-ai-lab-user-loop-engine-intent-runtime-capability-descriptor intent)
  (let ((capability-receipt
         (agentic-ai-lab-user-loop-engine-capability-receipt->alist
          (agentic-ai-lab-user-loop-engine-intent-capability-receipt intent))))
    (list
     (cons 'kind 'loop-engine-runtime-capability-descriptor)
     (cons 'contract
           +agentic-ai-lab-user-loop-engine-runtime-capability-descriptor-contract+)
     (cons 'runtime-language 'rust)
     (cons 'transport-class 'manifest)
     (cons 'runtime-packet-contracts
           +agentic-ai-lab-user-loop-engine-runtime-packet-contracts+)
     (cons 'supports-readiness-gates? #t)
     (cons 'capability-receipt capability-receipt)
     (cons 'sandbox-profile-refs
           (agentic-ai-lab-user-loop-engine-intent-ref
            intent
            'sandbox-profile-refs
            '()))
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f))))

(def (agentic-ai-lab-user-loop-engine-intent-policy-profile-packet intent)
  (let ((use-case-name
         (agentic-ai-lab-user-loop-engine-intent-use-case-name intent)))
    (list
     (cons 'kind 'loop-engine-policy-profile-packet)
     (cons 'contract
           +agentic-ai-lab-user-loop-engine-policy-profile-packet-contract+)
     (cons 'profile-id
           (agentic-ai-lab-user-loop-engine-runtime-id
            use-case-name
            "policy-profile"))
     (cons 'source-refs (list use-case-name))
     (cons 'policy (agentic-ai-lab-user-loop-engine-intent-policy intent))
     (cons 'queue-policy
           (agentic-ai-lab-user-loop-engine-intent-ref
            intent
            'queue-policy
            '((prioritize-steering . #t))))
     (cons 'policy-extension-receipts
           (agentic-ai-lab-user-loop-engine-intent-ref
            intent
            'policy-extension-receipts
            '()))
     (cons 'sandbox-profile-refs
           (agentic-ai-lab-user-loop-engine-intent-ref
            intent
            'sandbox-profile-refs
            '()))
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f))))

(def (agentic-ai-lab-user-loop-engine-intent-runtime-action-packet intent)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (sandbox-agreement
          (agentic-ai-lab-user-loop-engine-intent-sandbox-handoff-agreement
           intent))
         (readiness-receipts
          (agentic-ai-lab-user-loop-engine-intent-runtime-readiness-receipts
           intent
           sandbox-agreement)))
    (list
     (cons 'kind 'loop-engine-runtime-action-packet)
     (cons 'contract +agentic-ai-lab-user-loop-engine-runtime-action-packet-contract+)
     (cons 'profile-id
           (agentic-ai-lab-user-loop-engine-runtime-id
            use-case-name
            "policy-profile"))
     (cons 'candidate-refs
           (agentic-ai-lab-user-loop-engine-intent-use-case-refs intent))
     (cons 'readiness-receipts
           readiness-receipts)
     (cons 'gate-state
           (list
            (cons 'sandbox-handoff-ready?
                  (agentic-ai-lab-user-loop-engine-intent-ref
                   sandbox-agreement
                   'handoff-ready?
                   #f))
            (cons 'readiness-receipts
                  readiness-receipts)))
     (cons 'action-kind
           (agentic-ai-lab-user-loop-engine-intent-runtime-action-kind intent))
     (cons 'operation-kind
           (agentic-ai-lab-user-loop-engine-intent-operation-kind intent))
     (cons 'result-contract
           (agentic-ai-lab-user-loop-engine-intent-operation-result-contract intent))
     (cons 'workflow-ref (agentic-ai-lab-user-loop-engine-intent-workflow-ref intent))
     (cons 'status (agentic-ai-lab-user-loop-engine-intent-status intent))
     (cons 'runtime-intent
           (agentic-ai-lab-user-loop-engine-intent-runtime-intent intent))
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f))))

(def (agentic-ai-lab-user-loop-engine-intent-runtime-receipt-batch-template intent)
  (list
   (cons 'kind 'loop-engine-runtime-receipt-batch-template)
   (cons 'contract +agentic-ai-lab-user-loop-engine-runtime-receipt-batch-contract+)
   (cons 'use-case-name
         (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
   (cons 'workflow-ref (agentic-ai-lab-user-loop-engine-intent-workflow-ref intent))
   (cons 'receipt-kinds
         '(dispatch
           lineage
           selector
           resource-dispatch
           capability
           memory
           compression))
   (cons 'status 'not-executed)
   (cons 'accepted-packet-ids '())
   (cons 'runtime-owner "marlin-agent-core")
   (cons 'runtime-executed #f)))

(def (agentic-ai-lab-user-loop-engine-intent-lineage-receipt intent)
  (let ((lineage-policy
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'lineage-policy '())))
    (agentic-ai-lab-user-loop-engine-intent-runtime-receipt
     'loop-engine-lineage-receipt
     "lineage"
     intent
     (list
      (cons 'status (agentic-ai-lab-user-loop-engine-intent-status intent))
      (cons 'lineage-policy lineage-policy)
      (cons 'parent-session-refs
            (agentic-ai-lab-user-loop-engine-intent-ref
             lineage-policy
             'parent-session-refs
             '()))
      (cons 'lineage-kind
            (agentic-ai-lab-user-loop-engine-intent-ref
             lineage-policy
             'lineage-kind
             #f))
      (cons 'lineage-operator
            (agentic-ai-lab-user-loop-engine-intent-ref
             lineage-policy
             'lineage-operator
             #f))
      (cons 'use-case
            (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-case '()))
      (cons 'use-cases
            (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-cases '()))
      (cons 'runtime-intent
            (agentic-ai-lab-user-loop-engine-intent-runtime-intent intent))
      (cons 'policy-profile-packet
            (agentic-ai-lab-user-loop-engine-intent-policy-profile-packet intent))
      (cons 'workflow-agreement
            (agentic-ai-lab-user-loop-engine-intent-workflow-agreement intent))))))

(def (agentic-ai-lab-user-loop-engine-intent-selector-receipt intent)
  (let ((selector-policy
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'selector-policy '())))
    (agentic-ai-lab-user-loop-engine-intent-runtime-receipt
     'loop-engine-selector-receipt
     "selector"
     intent
     (list
      (cons 'selector-policy selector-policy)
      (cons 'candidates
            (agentic-ai-lab-user-loop-engine-intent-ref
             selector-policy
             'candidates
             '()))
      (cons 'selected-branch
            (agentic-ai-lab-user-loop-engine-intent-ref
             selector-policy
             'selected-branch
             #f))
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
             '()))))))

(def (agentic-ai-lab-user-loop-engine-intent-resource-dispatch-receipt intent)
  (let ((resource-policy
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'resource-policy '())))
    (agentic-ai-lab-user-loop-engine-intent-runtime-receipt
     'loop-engine-resource-dispatch-receipt
     "resource-dispatch"
     intent
     (list
      (cons 'resource-policy resource-policy)
      (cons 'tool-refs
            (agentic-ai-lab-user-loop-engine-intent-ref
             resource-policy
             'tool-refs
             '()))
      (cons 'dispatch-groups
            (agentic-ai-lab-user-loop-engine-intent-ref
             resource-policy
             'dispatch-groups
             '()))
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
      (cons 'sandbox-unresolved-profile-refs
            (agentic-ai-lab-user-loop-engine-intent-ref
             intent
             'sandbox-unresolved-profile-refs
             '()))
      (cons 'sandbox-handoff-agreement
            (agentic-ai-lab-user-loop-engine-intent-sandbox-handoff-agreement
             intent))))))

(def (agentic-ai-lab-user-loop-engine-intent-memory-policy-for-use-case policies
                                                                  use-case)
  (cond
   ((null? policies) '())
   ((not (pair? policies)) '())
   ((equal? (agentic-ai-lab-user-loop-engine-intent-ref
             (car policies)
             'use-case
             #f)
            use-case)
    (car policies))
   (else
    (agentic-ai-lab-user-loop-engine-intent-memory-policy-for-use-case
     (cdr policies)
     use-case))))

;;; Receipt boundary: resolve one memory policy per use case and retain unresolved selections as diagnostics.
(def (agentic-ai-lab-user-loop-engine-intent-memory-receipt intent)
  (let* ((memory-policies
          (agentic-ai-lab-user-loop-engine-intent-ref intent 'memory-policies '()))
         (available-use-cases
          (map (lambda (policy)
                 (agentic-ai-lab-user-loop-engine-intent-ref
                  policy
                  'use-case
                  #f))
               memory-policies))
         (selector-policy
          (agentic-ai-lab-user-loop-engine-intent-ref intent 'selector-policy '()))
         (selected-use-case
          (agentic-ai-lab-user-loop-engine-intent-ref
           selector-policy
           'selected-branch
           (if (null? available-use-cases)
             #f
             (car available-use-cases))))
         (selected-policy
          (agentic-ai-lab-user-loop-engine-intent-memory-policy-for-use-case
           memory-policies
           selected-use-case)))
    (agentic-ai-lab-user-loop-engine-intent-runtime-receipt
     'loop-engine-memory-receipt
     "memory"
     intent
     (list
      (cons 'memory-intents
            (agentic-ai-lab-user-loop-engine-intent-ref intent 'memory-intents '()))
      (cons 'memory-policy
            (agentic-ai-lab-user-loop-engine-intent-ref intent 'memory-policy '()))
      (cons 'memory-policies memory-policies)
      (cons 'policies memory-policies)
      (cons 'selected-use-case selected-use-case)
      (cons 'use-case selected-use-case)
      (cons 'policy-count (length memory-policies))
      (cons 'available-use-cases available-use-cases)
      (cons 'selected-policy-found? (not (null? selected-policy)))
      (cons 'store
            (agentic-ai-lab-user-loop-engine-intent-ref selected-policy 'store #f))
      (cons 'state-path
            (agentic-ai-lab-user-loop-engine-intent-ref
             selected-policy
             'state-path
             #f))
      (cons 'scope
            (agentic-ai-lab-user-loop-engine-intent-ref selected-policy 'scope #f))
      (cons 'recall
            (agentic-ai-lab-user-loop-engine-intent-ref selected-policy 'recall '()))
      (cons 'commit
            (agentic-ai-lab-user-loop-engine-intent-ref selected-policy 'commit '()))
      (cons 'ranking
            (agentic-ai-lab-user-loop-engine-intent-ref selected-policy 'ranking #f))
      (cons 'retention
            (agentic-ai-lab-user-loop-engine-intent-ref
             selected-policy
             'retention
             #f))
      (cons 'checkpoint-ref
            (agentic-ai-lab-user-loop-engine-intent-ref intent 'checkpoint-ref #f))))))

(def (agentic-ai-lab-user-loop-engine-intent-compression-receipt intent)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (compression-policy
          (agentic-ai-lab-user-loop-engine-intent-ref
           intent
           'compression-policy
           '())))
    (agentic-ai-lab-user-loop-engine-intent-runtime-receipt
     'loop-engine-compression-receipt
     "compression"
     intent
     (list
      (cons 'compression-policy compression-policy)
      (cons 'strategy
            (agentic-ai-lab-user-loop-engine-intent-ref
             compression-policy
             'strategy
             #f))
      (cons 'trigger
            (agentic-ai-lab-user-loop-engine-intent-ref
             compression-policy
             'trigger
             #f))
      (cons 'summary-format
            (agentic-ai-lab-user-loop-engine-intent-ref
             compression-policy
             'summary-format
             #f))
      (cons 'lineage-kind
            (agentic-ai-lab-user-loop-engine-intent-ref
             compression-policy
             'lineage-kind
             #f))
      (cons 'source-session-ref
            (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "session"))
      (cons 'compressed-session-ref
            (agentic-ai-lab-user-loop-engine-runtime-id
             use-case-name
             "compressed-session"))
      (cons 'retention
            (agentic-ai-lab-user-loop-engine-intent-ref intent 'retention '()))
      (cons 'artifact-refs
            (agentic-ai-lab-user-loop-engine-intent-ref intent 'artifact-refs '()))))))
