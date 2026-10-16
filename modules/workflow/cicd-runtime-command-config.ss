;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CI/CD runtime command projection prepares declarative handoff
;;; payloads for runtime owners and never invokes CI commands from Scheme.
;;; Invariant: manifest summaries preserve declaration order and record only
;;; policy data, while Marlin owns execution, process lifecycle, and retries.

(import :core/module-system/selection/objects
        :poo-flow/modules/sandbox-core/profile-catalog
        :poo-flow/modules/funflow/config
        :poo-flow/modules/workflow/types
        :poo-flow/modules/workflow/objects
        :poo-flow/modules/workflow/funs)

(export poo-flow-user-cicd-payload?
        poo-flow-user-cicd-payload-section
        poo-flow-user-module-selection-cicd-intent
        poo-flow-user-config-cicd-intents/add
        poo-flow-user-config-cicd-intents
        poo-flow-user-module-selection-workflow-cicd-check-map
        poo-flow-user-config-workflow-cicd-check-maps/add
        poo-flow-user-config-workflow-cicd-check-maps
        poo-flow-user-workflow-cicd-functional-dags
        poo-flow-user-workflow-cicd-functional-dag-rows
        poo-flow-user-config-workflow-cicd-functional-dag-rows
        poo-flow-user-workflow-cicd-runtime-readiness/add
        poo-flow-user-config-workflow-cicd-runtime-readiness
        poo-flow-user-workflow-cicd-runtime-command-manifests/add
        poo-flow-user-config-workflow-cicd-runtime-command-manifests
        poo-flow-user-workflow-cicd-runtime-command-manifest-map-manifests
        poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection/add-manifests
        poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection/add-maps
        poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection
        poo-flow-user-workflow-cicd-runtime-command-manifest-summaries
        +poo-flow-user-workflow-cicd-runtime-owner+
        poo-flow-user-list-all-false?
        poo-flow-user-workflow-cicd-runtime-command-manifest-summaries-for
        poo-flow-user-workflow-cicd-runtime-command-manifest-summary-has-manifest?
        poo-flow-user-workflow-cicd-runtime-command-manifest-extra-summary-diagnostics
        poo-flow-user-workflow-cicd-summary-count-diagnostics
        poo-flow-user-workflow-cicd-mismatch-diagnostics
        poo-flow-user-workflow-cicd-runtime-command-agreement-diagnostics
        poo-flow-user-workflow-cicd-runtime-command-durable-agreement-diagnostics
        poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-row
        poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-rows
        poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-row-diagnostics
        poo-flow-user-workflow-cicd-runtime-command-manifest-agreement/from-manifests
        poo-flow-user-workflow-cicd-runtime-command-manifest-agreement
        poo-flow-user-config-workflow-cicd-runtime-command-manifest-agreement
        poo-flow-user-alist-ref)

