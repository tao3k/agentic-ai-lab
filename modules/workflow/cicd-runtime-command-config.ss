;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CI/CD runtime command projection prepares declarative handoff
;;; payloads for runtime owners and never invokes CI commands from Scheme.
;;; Invariant: manifest summaries preserve declaration order and record only
;;; policy data, while Marlin owns execution, process lifecycle, and retries.

(import :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/sandbox-core/profile-catalog
        :yuanxu/modules/funflow/graph-projection
        :yuanxu/modules/funflow/check-types
        :yuanxu/modules/funflow/check-objects
        :agentic-ai-lab/modules/workflow/funs)

(export agentic-ai-lab-user-cicd-payload?
        agentic-ai-lab-user-cicd-payload-section
        agentic-ai-lab-user-module-selection-cicd-intent
        agentic-ai-lab-user-config-cicd-intents/add
        agentic-ai-lab-user-config-cicd-intents
        agentic-ai-lab-user-module-selection-workflow-cicd-check-map
        agentic-ai-lab-user-config-workflow-cicd-check-maps/add
        agentic-ai-lab-user-config-workflow-cicd-check-maps
        agentic-ai-lab-user-workflow-cicd-functional-dags
        agentic-ai-lab-user-workflow-cicd-functional-dag-rows
        agentic-ai-lab-user-config-workflow-cicd-functional-dag-rows
        agentic-ai-lab-user-workflow-cicd-runtime-readiness/add
        agentic-ai-lab-user-config-workflow-cicd-runtime-readiness
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifests/add
        agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifests
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-map-manifests
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection/add-manifests
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection/add-maps
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries
        +agentic-ai-lab-user-workflow-cicd-runtime-owner+
        agentic-ai-lab-user-list-all-false?
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries-for
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-has-manifest?
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-extra-summary-diagnostics
        agentic-ai-lab-user-workflow-cicd-summary-count-diagnostics
        agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
        agentic-ai-lab-user-workflow-cicd-runtime-command-agreement-diagnostics
        agentic-ai-lab-user-workflow-cicd-runtime-command-durable-agreement-diagnostics
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-row
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-rows
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-row-diagnostics
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement/from-manifests
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement
        agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifest-agreement
        agentic-ai-lab-user-alist-ref)

