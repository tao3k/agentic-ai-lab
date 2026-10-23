;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: projects user loop-engine configuration into runtime-owned inputs.
;;; Invariant: projection is pure and leaves execution to the runtime handoff boundary.
(import (only-in :yuanxu/modules/funflow/graph-projection
                 yuanxu-funflow-workflow-agreement)
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/sandbox-core/profile-catalog
        :agentic-ai-lab/modules/sandbox-core/backend-capability-catalog
        :agentic-ai-lab/modules/workflow/cicd-config
        :agentic-ai-lab/modules/workflow/cicd-runtime-command-config
        "core.ss"
        "runtime-base.ss"
        "runtime-capability.ss"
        "runtime-agent.ss"
        (only-in "runtime-intent-request.ss"
                 agentic-ai-lab-user-loop-engine-intent-runtime-request
                 agentic-ai-lab-user-loop-engine-runtime-envelope/from-request)
        (only-in "runtime-intent-manifest.ss"
                 agentic-ai-lab-user-loop-engine-runtime-command-manifest/from-envelope
                 agentic-ai-lab-user-loop-engine-runtime-command-manifest-summary/from-manifest
                 agentic-ai-lab-user-loop-engine-proof-manifest/from-manifest)
        (only-in "runtime-intent-handoff.ss"
                 agentic-ai-lab-user-loop-engine-runtime-handoff-facts/from-request)
        "result-contract.ss"
        :yuanxu/utilities/functional)

(export agentic-ai-lab-user-loop-engine-memory-policy-for-use-case
        agentic-ai-lab-user-loop-engine-memory-policy-use-cases/rev
        agentic-ai-lab-user-loop-engine-memory-policy-use-cases
        agentic-ai-lab-user-loop-engine-intent-runtime-projections
        agentic-ai-lab-user-loop-engine-intents-field-values
        agentic-ai-lab-user-module-selection-loop-engine?
        agentic-ai-lab-user-loop-engine-context-profile-catalog
        agentic-ai-lab-user-loop-engine-context-workflow-check-maps
        agentic-ai-lab-user-loop-engine-context-backend-capability-registry
        agentic-ai-lab-user-loop-engine-base-intent
        agentic-ai-lab-user-loop-engine-enriched-intent
        agentic-ai-lab-user-module-selection-loop-engine-intent
        agentic-ai-lab-user-config-loop-engine-intents/add
        agentic-ai-lab-user-config-loop-engine-intents/project-rev
        agentic-ai-lab-user-config-loop-engine-intents/project
        agentic-ai-lab-user-config-loop-engine-intent
        agentic-ai-lab-user-config-loop-engine-intents)