(def (poo-flow-user-cicd-payload? payload)
  (and (pair? payload)
       (eq? (car payload) '+cicd)))

(def (poo-flow-user-cicd-payload-section payload section)
  (let (entry (assoc section (cdr payload)))
    (if entry (cdr entry) '())))

(def (poo-flow-user-module-selection-cicd-intent selection)
  (let ((payload
         (poo-flow-user-module-selection-flag-entry selection '+cicd)))
    (if (and (equal? (poo-flow-user-module-selection-key selection)
                     '(flow . funflow))
             (poo-flow-user-cicd-payload? payload))
      (list (cons 'key (poo-flow-user-module-selection-key selection))
            (cons 'feature '+cicd)
            (cons 'checks
                  (poo-flow-user-cicd-payload-section payload 'checks))
            (cons 'artifacts
                  (poo-flow-user-cicd-payload-section payload 'artifacts))
            (cons 'release
                  (poo-flow-user-cicd-payload-section payload 'release))
            (cons 'webhook
                  (poo-flow-user-cicd-payload-section payload 'webhook))
            (cons 'runtime
                  (poo-flow-user-cicd-payload-section payload 'runtime))
            (cons 'runtime-handoff 'runtime-command-manifest)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'descriptor-realized? #f)
            (cons 'runtime-executed #f))
      #f)))

(def (poo-flow-user-config-cicd-intents/add selected-modules)
  (cond
   ((null? selected-modules) '())
   ((poo-flow-user-module-selection-cicd-intent (car selected-modules))
    => (lambda (intent)
         (cons intent
               (poo-flow-user-config-cicd-intents/add
                (cdr selected-modules)))))
   (else
    (poo-flow-user-config-cicd-intents/add (cdr selected-modules)))))

(def (poo-flow-user-config-cicd-intents config)
  (poo-flow-user-config-cicd-intents/add
   (poo-flow-user-config-modules config)))

(def (poo-flow-user-module-selection-workflow-cicd-check-map selection)
  (let (entry
        (poo-flow-user-module-selection-flag-entry selection ':workflow-pipeline))
    (if (and entry
             (pair? entry)
             (poo-flow-cicd-check-map? (cdr entry)))
      (cdr entry)
      #f)))

(def (poo-flow-user-config-workflow-cicd-check-maps/add selected-modules)
  (cond
   ((null? selected-modules) '())
   ((poo-flow-user-module-selection-workflow-cicd-check-map
     (car selected-modules))
    => (lambda (check-map)
         (cons check-map
               (poo-flow-user-config-workflow-cicd-check-maps/add
                (cdr selected-modules)))))
   (else
    (poo-flow-user-config-workflow-cicd-check-maps/add
     (cdr selected-modules)))))

(def (poo-flow-user-config-workflow-cicd-check-maps config)
  (poo-flow-user-config-workflow-cicd-check-maps/add
   (poo-flow-user-config-modules config)))

(def (poo-flow-user-workflow-cicd-functional-dags check-maps)
  (map poo-flow-funflow-check-map->functional-dag check-maps))

(def (poo-flow-user-workflow-cicd-functional-dag-rows check-maps)
  (map poo-flow-funflow-functional-dag->alist
       (poo-flow-user-workflow-cicd-functional-dags check-maps)))

(def (poo-flow-user-config-workflow-cicd-functional-dag-rows config)
  (poo-flow-user-workflow-cicd-functional-dag-rows
   (poo-flow-user-config-workflow-cicd-check-maps config)))

(def (poo-flow-user-workflow-cicd-runtime-readiness/add check-maps
                                                        profile-catalog)
  (cond
   ((null? check-maps) '())
   (else
    (cons
     (poo-flow-cicd-check-map->runtime-manifest-readiness
      (car check-maps)
      profile-catalog)
     (poo-flow-user-workflow-cicd-runtime-readiness/add
      (cdr check-maps)
      profile-catalog)))))

(def (poo-flow-user-config-workflow-cicd-runtime-readiness config)
  (let* ((selected-modules (poo-flow-user-config-modules config))
         (profile-catalog
          (poo-flow-user-config-sandbox-profile-catalog selected-modules)))
    (poo-flow-user-workflow-cicd-runtime-readiness/add
     (poo-flow-user-config-workflow-cicd-check-maps config)
     profile-catalog)))

(def (poo-flow-user-workflow-cicd-runtime-command-manifests/add
      check-maps
      profile-catalog)
  (cond
   ((null? check-maps) '())
   (else
    (cons
     (poo-flow-cicd-check-map->runtime-command-manifests
      (car check-maps)
      profile-catalog)
     (poo-flow-user-workflow-cicd-runtime-command-manifests/add
      (cdr check-maps)
      profile-catalog)))))

(def (poo-flow-user-config-workflow-cicd-runtime-command-manifests config)
  (let* ((selected-modules (poo-flow-user-config-modules config))
         (profile-catalog
          (poo-flow-user-config-sandbox-profile-catalog selected-modules)))
    (poo-flow-user-workflow-cicd-runtime-command-manifests/add
     (poo-flow-user-config-workflow-cicd-check-maps config)
     profile-catalog)))

(def (poo-flow-user-alist-ref entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

(def (poo-flow-user-workflow-cicd-runtime-command-manifest-map-manifests
      manifest-maps)
  (poo-flow-user-alist-ref
   (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection
    manifest-maps)
   'manifests
   '()))

;;; Runtime command manifest summaries are bounded receipt projections. They
;;; preserve the keys used by agreement matching without retaining the complete
;;; manifest graph in every summary row.
;; : (-> Alist Alist)
(def (poo-flow-user-workflow-cicd-runtime-command-manifest-summary manifest)
  (let* ((request (poo-flow-user-alist-ref manifest 'request '()))
         (policy (poo-flow-user-alist-ref manifest 'policy '()))
         (metadata (poo-flow-user-alist-ref manifest 'metadata '()))
         (unresolved (poo-flow-user-alist-ref
                      request
                      'sandbox-unresolved-profile-refs
                      '())))
    (list
     (cons 'kind 'workflow-cicd-runtime-command-manifest-summary)
     (cons 'request-id (poo-flow-user-alist-ref manifest 'request-id #f))
     (cons 'check (poo-flow-user-alist-ref request 'check #f))
     (cons 'dependency-refs
           (poo-flow-user-alist-ref
            request
            'dependency-refs
            (poo-flow-user-alist-ref policy 'dependency-refs '())))
     (cons 'status
           (poo-flow-user-alist-ref manifest
                                    'status
                                    (if (null? unresolved) 'ready 'blocked)))
     (cons 'argv (poo-flow-user-alist-ref manifest 'argv '()))
     (cons 'runtime-owner
           (poo-flow-user-alist-ref manifest
                                    'runtime-owner
                                    +poo-flow-user-workflow-cicd-runtime-owner+))
     (cons 'runtime-executed
           (poo-flow-user-alist-ref
            metadata
            'runtime-executed
            (poo-flow-user-alist-ref request 'runtime-executed #f)))
     (cons 'handoff-ready
           (poo-flow-user-alist-ref
            manifest
            'handoff-ready
            (and (poo-flow-user-alist-ref
                  request
                  'handoff-required
                  (poo-flow-user-alist-ref policy 'handoff-required #f))
                 (null? unresolved)
                 (eq? (poo-flow-user-alist-ref
                       manifest
                       'status
                       (if (null? unresolved) 'ready 'blocked))
                      'ready))))
     (cons 'sandbox-profile-ref
           (poo-flow-user-alist-ref manifest 'sandbox-profile-ref #f))
     (cons 'sandbox-unresolved-profile-refs unresolved)
     (cons 'durable-task-id
           (poo-flow-user-alist-ref request 'durable-task-id #f))
     (cons 'action-class
           (poo-flow-user-alist-ref request 'action-class #f))
     (cons 'artifact-refs
           (poo-flow-user-alist-ref request 'artifact-refs '()))
     (cons 'artifact-provenance
           (poo-flow-user-alist-ref policy 'artifact-provenance '()))
     (cons 'artifact-retention
           (poo-flow-user-alist-ref request 'artifact-retention #f))
     (cons 'sandbox-refs
           (poo-flow-user-alist-ref request 'sandbox-refs '()))
     (cons 'checkpoint-ref
           (poo-flow-user-alist-ref request 'checkpoint-ref #f))
     (cons 'compensation-refs
           (poo-flow-user-alist-ref request 'compensation-refs '())))))

;;; Projection uses reverse accumulators to traverse manifest maps once, then
;;; restores declaration order only at the public summary boundary.
(def (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection/add-manifests
      manifests
      manifests-rev
      summaries-rev)
  (cond
   ((null? manifests)
    (values manifests-rev summaries-rev))
   (else
    (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection/add-manifests
     (cdr manifests)
     (cons (car manifests) manifests-rev)
     (cons
      (poo-flow-user-workflow-cicd-runtime-command-manifest-summary
       (car manifests))
      summaries-rev)))))

;;; Map traversal threads both reverse accumulators through each manifest list,
;;; avoiding append chains and ensuring every manifest is summarized once.
(def (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection/add-maps
      manifest-maps
      manifests-rev
      summaries-rev)
  (cond
   ((null? manifest-maps)
    (values manifests-rev summaries-rev))
   (else
    (let-values (((manifests-rev summaries-rev)
                  (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection/add-manifests
                   (poo-flow-user-alist-ref
                    (car manifest-maps)
                    'manifests
                    '())
                   manifests-rev
                   summaries-rev)))
      (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection/add-maps
       (cdr manifest-maps)
       manifests-rev
       summaries-rev)))))

(def (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection
      manifest-maps)
  (let-values (((manifests-rev summaries-rev)
                (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection/add-maps
                 manifest-maps
                 '()
                 '())))
    (list
     (cons 'manifests (reverse manifests-rev))
     (cons 'summaries (reverse summaries-rev)))))

(def (poo-flow-user-workflow-cicd-runtime-command-manifest-summaries
      manifest-maps)
  (poo-flow-user-alist-ref
   (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-projection
    manifest-maps)
   'summaries
   '()))

(def +poo-flow-user-workflow-cicd-runtime-owner+ "marlin-agent-core")

(def (poo-flow-user-list-all-false? values)
  (cond
   ((null? values) #t)
   ((equal? (car values) #f)
    (poo-flow-user-list-all-false? (cdr values)))
   (else #f)))

(def (poo-flow-user-workflow-cicd-runtime-command-manifest-summaries-for
      summaries
      request-id
      check-name)
  (cond
   ((null? summaries) '())
   ((and (equal? (poo-flow-user-alist-ref (car summaries)
                                          'request-id
                                          #f)
                 request-id)
         (equal? (poo-flow-user-alist-ref (car summaries) 'check #f)
                 check-name))
    (cons
     (car summaries)
     (poo-flow-user-workflow-cicd-runtime-command-manifest-summaries-for
      (cdr summaries)
      request-id
      check-name)))
   (else
    (poo-flow-user-workflow-cicd-runtime-command-manifest-summaries-for
     (cdr summaries)
     request-id
     check-name))))

(def (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-has-manifest?
      manifests
      summary)
  (cond
   ((null? manifests) #f)
   (else
    (let* ((manifest (car manifests))
           (request (poo-flow-user-alist-ref manifest 'request '()))
           (request-id (poo-flow-user-alist-ref manifest 'request-id #f))
           (check-name (poo-flow-user-alist-ref request 'check #f)))
      (if (and (equal? (poo-flow-user-alist-ref summary 'request-id #f)
                       request-id)
               (equal? (poo-flow-user-alist-ref summary 'check #f)
                       check-name))
        #t
        (poo-flow-user-workflow-cicd-runtime-command-manifest-summary-has-manifest?
         (cdr manifests)
         summary))))))

(def (poo-flow-user-workflow-cicd-runtime-command-manifest-extra-summary-diagnostics
      manifests
      summaries)
  (cond
   ((null? summaries) '())
   ((poo-flow-user-workflow-cicd-runtime-command-manifest-summary-has-manifest?
     manifests
     (car summaries))
    (poo-flow-user-workflow-cicd-runtime-command-manifest-extra-summary-diagnostics
     manifests
     (cdr summaries)))
   (else
    (cons
     'extra-summary
     (poo-flow-user-workflow-cicd-runtime-command-manifest-extra-summary-diagnostics
      manifests
      (cdr summaries))))))

(def (poo-flow-user-workflow-cicd-summary-count-diagnostics summary-count)
  (cond
   ((= summary-count 1) '())
   ((= summary-count 0) '(missing-summary))
   (else '(duplicate-summary))))

(def (poo-flow-user-workflow-cicd-mismatch-diagnostics summary-present?
                                                              match?
                                                              code)
  (if (or (not summary-present?) match?)
    '()
    (list code)))

(def (poo-flow-user-workflow-cicd-runtime-command-agreement-diagnostics
      summary-count
      summary-present?
      check-match?
      argv-match?
      runtime-owner-match?
      unresolved-profile-refs-match?
      runtime-executed-match?)
  (append
   (poo-flow-user-workflow-cicd-summary-count-diagnostics summary-count)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? check-match? 'check-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? argv-match? 'argv-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? runtime-owner-match? 'runtime-owner-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present?
    unresolved-profile-refs-match?
    'unresolved-profile-refs-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? runtime-executed-match? 'runtime-executed-mismatch)))

(def (poo-flow-user-workflow-cicd-runtime-command-durable-agreement-diagnostics
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
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? durable-task-id-match? 'durable-task-id-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? action-class-match? 'action-class-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? artifact-refs-match? 'artifact-refs-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? artifact-provenance-match? 'artifact-provenance-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? artifact-retention-match? 'artifact-retention-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? sandbox-refs-match? 'sandbox-refs-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? checkpoint-ref-match? 'checkpoint-ref-mismatch)
   (poo-flow-user-workflow-cicd-mismatch-diagnostics
    summary-present? compensation-refs-match? 'compensation-refs-mismatch)))

;;; Agreement rows compare one manifest with its bounded receipt summary. Keep
;;; matching here so diagnostics remain declarative and runtime execution stays
;;; outside the Scheme control plane.
(def (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-row
      manifest
      summary
      summary-count)
  (let* ((summary-row (or summary '()))
         (request (poo-flow-user-alist-ref manifest 'request '()))
         (policy (poo-flow-user-alist-ref manifest 'policy '()))
         (metadata (poo-flow-user-alist-ref manifest 'metadata '()))
         (request-id (poo-flow-user-alist-ref manifest 'request-id #f))
         (check-name (poo-flow-user-alist-ref request 'check #f))
         (manifest-argv (poo-flow-user-alist-ref manifest 'argv '()))
         (request-durable-task-id
          (poo-flow-user-alist-ref request 'durable-task-id #f))
         (request-action-class
          (poo-flow-user-alist-ref request 'action-class #f))
         (request-artifact-refs
          (poo-flow-user-alist-ref request 'artifact-refs '()))
         (request-artifact-retention
          (poo-flow-user-alist-ref request 'artifact-retention #f))
         (request-sandbox-refs
          (poo-flow-user-alist-ref request 'sandbox-refs '()))
         (request-checkpoint-ref
          (poo-flow-user-alist-ref request 'checkpoint-ref #f))
         (request-compensation-refs
          (poo-flow-user-alist-ref request 'compensation-refs '()))
         (policy-durable-task-id
          (poo-flow-user-alist-ref policy 'durable-task-id #f))
         (policy-action-class
          (poo-flow-user-alist-ref policy 'action-class #f))
         (policy-artifact-refs
          (poo-flow-user-alist-ref policy 'artifact-refs '()))
         (policy-artifact-provenance
          (poo-flow-user-alist-ref policy 'artifact-provenance '()))
         (policy-artifact-retention
          (poo-flow-user-alist-ref policy 'artifact-retention #f))
         (policy-sandbox-refs
          (poo-flow-user-alist-ref policy 'sandbox-refs '()))
         (policy-checkpoint-ref
          (poo-flow-user-alist-ref policy 'checkpoint-ref #f))
         (policy-compensation-refs
          (poo-flow-user-alist-ref policy 'compensation-refs '()))
         (request-unresolved
          (poo-flow-user-alist-ref request
                                   'sandbox-unresolved-profile-refs
                                   '()))
         (runtime-executed-values
          (list (poo-flow-user-alist-ref request 'runtime-executed #f)
                (poo-flow-user-alist-ref policy 'runtime-executed #f)
                (poo-flow-user-alist-ref metadata 'runtime-executed #f)))
         (summary-present? (= summary-count 1))
         (check-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row 'request-id #f)
                       request-id)
               (equal? (poo-flow-user-alist-ref summary-row 'check #f)
                       check-name)
               (equal? (poo-flow-user-alist-ref manifest 'name #f)
                       check-name)))
         (argv-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row 'argv '())
                       manifest-argv)))
         (runtime-owner-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row
                                                'runtime-owner
                                                #f)
                       +poo-flow-user-workflow-cicd-runtime-owner+)))
         (unresolved-profile-refs-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref
                        summary-row
                        'sandbox-unresolved-profile-refs
                        '())
                       request-unresolved)))
         (runtime-executed-match?
          (and summary-present?
               (poo-flow-user-list-all-false? runtime-executed-values)
               (equal? (poo-flow-user-alist-ref summary-row
                                                'runtime-executed
                                                #t)
                       #f)))
         (durable-task-id-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row
                                                'durable-task-id
                                                #f)
                       request-durable-task-id)
               (equal? request-durable-task-id policy-durable-task-id)))
         (action-class-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row
                                                'action-class
                                                #f)
                       request-action-class)
               (equal? request-action-class policy-action-class)))
         (artifact-refs-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row
                                                'artifact-refs
                                                '())
                       request-artifact-refs)
               (equal? request-artifact-refs policy-artifact-refs)))
         (artifact-provenance-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row
                                                'artifact-provenance
                                                '())
                       policy-artifact-provenance)))
         (artifact-retention-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row
                                                'artifact-retention
                                                #f)
                       request-artifact-retention)
               (equal? request-artifact-retention policy-artifact-retention)))
         (sandbox-refs-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row
                                                'sandbox-refs
                                                '())
                       request-sandbox-refs)
               (equal? request-sandbox-refs policy-sandbox-refs)))
         (checkpoint-ref-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row
                                                'checkpoint-ref
                                                #f)
                       request-checkpoint-ref)
               (equal? request-checkpoint-ref policy-checkpoint-ref)))
         (compensation-refs-match?
          (and summary-present?
               (equal? (poo-flow-user-alist-ref summary-row
                                                'compensation-refs
                                                '())
                       request-compensation-refs)
               (equal? request-compensation-refs policy-compensation-refs)))
         (diagnostics
          (append
           (poo-flow-user-workflow-cicd-runtime-command-agreement-diagnostics
            summary-count
            summary-present?
            check-match?
            argv-match?
            runtime-owner-match?
            unresolved-profile-refs-match?
            runtime-executed-match?)
           (poo-flow-user-workflow-cicd-runtime-command-durable-agreement-diagnostics
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
           (poo-flow-user-alist-ref summary-row 'durable-task-id #f))
     (cons 'action-class
           (poo-flow-user-alist-ref summary-row 'action-class #f))
     (cons 'artifact-refs
           (poo-flow-user-alist-ref summary-row 'artifact-refs '()))
     (cons 'artifact-retention
           (poo-flow-user-alist-ref summary-row 'artifact-retention #f))
     (cons 'sandbox-refs
           (poo-flow-user-alist-ref summary-row 'sandbox-refs '()))
     (cons 'checkpoint-ref
           (poo-flow-user-alist-ref summary-row 'checkpoint-ref #f))
     (cons 'compensation-refs
           (poo-flow-user-alist-ref summary-row 'compensation-refs '()))
     (cons 'runtime-owner
           (poo-flow-user-alist-ref summary-row 'runtime-owner #f))
     (cons 'runtime-executed
           (poo-flow-user-alist-ref summary-row 'runtime-executed #f))
     (cons 'diagnostics diagnostics)
     (cons 'valid? (null? diagnostics)))))

(def (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-rows
      manifests
      summaries)
  (cond
   ((null? manifests) '())
   (else
    (let* ((manifest (car manifests))
           (request (poo-flow-user-alist-ref manifest 'request '()))
           (request-id (poo-flow-user-alist-ref manifest 'request-id #f))
           (check-name (poo-flow-user-alist-ref request 'check #f))
           (matching-summaries
            (poo-flow-user-workflow-cicd-runtime-command-manifest-summaries-for
             summaries
             request-id
             check-name)))
      (cons
       (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-row
        manifest
        (if (null? matching-summaries) #f (car matching-summaries))
        (length matching-summaries))
       (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-rows
        (cdr manifests)
        summaries))))))

(def (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-row-diagnostics
      rows)
  (cond
   ((null? rows) '())
   (else
    (append
     (poo-flow-user-alist-ref (car rows) 'diagnostics '())
     (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-row-diagnostics
      (cdr rows))))))

;;; Aggregate agreement preserves cardinality mismatches as data for the
;;; runtime handoff rather than silently selecting or discarding a manifest.
(def (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement/from-manifests
      manifests
      summaries)
  (let* ((rows
          (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-rows
           manifests
           summaries))
         (diagnostics
          (append
           (if (= (length manifests) (length summaries))
             '()
             '(manifest-summary-count-mismatch))
           (poo-flow-user-workflow-cicd-runtime-command-manifest-extra-summary-diagnostics
            manifests
            summaries)
           (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement-row-diagnostics
            rows))))
    (list
     (cons 'kind 'workflow-cicd-runtime-command-manifest-agreement)
     (cons 'manifest-count (length manifests))
     (cons 'summary-count (length summaries))
     (cons 'agreement-count (length rows))
     (cons 'valid? (null? diagnostics))
     (cons 'diagnostics diagnostics)
     (cons 'rows rows)
     (cons 'runtime-owner +poo-flow-user-workflow-cicd-runtime-owner+)
     (cons 'runtime-executed #f))))

(def (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement
      manifest-maps
      summaries)
  (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement/from-manifests
   (poo-flow-user-workflow-cicd-runtime-command-manifest-map-manifests
    manifest-maps)
   summaries))

(def (poo-flow-user-config-workflow-cicd-runtime-command-manifest-agreement
      config)
  (let* ((manifest-maps
          (poo-flow-user-config-workflow-cicd-runtime-command-manifests
           config))
         (summaries
          (poo-flow-user-workflow-cicd-runtime-command-manifest-summaries
           manifest-maps)))
    (poo-flow-user-workflow-cicd-runtime-command-manifest-agreement
     manifest-maps
     summaries)))