(def (agentic-ai-lab-user-cicd-payload? payload)
  (and (pair? payload)
       (eq? (car payload) '+cicd)))

(def (agentic-ai-lab-user-cicd-payload-section payload section)
  (let (entry (assoc section (cdr payload)))
    (if entry (cdr entry) '())))

(def (agentic-ai-lab-user-module-selection-cicd-intent selection)
  (let ((payload
         (yuanxu-user-module-selection-flag-entry selection '+cicd)))
    (if (and (equal? (yuanxu-user-module-selection-key selection)
                     '(flow . funflow))
             (agentic-ai-lab-user-cicd-payload? payload))
      (list (cons 'key (yuanxu-user-module-selection-key selection))
            (cons 'feature '+cicd)
            (cons 'checks
                  (agentic-ai-lab-user-cicd-payload-section payload 'checks))
            (cons 'artifacts
                  (agentic-ai-lab-user-cicd-payload-section payload 'artifacts))
            (cons 'release
                  (agentic-ai-lab-user-cicd-payload-section payload 'release))
            (cons 'webhook
                  (agentic-ai-lab-user-cicd-payload-section payload 'webhook))
            (cons 'runtime
                  (agentic-ai-lab-user-cicd-payload-section payload 'runtime))
            (cons 'runtime-handoff 'runtime-command-manifest)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'descriptor-realized? #f)
            (cons 'runtime-executed #f))
      #f)))

(def (agentic-ai-lab-user-config-cicd-intents/add selected-modules)
  (cond
   ((null? selected-modules) '())
   ((agentic-ai-lab-user-module-selection-cicd-intent (car selected-modules))
    => (lambda (intent)
         (cons intent
               (agentic-ai-lab-user-config-cicd-intents/add
                (cdr selected-modules)))))
   (else
    (agentic-ai-lab-user-config-cicd-intents/add (cdr selected-modules)))))

(def (agentic-ai-lab-user-config-cicd-intents config)
  (agentic-ai-lab-user-config-cicd-intents/add
   (yuanxu-user-config-modules config)))

(def (agentic-ai-lab-user-module-selection-workflow-cicd-check-map selection)
  (let (entry
        (yuanxu-user-module-selection-flag-entry selection ':workflow-pipeline))
    (if (and entry
             (pair? entry)
             (yuanxu-cicd-check-map? (cdr entry)))
      (cdr entry)
      #f)))

(def (agentic-ai-lab-user-config-workflow-cicd-check-maps/add selected-modules)
  (cond
   ((null? selected-modules) '())
   ((agentic-ai-lab-user-module-selection-workflow-cicd-check-map
     (car selected-modules))
    => (lambda (check-map)
         (cons check-map
               (agentic-ai-lab-user-config-workflow-cicd-check-maps/add
                (cdr selected-modules)))))
   (else
    (agentic-ai-lab-user-config-workflow-cicd-check-maps/add
     (cdr selected-modules)))))

(def (agentic-ai-lab-user-config-workflow-cicd-check-maps config)
  (agentic-ai-lab-user-config-workflow-cicd-check-maps/add
   (yuanxu-user-config-modules config)))

(def (agentic-ai-lab-user-workflow-cicd-functional-dags check-maps)
  (map yuanxu-funflow-check-map->functional-dag check-maps))

(def (agentic-ai-lab-user-workflow-cicd-functional-dag-rows check-maps)
  (map yuanxu-funflow-functional-dag->alist
       (agentic-ai-lab-user-workflow-cicd-functional-dags check-maps)))

(def (agentic-ai-lab-user-config-workflow-cicd-functional-dag-rows config)
  (agentic-ai-lab-user-workflow-cicd-functional-dag-rows
   (agentic-ai-lab-user-config-workflow-cicd-check-maps config)))

(def (agentic-ai-lab-user-workflow-cicd-runtime-readiness/add check-maps
                                                        profile-catalog)
  (cond
   ((null? check-maps) '())
   (else
    (cons
     (agentic-ai-lab-cicd-check-map->runtime-manifest-readiness
      (car check-maps)
      profile-catalog)
     (agentic-ai-lab-user-workflow-cicd-runtime-readiness/add
      (cdr check-maps)
      profile-catalog)))))

(def (agentic-ai-lab-user-config-workflow-cicd-runtime-readiness config)
  (let* ((selected-modules (yuanxu-user-config-modules config))
         (profile-catalog
          (agentic-ai-lab-user-config-sandbox-profile-catalog selected-modules)))
    (agentic-ai-lab-user-workflow-cicd-runtime-readiness/add
     (agentic-ai-lab-user-config-workflow-cicd-check-maps config)
     profile-catalog)))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifests/add
      check-maps
      profile-catalog)
  (cond
   ((null? check-maps) '())
   (else
    (cons
     (agentic-ai-lab-cicd-check-map->runtime-command-manifests
      (car check-maps)
      profile-catalog)
     (agentic-ai-lab-user-workflow-cicd-runtime-command-manifests/add
      (cdr check-maps)
      profile-catalog)))))

(def (agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifests config)
  (let* ((selected-modules (yuanxu-user-config-modules config))
         (profile-catalog
          (agentic-ai-lab-user-config-sandbox-profile-catalog selected-modules)))
    (agentic-ai-lab-user-workflow-cicd-runtime-command-manifests/add
     (agentic-ai-lab-user-config-workflow-cicd-check-maps config)
     profile-catalog)))

(def (agentic-ai-lab-user-alist-ref entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-map-manifests
      manifest-maps)
  (agentic-ai-lab-user-alist-ref
   (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection
    manifest-maps)
   'manifests
   '()))

;;; Runtime command manifest summaries are bounded receipt projections. They
;;; preserve the keys used by agreement matching without retaining the complete
;;; manifest graph in every summary row.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary manifest)
  (let* ((request (agentic-ai-lab-user-alist-ref manifest 'request '()))
         (policy (agentic-ai-lab-user-alist-ref manifest 'policy '()))
         (metadata (agentic-ai-lab-user-alist-ref manifest 'metadata '()))
         (unresolved (agentic-ai-lab-user-alist-ref
                      request
                      'sandbox-unresolved-profile-refs
                      '())))
    (list
     (cons 'kind 'workflow-cicd-runtime-command-manifest-summary)
     (cons 'request-id (agentic-ai-lab-user-alist-ref manifest 'request-id #f))
     (cons 'check (agentic-ai-lab-user-alist-ref request 'check #f))
     (cons 'dependency-refs
           (agentic-ai-lab-user-alist-ref
            request
            'dependency-refs
            (agentic-ai-lab-user-alist-ref policy 'dependency-refs '())))
     (cons 'status
           (agentic-ai-lab-user-alist-ref manifest
                                    'status
                                    (if (null? unresolved) 'ready 'blocked)))
     (cons 'argv (agentic-ai-lab-user-alist-ref manifest 'argv '()))
     (cons 'runtime-owner
           (agentic-ai-lab-user-alist-ref manifest
                                    'runtime-owner
                                    +agentic-ai-lab-user-workflow-cicd-runtime-owner+))
     (cons 'runtime-executed
           (agentic-ai-lab-user-alist-ref
            metadata
            'runtime-executed
            (agentic-ai-lab-user-alist-ref request 'runtime-executed #f)))
     (cons 'handoff-ready
           (agentic-ai-lab-user-alist-ref
            manifest
            'handoff-ready
            (and (agentic-ai-lab-user-alist-ref
                  request
                  'handoff-required
                  (agentic-ai-lab-user-alist-ref policy 'handoff-required #f))
                 (null? unresolved)
                 (eq? (agentic-ai-lab-user-alist-ref
                       manifest
                       'status
                       (if (null? unresolved) 'ready 'blocked))
                      'ready))))
     (cons 'sandbox-profile-ref
           (agentic-ai-lab-user-alist-ref manifest 'sandbox-profile-ref #f))
     (cons 'sandbox-unresolved-profile-refs unresolved)
     (cons 'durable-task-id
           (agentic-ai-lab-user-alist-ref request 'durable-task-id #f))
     (cons 'action-class
           (agentic-ai-lab-user-alist-ref request 'action-class #f))
     (cons 'artifact-refs
           (agentic-ai-lab-user-alist-ref request 'artifact-refs '()))
     (cons 'artifact-provenance
           (agentic-ai-lab-user-alist-ref policy 'artifact-provenance '()))
     (cons 'artifact-retention
           (agentic-ai-lab-user-alist-ref request 'artifact-retention #f))
     (cons 'sandbox-refs
           (agentic-ai-lab-user-alist-ref request 'sandbox-refs '()))
     (cons 'checkpoint-ref
           (agentic-ai-lab-user-alist-ref request 'checkpoint-ref #f))
     (cons 'compensation-refs
           (agentic-ai-lab-user-alist-ref request 'compensation-refs '())))))

;;; Projection uses reverse accumulators to traverse manifest maps once, then
;;; restores declaration order only at the public summary boundary.
(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection/add-manifests
      manifests
      manifests-rev
      summaries-rev)
  (cond
   ((null? manifests)
    (values manifests-rev summaries-rev))
   (else
    (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection/add-manifests
     (cdr manifests)
     (cons (car manifests) manifests-rev)
     (cons
      (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary
       (car manifests))
      summaries-rev)))))

;;; Map traversal threads both reverse accumulators through each manifest list,
;;; avoiding append chains and ensuring every manifest is summarized once.
(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection/add-maps
      manifest-maps
      manifests-rev
      summaries-rev)
  (cond
   ((null? manifest-maps)
    (values manifests-rev summaries-rev))
   (else
    (let-values (((manifests-rev summaries-rev)
                  (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection/add-manifests
                   (agentic-ai-lab-user-alist-ref
                    (car manifest-maps)
                    'manifests
                    '())
                   manifests-rev
                   summaries-rev)))
      (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection/add-maps
       (cdr manifest-maps)
       manifests-rev
       summaries-rev)))))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection
      manifest-maps)
  (let-values (((manifests-rev summaries-rev)
                (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection/add-maps
                 manifest-maps
                 '()
                 '())))
    (list
     (cons 'manifests (reverse manifests-rev))
     (cons 'summaries (reverse summaries-rev)))))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries
      manifest-maps)
  (agentic-ai-lab-user-alist-ref
   (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection
    manifest-maps)
   'summaries
   '()))

(def +agentic-ai-lab-user-workflow-cicd-runtime-owner+ "marlin-agent-core")

(def (agentic-ai-lab-user-list-all-false? values)
  (cond
   ((null? values) #t)
   ((equal? (car values) #f)
    (agentic-ai-lab-user-list-all-false? (cdr values)))
   (else #f)))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries-for
      summaries
      request-id
      check-name)
  (cond
   ((null? summaries) '())
   ((and (equal? (agentic-ai-lab-user-alist-ref (car summaries)
                                          'request-id
                                          #f)
                 request-id)
         (equal? (agentic-ai-lab-user-alist-ref (car summaries) 'check #f)
                 check-name))
    (cons
     (car summaries)
     (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries-for
      (cdr summaries)
      request-id
      check-name)))
   (else
    (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries-for
     (cdr summaries)
     request-id
     check-name))))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-has-manifest?
      manifests
      summary)
  (cond
   ((null? manifests) #f)
   (else
    (let* ((manifest (car manifests))
           (request (agentic-ai-lab-user-alist-ref manifest 'request '()))
           (request-id (agentic-ai-lab-user-alist-ref manifest 'request-id #f))
           (check-name (agentic-ai-lab-user-alist-ref request 'check #f)))
      (if (and (equal? (agentic-ai-lab-user-alist-ref summary 'request-id #f)
                       request-id)
               (equal? (agentic-ai-lab-user-alist-ref summary 'check #f)
                       check-name))
        #t
        (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-has-manifest?
         (cdr manifests)
         summary))))))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-extra-summary-diagnostics
      manifests
      summaries)
  (cond
   ((null? summaries) '())
   ((agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-has-manifest?
     manifests
     (car summaries))
    (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-extra-summary-diagnostics
     manifests
     (cdr summaries)))
   (else
    (cons
     'extra-summary
     (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-extra-summary-diagnostics
      manifests
      (cdr summaries))))))

(def (agentic-ai-lab-user-workflow-cicd-summary-count-diagnostics summary-count)
  (cond
   ((= summary-count 1) '())
   ((= summary-count 0) '(missing-summary))
   (else '(duplicate-summary))))

(def (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics summary-present?
                                                              match?
                                                              code)
  (if (or (not summary-present?) match?)
    '()
    (list code)))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-agreement-diagnostics
      summary-count
      summary-present?
      check-match?
      argv-match?
      runtime-owner-match?
      unresolved-profile-refs-match?
      runtime-executed-match?)
  (append
   (agentic-ai-lab-user-workflow-cicd-summary-count-diagnostics summary-count)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? check-match? 'check-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? argv-match? 'argv-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? runtime-owner-match? 'runtime-owner-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present?
    unresolved-profile-refs-match?
    'unresolved-profile-refs-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? runtime-executed-match? 'runtime-executed-mismatch)))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-durable-agreement-diagnostics
      summary-present?
      durable-task-id-match?
      action-class-match?
      artifact-refs-match?
      artifact-provenance-match?
      artifact-retention-match?
      sandbox-refs-match?
      checkpoint-ref-match?
      compensation-refs-match?)
  (append
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? durable-task-id-match? 'durable-task-id-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? action-class-match? 'action-class-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? artifact-refs-match? 'artifact-refs-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? artifact-provenance-match? 'artifact-provenance-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? artifact-retention-match? 'artifact-retention-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? sandbox-refs-match? 'sandbox-refs-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? checkpoint-ref-match? 'checkpoint-ref-mismatch)
   (agentic-ai-lab-user-workflow-cicd-mismatch-diagnostics
    summary-present? compensation-refs-match? 'compensation-refs-mismatch)))

;;; Agreement rows compare one manifest with its bounded receipt summary. Keep
;;; matching here so diagnostics remain declarative and runtime execution stays
;;; outside the Scheme control plane.
(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-row
      manifest
      summary
      summary-count)
  (let* ((summary-row (or summary '()))
         (request (agentic-ai-lab-user-alist-ref manifest 'request '()))
         (policy (agentic-ai-lab-user-alist-ref manifest 'policy '()))
         (metadata (agentic-ai-lab-user-alist-ref manifest 'metadata '()))
         (request-id (agentic-ai-lab-user-alist-ref manifest 'request-id #f))
         (check-name (agentic-ai-lab-user-alist-ref request 'check #f))
         (manifest-argv (agentic-ai-lab-user-alist-ref manifest 'argv '()))
         (request-durable-task-id
          (agentic-ai-lab-user-alist-ref request 'durable-task-id #f))
         (request-action-class
          (agentic-ai-lab-user-alist-ref request 'action-class #f))
         (request-artifact-refs
          (agentic-ai-lab-user-alist-ref request 'artifact-refs '()))
         (request-artifact-retention
          (agentic-ai-lab-user-alist-ref request 'artifact-retention #f))
         (request-sandbox-refs
          (agentic-ai-lab-user-alist-ref request 'sandbox-refs '()))
         (request-checkpoint-ref
          (agentic-ai-lab-user-alist-ref request 'checkpoint-ref #f))
         (request-compensation-refs
          (agentic-ai-lab-user-alist-ref request 'compensation-refs '()))
         (policy-durable-task-id
          (agentic-ai-lab-user-alist-ref policy 'durable-task-id #f))
         (policy-action-class
          (agentic-ai-lab-user-alist-ref policy 'action-class #f))
         (policy-artifact-refs
          (agentic-ai-lab-user-alist-ref policy 'artifact-refs '()))
         (policy-artifact-provenance
          (agentic-ai-lab-user-alist-ref policy 'artifact-provenance '()))
         (policy-artifact-retention
          (agentic-ai-lab-user-alist-ref policy 'artifact-retention #f))
         (policy-sandbox-refs
          (agentic-ai-lab-user-alist-ref policy 'sandbox-refs '()))
         (policy-checkpoint-ref
          (agentic-ai-lab-user-alist-ref policy 'checkpoint-ref #f))
         (policy-compensation-refs
          (agentic-ai-lab-user-alist-ref policy 'compensation-refs '()))
         (request-unresolved
          (agentic-ai-lab-user-alist-ref request
                                   'sandbox-unresolved-profile-refs
                                   '()))
         (runtime-executed-values
          (list (agentic-ai-lab-user-alist-ref request 'runtime-executed #f)
                (agentic-ai-lab-user-alist-ref policy 'runtime-executed #f)
                (agentic-ai-lab-user-alist-ref metadata 'runtime-executed #f)))
         (summary-present? (= summary-count 1))
         (check-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row 'request-id #f)
                       request-id)
               (equal? (agentic-ai-lab-user-alist-ref summary-row 'check #f)
                       check-name)
               (equal? (agentic-ai-lab-user-alist-ref manifest 'name #f)
                       check-name)))
         (argv-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row 'argv '())
                       manifest-argv)))
         (runtime-owner-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row
                                                'runtime-owner
                                                #f)
                       +agentic-ai-lab-user-workflow-cicd-runtime-owner+)))
         (unresolved-profile-refs-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref
                        summary-row
                        'sandbox-unresolved-profile-refs
                        '())
                       request-unresolved)))
         (runtime-executed-match?
          (and summary-present?
               (agentic-ai-lab-user-list-all-false? runtime-executed-values)
               (equal? (agentic-ai-lab-user-alist-ref summary-row
                                                'runtime-executed
                                                #t)
                       #f)))
         (durable-task-id-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row
                                                'durable-task-id
                                                #f)
                       request-durable-task-id)
               (equal? request-durable-task-id policy-durable-task-id)))
         (action-class-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row
                                                'action-class
                                                #f)
                       request-action-class)
               (equal? request-action-class policy-action-class)))
         (artifact-refs-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row
                                                'artifact-refs
                                                '())
                       request-artifact-refs)
               (equal? request-artifact-refs policy-artifact-refs)))
         (artifact-provenance-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row
                                                'artifact-provenance
                                                '())
                       policy-artifact-provenance)))
         (artifact-retention-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row
                                                'artifact-retention
                                                #f)
                       request-artifact-retention)
               (equal? request-artifact-retention policy-artifact-retention)))
         (sandbox-refs-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row
                                                'sandbox-refs
                                                '())
                       request-sandbox-refs)
               (equal? request-sandbox-refs policy-sandbox-refs)))
         (checkpoint-ref-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row
                                                'checkpoint-ref
                                                #f)
                       request-checkpoint-ref)
               (equal? request-checkpoint-ref policy-checkpoint-ref)))
         (compensation-refs-match?
          (and summary-present?
               (equal? (agentic-ai-lab-user-alist-ref summary-row
                                                'compensation-refs
                                                '())
                       request-compensation-refs)
               (equal? request-compensation-refs policy-compensation-refs)))
         (diagnostics
          (append
           (agentic-ai-lab-user-workflow-cicd-runtime-command-agreement-diagnostics
            summary-count
            summary-present?
            check-match?
            argv-match?
            runtime-owner-match?
            unresolved-profile-refs-match?
            runtime-executed-match?)
           (agentic-ai-lab-user-workflow-cicd-runtime-command-durable-agreement-diagnostics
            summary-present?
            durable-task-id-match?
            action-class-match?
            artifact-refs-match?
            artifact-provenance-match?
            artifact-retention-match?
            sandbox-refs-match?
            checkpoint-ref-match?
            compensation-refs-match?))))
    (list
     (cons 'kind
           'workflow-cicd-runtime-command-manifest-agreement-row)
     (cons 'request-id request-id)
     (cons 'check check-name)
     (cons 'manifest? #t)
     (cons 'summary? summary-present?)
     (cons 'summary-count summary-count)
     (cons 'check-match? check-match?)
     (cons 'argv-match? argv-match?)
     (cons 'runtime-owner-match? runtime-owner-match?)
     (cons 'unresolved-profile-refs-match?
           unresolved-profile-refs-match?)
     (cons 'runtime-executed-match? runtime-executed-match?)
     (cons 'durable-task-id-match? durable-task-id-match?)
     (cons 'action-class-match? action-class-match?)
     (cons 'artifact-refs-match? artifact-refs-match?)
     (cons 'artifact-provenance-match? artifact-provenance-match?)
     (cons 'artifact-retention-match? artifact-retention-match?)
     (cons 'sandbox-refs-match? sandbox-refs-match?)
     (cons 'checkpoint-ref-match? checkpoint-ref-match?)
     (cons 'compensation-refs-match? compensation-refs-match?)
     (cons 'durable-task-id
           (agentic-ai-lab-user-alist-ref summary-row 'durable-task-id #f))
     (cons 'action-class
           (agentic-ai-lab-user-alist-ref summary-row 'action-class #f))
     (cons 'artifact-refs
           (agentic-ai-lab-user-alist-ref summary-row 'artifact-refs '()))
     (cons 'artifact-retention
           (agentic-ai-lab-user-alist-ref summary-row 'artifact-retention #f))
     (cons 'sandbox-refs
           (agentic-ai-lab-user-alist-ref summary-row 'sandbox-refs '()))
     (cons 'checkpoint-ref
           (agentic-ai-lab-user-alist-ref summary-row 'checkpoint-ref #f))
     (cons 'compensation-refs
           (agentic-ai-lab-user-alist-ref summary-row 'compensation-refs '()))
     (cons 'runtime-owner
           (agentic-ai-lab-user-alist-ref summary-row 'runtime-owner #f))
     (cons 'runtime-executed
           (agentic-ai-lab-user-alist-ref summary-row 'runtime-executed #f))
     (cons 'diagnostics diagnostics)
     (cons 'valid? (null? diagnostics)))))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-rows
      manifests
      summaries)
  (cond
   ((null? manifests) '())
   (else
    (let* ((manifest (car manifests))
           (request (agentic-ai-lab-user-alist-ref manifest 'request '()))
           (request-id (agentic-ai-lab-user-alist-ref manifest 'request-id #f))
           (check-name (agentic-ai-lab-user-alist-ref request 'check #f))
           (matching-summaries
            (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries-for
             summaries
             request-id
             check-name)))
      (cons
       (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-row
        manifest
        (if (null? matching-summaries) #f (car matching-summaries))
        (length matching-summaries))
       (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-rows
        (cdr manifests)
        summaries))))))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-row-diagnostics
      rows)
  (cond
   ((null? rows) '())
   (else
    (append
     (agentic-ai-lab-user-alist-ref (car rows) 'diagnostics '())
     (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-row-diagnostics
      (cdr rows))))))

;;; Aggregate agreement preserves cardinality mismatches as data for the
;;; runtime handoff rather than silently selecting or discarding a manifest.
(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement/from-manifests
      manifests
      summaries)
  (let* ((rows
          (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-rows
           manifests
           summaries))
         (diagnostics
          (append
           (if (= (length manifests) (length summaries))
             '()
             '(manifest-summary-count-mismatch))
           (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-extra-summary-diagnostics
            manifests
            summaries)
           (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement-row-diagnostics
            rows))))
    (list
     (cons 'kind 'workflow-cicd-runtime-command-manifest-agreement)
     (cons 'manifest-count (length manifests))
     (cons 'summary-count (length summaries))
     (cons 'agreement-count (length rows))
     (cons 'valid? (null? diagnostics))
     (cons 'diagnostics diagnostics)
     (cons 'rows rows)
     (cons 'runtime-owner +agentic-ai-lab-user-workflow-cicd-runtime-owner+)
     (cons 'runtime-executed #f))))

(def (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement
      manifest-maps
      summaries)
  (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement/from-manifests
   (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-map-manifests
    manifest-maps)
   summaries))

(def (agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifest-agreement
      config)
  (let* ((manifest-maps
          (agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifests
           config))
         (summaries
          (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries
           manifest-maps)))
    (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement
     manifest-maps
     summaries)))