(def (agentic-ai-lab-user-loop-engine-memory-policy-for-use-case
      memory-policies
      use-case-name)
  (cond
   ((null? memory-policies) '())
   ((and (pair? memory-policies)
         (equal? (agentic-ai-lab-user-loop-engine-intent-ref
                  (car memory-policies)
                  'use-case
                  #f)
                 use-case-name))
    (car memory-policies))
   ((pair? memory-policies)
    (agentic-ai-lab-user-loop-engine-memory-policy-for-use-case
     (cdr memory-policies)
     use-case-name))
   (else '())))

(def (agentic-ai-lab-user-loop-engine-memory-policy-use-cases/rev
      memory-policies
      use-cases-rev)
  (yuanxu-fold-left
   (lambda (memory-policy use-cases)
     (cons (agentic-ai-lab-user-loop-engine-intent-ref
            memory-policy
            'use-case
            #f)
           use-cases))
   use-cases-rev
   memory-policies))

(def (agentic-ai-lab-user-loop-engine-memory-policy-use-cases memory-policies)
  (reverse
   (agentic-ai-lab-user-loop-engine-memory-policy-use-cases/rev
    memory-policies
    '())))

;;; Projection boundary: expose the accepted intent as named contract catalogs and runtime facts.
(def (agentic-ai-lab-user-loop-engine-intent-runtime-projections intent)
  ;; One request owns the expensive graph/receipt materialization. Every
  ;; presentation field below reuses values from that request, so the enriched
  ;; intent preserves one object graph rather than several equal deep copies.
  (let* ((request
          (agentic-ai-lab-user-loop-engine-intent-runtime-request intent))
         (envelope
          (agentic-ai-lab-user-loop-engine-runtime-envelope/from-request
           intent request))
         (runtime-command-manifest
          (agentic-ai-lab-user-loop-engine-runtime-command-manifest/from-envelope
           envelope))
         (runtime-command-manifest-summary
          (agentic-ai-lab-user-loop-engine-runtime-command-manifest-summary/from-manifest
           runtime-command-manifest))
         (proof-manifest
          (agentic-ai-lab-user-loop-engine-proof-manifest/from-manifest
           runtime-command-manifest)))
   (list
   (cons 'runtime-handoff-contracts
         +agentic-ai-lab-user-loop-engine-handoff-contracts+)
   (cons 'receipt-contracts
         +agentic-ai-lab-user-loop-engine-receipt-contracts+)
   (cons 'runtime-packet-contracts
         +agentic-ai-lab-user-loop-engine-runtime-packet-contracts+)
   (cons 'runtime-capability-descriptor
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'runtime-capability-descriptor '()))
   (cons 'policy-profile-packet
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'policy-profile-packet '()))
   (cons 'runtime-action-packets
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'runtime-action-packets '()))
   (cons 'runtime-receipt-batch-template
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'runtime-receipt-batch-template '()))
   (cons 'runtime-handoff-facts
         (agentic-ai-lab-user-loop-engine-runtime-handoff-facts/from-request
          intent request))
   (cons 'workflow-agreement
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'workflow-agreement '()))
   (cons 'result-contract
         (agentic-ai-lab-user-loop-engine-intent-ref request 'result-contract '()))
   (cons 'agent-profiles
         (agentic-ai-lab-user-loop-engine-intent-ref request 'agent-profiles '()))
   (cons 'agent-harnesses
         (agentic-ai-lab-user-loop-engine-intent-ref request 'agent-harnesses '()))
   (cons 'agent-sessions
         (agentic-ai-lab-user-loop-engine-intent-ref request 'agent-sessions '()))
   (cons 'session-agent-graph
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'session-agent-graph '()))
   (cons 'session-agent-topology-trace
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'session-agent-topology-trace '()))
   (cons 'workflow-run
         (agentic-ai-lab-user-loop-engine-intent-ref request 'workflow-run '()))
   (cons 'dispatch-receipt
         (agentic-ai-lab-user-loop-engine-intent-ref request 'dispatch-receipt '()))
   (cons 'agent-operation
         (agentic-ai-lab-user-loop-engine-intent-ref request 'agent-operation '()))
   (cons 'delegated-operation
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'delegated-operation '()))
   (cons 'lineage-receipt
         (agentic-ai-lab-user-loop-engine-intent-ref request 'lineage-receipt '()))
   (cons 'selector-receipt
         (agentic-ai-lab-user-loop-engine-intent-ref request 'selector-receipt '()))
   (cons 'resource-dispatch-receipt
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'resource-dispatch-receipt '()))
   (cons 'capability-receipt
         (agentic-ai-lab-user-loop-engine-intent-capability-receipt intent))
   (cons 'memory-receipt
         (agentic-ai-lab-user-loop-engine-intent-ref request 'memory-receipt '()))
   (cons 'compression-receipt
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'compression-receipt '()))
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
   (cons 'runtime-command-manifest
         runtime-command-manifest)
   (cons 'runtime-command-manifest-summary
         runtime-command-manifest-summary)
   (cons 'proof-manifest
         proof-manifest)
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
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'sandbox-handoff-agreement '()))
   (cons 'sandbox-unresolved-profile-refs
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'sandbox-unresolved-profile-refs
          '()))
   (cons 'runtime-snapshot
         (agentic-ai-lab-user-loop-engine-intent-ref
          request 'runtime-snapshot '())))))

(def (agentic-ai-lab-user-loop-engine-intents-field-values intents field)
  (yuanxu-fold-right
   (lambda (intent values)
     (cons (agentic-ai-lab-user-loop-engine-intent-ref intent field #f)
           values))
   '()
   intents))

(def (agentic-ai-lab-user-module-selection-loop-engine? selection)
  (equal? (yuanxu-user-module-selection-key selection)
          '(flow . loop-engine)))

(def (agentic-ai-lab-user-loop-engine-context-profile-catalog context)
  (if (null? context)
    (agentic-ai-lab-user-config-sandbox-profile-catalog '())
    (car context)))

(def (agentic-ai-lab-user-loop-engine-context-workflow-check-maps context)
  (if (or (null? context) (null? (cdr context)))
    '()
    (cadr context)))

(def (agentic-ai-lab-user-loop-engine-context-backend-capability-registry context)
  (if (or (null? context) (null? (cdr context)) (null? (cddr context)))
    (agentic-ai-lab-user-config-sandbox-backend-capability-registry '())
    (caddr context)))

(def (agentic-ai-lab-user-loop-engine-base-intent selection poo-intent-fields)
  (append
   (list (cons 'key
               (yuanxu-user-module-selection-key selection))
         (cons 'feature '+loop-engine)
         (cons 'workflow-owned? #t)
         (cons 'governor-derived? #t))
   poo-intent-fields
   (list
    (cons 'contract 'agentic-ai-lab.loop-governor.v1)
    (cons 'node-contract 'agentic-ai-lab.loop-governor.node.v1)
    (cons 'descriptor-realized? #f)
    (cons 'runtime-executed #f))))

(def (agentic-ai-lab-user-loop-engine-enriched-intent base-intent
                                                profile-catalog
                                                workflow-check-maps
                                                backend-capability-registry)
  (let* ((sandbox-profile-refs
          (agentic-ai-lab-user-loop-engine-sandbox-profile-refs base-intent))
         (sandbox-runtime-summaries
          (agentic-ai-lab-user-loop-engine-sandbox-runtime-summaries
           sandbox-profile-refs
           profile-catalog))
         (sandbox-handoff-summaries
          (agentic-ai-lab-user-loop-engine-sandbox-handoff-summaries
           sandbox-profile-refs
           profile-catalog))
         (sandbox-unresolved-profile-refs
          (agentic-ai-lab-user-loop-engine-sandbox-unresolved-profile-refs
           sandbox-profile-refs
           profile-catalog))
         (sandbox-handoff-agreement
          (agentic-ai-lab-user-loop-engine-sandbox-handoff-agreement
           sandbox-profile-refs
           sandbox-runtime-summaries
           sandbox-handoff-summaries
           sandbox-unresolved-profile-refs))
         (workflow-agreement
          (yuanxu-funflow-workflow-agreement
           (agentic-ai-lab-user-loop-engine-intent-workflow-ref base-intent)
           workflow-check-maps))
         (workflow-functional-dags
          (agentic-ai-lab-user-alist-ref workflow-agreement
                                   'functional-dags
                                   '()))
         (intent
          (append
           base-intent
           (list
            (cons 'workflow-agreement workflow-agreement)
            (cons 'workflow-functional-dag-count
                  (agentic-ai-lab-user-alist-ref workflow-agreement
                                           'functional-dag-count
                                           0))
            (cons 'workflow-functional-dags workflow-functional-dags)
            (cons 'sandbox-profile-refs sandbox-profile-refs)
            (cons 'sandbox-runtime-summaries sandbox-runtime-summaries)
            (cons 'sandbox-handoff-summaries sandbox-handoff-summaries)
            (cons 'sandbox-handoff-agreement sandbox-handoff-agreement)
            (cons 'sandbox-unresolved-profile-refs
                  sandbox-unresolved-profile-refs))))
         (capability-receipt
          (agentic-ai-lab-user-loop-engine-intent-capability-receipt
           intent
           backend-capability-registry))
         (intent-with-capability
          (append intent
                  (list (cons 'capability-receipt capability-receipt)))))
    (append intent-with-capability
            (agentic-ai-lab-user-loop-engine-intent-runtime-projections
             intent-with-capability))))

(def (agentic-ai-lab-user-module-selection-loop-engine-intent selection
                                                       . maybe-context)
  (and (agentic-ai-lab-user-module-selection-loop-engine? selection)
       (let (poo-intent-fields
             (agentic-ai-lab-user-loop-engine-selection-poo-intent selection))
         (and poo-intent-fields
              (agentic-ai-lab-user-loop-engine-enriched-intent
               (agentic-ai-lab-user-loop-engine-base-intent selection
                                                      poo-intent-fields)
               (agentic-ai-lab-user-loop-engine-context-profile-catalog
                maybe-context)
               (agentic-ai-lab-user-loop-engine-context-workflow-check-maps
                maybe-context)
               (agentic-ai-lab-user-loop-engine-context-backend-capability-registry
                maybe-context))))))

(def (agentic-ai-lab-user-config-loop-engine-intents/add selected-modules
                                                   profile-catalog
                                                   . maybe-workflow-check-maps)
  (let ((workflow-check-maps
         (if (null? maybe-workflow-check-maps)
           '()
           (car maybe-workflow-check-maps)))
        (backend-capability-registry
         (if (or (null? maybe-workflow-check-maps)
                 (null? (cdr maybe-workflow-check-maps)))
           (agentic-ai-lab-user-config-sandbox-backend-capability-registry
            selected-modules)
           (cadr maybe-workflow-check-maps))))
    (let (cache (vector '()))
      ;; Engineering note: policy-sensitive helpers in this owner keep explicit
      ;; contracts adjacent to definitions so downstream reports stay actionable.
      ;; : (-> Any Any)
      (def (project-selection selection)
        (let (entry (assq selection (vector-ref cache 0)))
          (if entry
            (cdr entry)
            (let (intent
                  (agentic-ai-lab-user-config-loop-engine-intent
                   selection
                   profile-catalog
                   workflow-check-maps
                   backend-capability-registry))
              (vector-set! cache
                           0
                           (cons (cons selection intent)
                                 (vector-ref cache 0)))
              intent))))
      (agentic-ai-lab-user-config-loop-engine-intents/project
       project-selection
       selected-modules))))

(def (agentic-ai-lab-user-config-loop-engine-intents/project-rev project-selection
                                                           selected-modules
                                                           intents-rev)
  (yuanxu-fold-left
   (lambda (selection intents)
     (let (intent (project-selection selection))
       (if intent
         (cons intent intents)
         intents)))
   intents-rev
   selected-modules))

(def (agentic-ai-lab-user-config-loop-engine-intents/project project-selection
                                                       selected-modules)
  (reverse
   (agentic-ai-lab-user-config-loop-engine-intents/project-rev
    project-selection
    selected-modules
    '())))

(def (agentic-ai-lab-user-config-loop-engine-intent selection
                                              profile-catalog
                                              workflow-check-maps
                                              .
                                              maybe-backend-capability-registry)
  (agentic-ai-lab-user-module-selection-loop-engine-intent
   selection
   profile-catalog
   workflow-check-maps
   (if (null? maybe-backend-capability-registry)
     (agentic-ai-lab-user-config-sandbox-backend-capability-registry '())
     (car maybe-backend-capability-registry))))

(def (agentic-ai-lab-user-config-loop-engine-intents config)
  (let* ((selected-modules (yuanxu-user-config-modules config))
         (profile-catalog
          (agentic-ai-lab-user-config-sandbox-profile-catalog selected-modules))
         (workflow-check-maps
          (agentic-ai-lab-user-config-workflow-cicd-check-maps config))
         (backend-capability-registry
          (agentic-ai-lab-user-config-sandbox-backend-capability-registry
           selected-modules)))
    (agentic-ai-lab-user-config-loop-engine-intents/add
     selected-modules
     profile-catalog
     workflow-check-maps
     backend-capability-registry)))
