;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: workflow CI/CD user-module projection for the module system.
;;; Invariant: this owner emits POO control-plane data and never executes checks.

(import (only-in :clan/poo/object .ref object<-fun)
        :yuanxu/module-system/selection/objects
        :yuanxu/utilities/runtime-receipt-syntax
        (only-in :agentic-ai-lab/modules/workflow/cicd-runtime-command-config
                 agentic-ai-lab-user-alist-ref)
        :agentic-ai-lab/modules/sandbox-core/profile-catalog
        (only-in :yuanxu/modules/funflow/graph-projection
                 yuanxu-funflow-check-map->functional-dag
                 yuanxu-funflow-functional-dag->alist)
        (only-in :yuanxu/modules/funflow/check-objects
                 yuanxu-cicd-check-map?
                 yuanxu-cicd-check-map-name)
        (only-in :agentic-ai-lab/modules/workflow/funs
                 agentic-ai-lab-cicd-check-map->receipts
                 agentic-ai-lab-cicd-check-map->runtime-manifest-readiness
                 agentic-ai-lab-cicd-check-map->runtime-command-manifests
                 agentic-ai-lab-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi))

(export agentic-ai-lab-user-cicd-payload?
        agentic-ai-lab-user-cicd-payload-section
        agentic-ai-lab-user-module-selection-cicd-intent
        agentic-ai-lab-user-config-cicd-intents
        agentic-ai-lab-user-module-selection-workflow-cicd-check-map
        agentic-ai-lab-user-config-workflow-cicd-check-maps
        agentic-ai-lab-user-workflow-cicd-functional-dags
        agentic-ai-lab-user-workflow-cicd-functional-dag-rows
        agentic-ai-lab-user-config-workflow-cicd-functional-dag-rows
        agentic-ai-lab-user-config-workflow-cicd-runtime-readiness
        agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifests
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-map-manifests
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries
        agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement
        agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifest-agreement
        agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abis
        agentic-ai-lab-user-config-workflow-cicd-marlin-runtime-handoff-abis
        agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abi-summary
        agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abi-summaries
        agentic-ai-lab-user-workflow-cicd-marlin-handoff-receipt-bundle
        agentic-ai-lab-user-config-workflow-cicd-marlin-handoff-receipt-bundle
        agentic-ai-lab-user-config-workflow-cicd-receipts
        agentic-ai-lab-user-config-workflow-cicd-runtime-projection-object
        agentic-ai-lab-user-config-workflow-cicd-runtime-projection
        agentic-ai-lab-user-alist-ref
        agentic-ai-lab-user-workflow-cicd-readiness-checks
        agentic-ai-lab-user-workflow-cicd-checks-field-values)


;;; CI/CD payload predicates recognize the nested flag shape emitted by init.ss.
;;; They avoid descriptor lookup so user tools can inspect declared intent first.
;; : (-> UserCicdPayloadCandidate Boolean)
(import :agentic-ai-lab/modules/workflow/cicd-runtime-command-config)

;;; Payload section reads are deliberately lossy: missing sections become empty
;;; lists, which keeps partial user declarations presentable before validation.
;; : (-> UserCicdPayload Symbol [Symbol])
;;; CI/CD intent facts are user-interface presentation data. They describe the
;;; Funflow vocabulary selected by init.ss and never imply adapter execution.
;; : (-> PooUserModuleSelection MaybeAlist)
;;; CI/CD intent accumulation is a report-only filter over selected modules. It
;;; preserves init.ss declaration order and never asks the resolver for descriptors.
;; : (-> [PooUserModuleSelection] [Alist])
;;; Config-level CI/CD intents are the stable downstream presentation surface
;;; for the Bass-inspired Funflow CI/CD payload.
;; : (-> PooUserConfig [Alist])
;;; Workflow CI/CD check-maps are the typed pipeline objects attached by the
;;; Funflow module. Presentation consumes them, but still performs no runtime
;;; descriptor realization or provider execution.
;; : (-> PooUserModuleSelection MaybeYuanxuCicdCheckMap)
;;; Check-map accumulation filters selected modules without losing declaration
;;; order. Invalid or absent CI/CD maps are skipped so presentation can stay
;;; inspectable before runtime validation.
;; : (-> [PooUserModuleSelection] [YuanxuCicdCheckMap])
;;; Config-level check-map discovery keeps the user interface on the declared
;;; POO object graph: sandbox profile resolution happens against selected
;;; module config plus standard defaults, not by probing the filesystem.
;; : (-> PooUserConfig [YuanxuCicdCheckMap])
;;; Functional DAG discovery stays in the Funflow owner. This layer only
;;; projects check-map values into POO DAG objects and final presentation rows.
;; : (-> [YuanxuCicdCheckMap] [YuanxuFunflowFunctionalDag])
;; : (-> [YuanxuCicdCheckMap] [Alist])
;; : (-> PooUserConfig [Alist])
;;; Boundary: user workflow cicd runtime readiness add is the policy-visible
;;; edge for module-system, workflow behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> [YuanxuCicdCheckMap] [PooSandboxProfile] [Alist])
;; : (-> PooUserConfig [Alist])
;;; Boundary: user workflow cicd runtime command manifests add is the policy-
;;; visible edge for module-system, workflow behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> [YuanxuCicdCheckMap] [PooSandboxProfile] [Alist])
;;; Runtime command manifests use the same configured profile catalog as
;;; readiness, so user/project overrides are visible before Marlin consumes the
;;; handoff data.
;; : (-> PooUserConfig [Alist])
;;; Manifest maps stay grouped by pipeline in the full presentation; summaries
;;; flatten them only for audit rows, preserving the full map as source data.
;; : (-> [Alist] [Alist])
;;; Compact summaries are the agent-facing audit rows for runtime handoff. The
;;; full manifest remains available, but presentation code and docs can inspect
;;; these rows without traversing nested sandbox summaries.
;; : (-> Alist Alist)
(defpoo-runtime-receipt-projection
  agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary
  (manifest)
  (bindings
   ((request (agentic-ai-lab-user-alist-ref manifest 'request '()))
    (policy (agentic-ai-lab-user-alist-ref manifest 'policy '()))
    (unresolved
     (agentic-ai-lab-user-alist-ref request
                              'sandbox-unresolved-profile-refs
                              '()))
    (handoff-ready (null? unresolved))))
  (fields
   (('kind 'workflow-cicd-runtime-command-manifest-summary)
    ('operation
     (agentic-ai-lab-user-alist-ref manifest 'operation #f))
    ('request-id
     (agentic-ai-lab-user-alist-ref manifest 'request-id #f))
    ('artifact-handle
     (agentic-ai-lab-user-alist-ref manifest 'artifact-handle #f))
    ('argv
     (agentic-ai-lab-user-alist-ref manifest 'argv '()))
    ('check
     (agentic-ai-lab-user-alist-ref request 'check #f))
    ('profile
     (agentic-ai-lab-user-alist-ref request 'profile #f))
    ('profile-refs
     (agentic-ai-lab-user-alist-ref request 'profile-refs '()))
    ('dependency-refs
     (agentic-ai-lab-user-alist-ref request 'dependency-refs '()))
    ('durable-task-id
     (agentic-ai-lab-user-alist-ref request 'durable-task-id #f))
    ('action-class
     (agentic-ai-lab-user-alist-ref request 'action-class #f))
    ('artifact-refs
     (agentic-ai-lab-user-alist-ref request 'artifact-refs '()))
    ('artifact-provenance
     (agentic-ai-lab-user-alist-ref
      policy
      'artifact-provenance
      '()))
    ('artifact-retention
     (agentic-ai-lab-user-alist-ref request 'artifact-retention #f))
    ('sandbox-refs
     (agentic-ai-lab-user-alist-ref request 'sandbox-refs '()))
    ('checkpoint-ref
     (agentic-ai-lab-user-alist-ref request 'checkpoint-ref #f))
    ('compensation-refs
     (agentic-ai-lab-user-alist-ref request 'compensation-refs '()))
    ('runtime
     (agentic-ai-lab-user-alist-ref request 'runtime #f))
    ('runtime-owner "marlin-agent-core")
    ('sandbox-unresolved-profile-refs unresolved)
    ('status (if handoff-ready 'ready 'blocked))
    ('handoff-ready handoff-ready)
    ('handoff-required
     (agentic-ai-lab-user-alist-ref policy 'handoff-required #t))
    ('runtime-executed
     (agentic-ai-lab-user-alist-ref request 'runtime-executed #f)))))

;;; Marlin ABI projections reuse the already validated manifest maps. The user
;;; interface sees a stable handoff payload without learning workflow object
;;; internals or executing any runtime adapter.
;; : (-> [Alist] [Alist] [Alist])
(def (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abis/rev
      manifest-maps
      abis-rev)
  (cond
   ((null? manifest-maps) abis-rev)
   (else
    (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abis/rev
     (cdr manifest-maps)
     (cons
      (agentic-ai-lab-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
       (car manifest-maps))
      abis-rev)))))

;; : (-> [Alist] [Alist])
(def (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abis manifest-maps)
  (reverse
   (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abis/rev
    manifest-maps
    '())))

;; : (-> PooUserConfig [Alist])
(def (agentic-ai-lab-user-config-workflow-cicd-marlin-runtime-handoff-abis config)
  (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abis
   (agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifests config)))

;;; ABI summaries are the receipt-sized view used by user-interface tests and
;;; handoff diagnostics; they keep the full per-check entries available only in
;;; the ABI payload.
;; : (-> MarlinRuntimeHandoffAbi MarlinRuntimeHandoffAbiSummary)
(defpoo-runtime-receipt-projection
  agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abi-summary
  (abi)
  (bindings
   ((entries (agentic-ai-lab-user-alist-ref abi 'entries '()))))
  (fields
   (('kind 'workflow-cicd-marlin-runtime-handoff-abi-summary)
    ('schema (agentic-ai-lab-user-alist-ref abi 'schema #f))
    ('check-map (agentic-ai-lab-user-alist-ref abi 'check-map #f))
    ('runtime-owner
     (agentic-ai-lab-user-alist-ref abi 'runtime-owner
                              +agentic-ai-lab-user-workflow-cicd-runtime-owner+))
    ('manifest-count
     (agentic-ai-lab-user-alist-ref abi 'manifest-count (length entries)))
    ('entry-count (length entries))
    ('required-fields
     (agentic-ai-lab-user-alist-ref abi 'required-fields '()))
    ('handoff-required
     (agentic-ai-lab-user-alist-ref abi 'handoff-required #t))
    ('runtime-executed
     (agentic-ai-lab-user-alist-ref abi 'runtime-executed #f))
    ('runtime-parses-scheme-source
     (agentic-ai-lab-user-alist-ref abi 'runtime-parses-scheme-source #f))
    ('scheme-manufactures-runtime-handlers
     (agentic-ai-lab-user-alist-ref
      abi
      'scheme-manufactures-runtime-handlers
      #f)))))

;; : (-> [MarlinRuntimeHandoffAbi] [MarlinRuntimeHandoffAbiSummary])
(def (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abi-summaries/rev
      abi-rows
      summaries-rev)
  (cond
   ((null? abi-rows) summaries-rev)
   (else
    (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abi-summaries/rev
     (cdr abi-rows)
     (cons
      (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abi-summary
       (car abi-rows))
      summaries-rev)))))

;; : (-> [MarlinRuntimeHandoffAbi] [MarlinRuntimeHandoffAbiSummary])
(def (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abi-summaries
      abi-rows)
  (reverse
   (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abi-summaries/rev
    abi-rows
    '())))

;; : (-> [MarlinRuntimeHandoffAbiSummary] Integer)
(def (agentic-ai-lab-user-workflow-cicd-marlin-handoff-entry-count summaries)
  (cond
   ((null? summaries) 0)
   (else
    (+ (agentic-ai-lab-user-alist-ref (car summaries) 'entry-count 0)
       (agentic-ai-lab-user-workflow-cicd-marlin-handoff-entry-count
        (cdr summaries))))))

;;; The handoff receipt bundle is the user-interface receipt-sized envelope for
;;; Marlin handoff. It keeps the full ABI payload available while giving agents
;;; one stable object to inspect for agreement, proof gate, and non-execution
;;; evidence.
;; : (-> [Alist] [Alist] Alist [Alist] [Alist] [Alist] Alist)
(defpoo-runtime-receipt-projection
  agentic-ai-lab-user-workflow-cicd-marlin-handoff-receipt-bundle
  (manifest-maps
   manifest-summaries
   manifest-agreement
   handoff-abis
   handoff-summaries
   receipts)
  (bindings
   ((handoff-entry-count
     (agentic-ai-lab-user-workflow-cicd-marlin-handoff-entry-count
      handoff-summaries))))
  (fields
   (('schema
     'agentic-ai-lab.modules.workflow-cicd.marlin-handoff-receipt-bundle.v1)
    ('kind 'workflow-cicd-marlin-handoff-receipt-bundle)
    ('source 'agentic-ai-lab-user-config-presentation)
    ('alignment-gate-id
     'stage-23-user-interface-marlin-handoff-projection)
    ('proof-command
     "gxtest t/user-interface-cicd-test.ss: projects user config into Marlin runtime handoff ABI")
    ('presentation-fields
     '(workflow-cicd-runtime-command-manifests
       workflow-cicd-runtime-command-manifest-summaries
       workflow-cicd-runtime-command-manifest-agreement
       workflow-cicd-marlin-runtime-handoff-abis
       workflow-cicd-marlin-runtime-handoff-summaries
       workflow-cicd-receipts))
    ('runtime-owner +agentic-ai-lab-user-workflow-cicd-runtime-owner+)
    ('handoff-required (> (length handoff-abis) 0))
    ('runtime-executed #f)
    ('runtime-parses-scheme-source #f)
    ('scheme-manufactures-runtime-handlers #f)
    ('manifest-map-count (length manifest-maps))
    ('manifest-summary-count (length manifest-summaries))
    ('manifest-agreement-valid?
     (agentic-ai-lab-user-alist-ref manifest-agreement 'valid? #f))
    ('manifest-agreement-diagnostics
     (agentic-ai-lab-user-alist-ref manifest-agreement 'diagnostics '()))
    ('marlin-runtime-handoff-abi-count (length handoff-abis))
    ('marlin-runtime-handoff-summary-count (length handoff-summaries))
    ('receipt-count (length receipts))
    ('manifest-agreement-schema
     (agentic-ai-lab-user-alist-ref manifest-agreement 'schema #f))
    ('manifest-agreement-row-count
     (length (agentic-ai-lab-user-alist-ref manifest-agreement 'rows '())))
    ('marlin-runtime-handoff-entry-count handoff-entry-count))))

;;; Config-level bundle construction reuses the same projection path as the
;;; presentation layer so tests can compare one receipt shape across surfaces.
;; : (-> PooUserConfig Alist)
(def (agentic-ai-lab-user-config-workflow-cicd-marlin-handoff-receipt-bundle
      config)
  (let* ((manifest-maps
          (agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifests
           config))
         (manifest-summaries
          (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries
           manifest-maps))
         (manifest-agreement
          (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement
           manifest-maps
           manifest-summaries))
         (handoff-abis
          (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abis
           manifest-maps))
         (handoff-summaries
          (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abi-summaries
           handoff-abis))
         (receipts
          (agentic-ai-lab-user-config-workflow-cicd-receipts config)))
    (agentic-ai-lab-user-workflow-cicd-marlin-handoff-receipt-bundle
     manifest-maps
     manifest-summaries
     manifest-agreement
     handoff-abis
     handoff-summaries
     receipts)))

;;; Receipt accumulation preserves check-map declaration order while flattening
;;; per-check receipts into the presentation contract.
;; : (-> [YuanxuCicdCheckMap] [PooSandboxProfile] [Alist] [Alist])
(def (agentic-ai-lab-user-workflow-cicd-receipts/add/rev check-maps
                                                       profile-catalog
                                                       receipts-rev)
  (cond
   ((null? check-maps) receipts-rev)
   (else
    (agentic-ai-lab-user-workflow-cicd-receipts/add/rev
     (cdr check-maps)
     profile-catalog
     (agentic-ai-lab-user-workflow-cicd-reverse-prepend
      (agentic-ai-lab-cicd-check-map->receipts (car check-maps) profile-catalog)
      receipts-rev)))))

;; : (-> [YuanxuCicdCheckMap] [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-user-workflow-cicd-receipts/add check-maps profile-catalog)
  (reverse
   (agentic-ai-lab-user-workflow-cicd-receipts/add/rev
    check-maps
    profile-catalog
    '())))

;;; Config-level receipts resolve sandbox profiles through selected modules,
;;; preserving user overrides before Marlin receives check receipts.
;; : (-> PooUserConfig [Alist])
(def (agentic-ai-lab-user-config-workflow-cicd-receipts config)
  (let* ((selected-modules (yuanxu-user-config-modules config))
         (profile-catalog
          (agentic-ai-lab-user-config-sandbox-profile-catalog selected-modules)))
    (agentic-ai-lab-user-workflow-cicd-receipts/add
     (agentic-ai-lab-user-config-workflow-cicd-check-maps config)
     profile-catalog)))

;; agentic-ai-lab-user-workflow-cicd-check-map-names
;;   : (forall (k v) (-> [(Pair k v)] [k]))
;;   | contract: Project declared CI/CD check identities without resolving them.
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-user-workflow-cicd-check-map-names check-maps)
;;       ;; => '(build test)
;;       ```
;;     %
;; : (-> [YuanxuCicdCheckMap] [Symbol])
(def (agentic-ai-lab-user-workflow-cicd-check-map-names check-maps)
  (cond
   ((null? check-maps) '())
   (else
    (cons (yuanxu-cicd-check-map-name (car check-maps))
          (agentic-ai-lab-user-workflow-cicd-check-map-names
           (cdr check-maps))))))

;;; The runtime projection is POO-native and demand driven. Each field family is
;;; computed at most once, and unrelated readiness/receipt families stay cold.
(def +agentic-ai-lab-user-workflow-cicd-runtime-projection-keys+
  '(check-maps
    pipeline-count
    pipeline-names
    runtime-readiness
    readiness-checks
    sandbox-runtime-summaries
    sandbox-handoff-summaries
    sandbox-unresolved-profile-refs
    runtime-command-manifests
    runtime-command-manifest-summaries
    runtime-command-manifest-agreement
    marlin-runtime-handoff-abis
    marlin-runtime-handoff-summaries
    receipts
    marlin-handoff-receipt-bundle
    runtime-executed))

;; : (-> PooUserConfig POOObject)
(def (agentic-ai-lab-user-config-workflow-cicd-runtime-projection-object config)
  (let* ((selected-modules (yuanxu-user-config-modules config))
         (profile-catalog/promise
          (delay
            (agentic-ai-lab-user-config-sandbox-profile-catalog selected-modules)))
         (check-maps/promise
          (delay (agentic-ai-lab-user-config-workflow-cicd-check-maps config)))
         (readiness-rows/promise
          (delay
            (agentic-ai-lab-user-workflow-cicd-runtime-readiness/add
             (force check-maps/promise)
             (force profile-catalog/promise))))
         (readiness-check-summary/promise
          (delay
            (agentic-ai-lab-user-workflow-cicd-readiness-check-summary
             (force readiness-rows/promise))))
         (manifest-maps/promise
          (delay
            (agentic-ai-lab-user-workflow-cicd-runtime-command-manifests/add
             (force check-maps/promise)
             (force profile-catalog/promise))))
         (manifest-summary-projection/promise
          (delay
            (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summary-projection
             (force manifest-maps/promise))))
         (manifest-summaries/promise
          (delay
            (agentic-ai-lab-user-alist-ref
             (force manifest-summary-projection/promise)
             'summaries
             '())))
         (manifest-agreement/promise
          (delay
            (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement/from-manifests
             (agentic-ai-lab-user-alist-ref
              (force manifest-summary-projection/promise)
              'manifests
              '())
             (force manifest-summaries/promise))))
         (handoff-abis/promise
          (delay
            (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abis
             (force manifest-maps/promise))))
         (handoff-summaries/promise
          (delay
            (agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abi-summaries
             (force handoff-abis/promise))))
         (receipts/promise
          (delay
            (agentic-ai-lab-user-workflow-cicd-receipts/add
             (force check-maps/promise)
             (force profile-catalog/promise))))
         (handoff-bundle/promise
          (delay
            (agentic-ai-lab-user-workflow-cicd-marlin-handoff-receipt-bundle
             (force manifest-maps/promise)
             (force manifest-summaries/promise)
             (force manifest-agreement/promise)
             (force handoff-abis/promise)
             (force handoff-summaries/promise)
             (force receipts/promise)))))
    (object<-fun
     (lambda (key)
       (case key
        ((check-maps) (force check-maps/promise))
        ((pipeline-count) (length (force check-maps/promise)))
        ((pipeline-names)
         (agentic-ai-lab-user-workflow-cicd-check-map-names
          (force check-maps/promise)))
        ((runtime-readiness) (force readiness-rows/promise))
        ((readiness-checks)
         (agentic-ai-lab-user-alist-ref
          (force readiness-check-summary/promise) 'checks '()))
        ((sandbox-runtime-summaries)
         (agentic-ai-lab-user-alist-ref
          (force readiness-check-summary/promise)
          'sandbox-runtime-summaries
          '()))
        ((sandbox-handoff-summaries)
         (agentic-ai-lab-user-alist-ref
          (force readiness-check-summary/promise)
          'sandbox-handoff-summaries
          '()))
        ((sandbox-unresolved-profile-refs)
         (agentic-ai-lab-user-alist-ref
          (force readiness-check-summary/promise)
          'sandbox-unresolved-profile-refs
          '()))
        ((runtime-command-manifests) (force manifest-maps/promise))
        ((runtime-command-manifest-summaries)
         (force manifest-summaries/promise))
        ((runtime-command-manifest-agreement)
         (force manifest-agreement/promise))
        ((marlin-runtime-handoff-abis) (force handoff-abis/promise))
        ((marlin-runtime-handoff-summaries)
         (force handoff-summaries/promise))
        ((receipts) (force receipts/promise))
        ((marlin-handoff-receipt-bundle) (force handoff-bundle/promise))
        ((runtime-executed) #f)
        (else (error "unknown workflow runtime projection slot" key))))
     keys: +agentic-ai-lab-user-workflow-cicd-runtime-projection-keys+)))

;;; Alist materialization remains an explicit outer adapter for existing report
;;; surfaces. New POO consumers use the object projection above.
;; : (-> PooUserConfig Alist)
(def (agentic-ai-lab-user-config-workflow-cicd-runtime-projection config)
  (let (projection
        (agentic-ai-lab-user-config-workflow-cicd-runtime-projection-object config))
    (map (lambda (key) (cons key (.ref projection key)))
         +agentic-ai-lab-user-workflow-cicd-runtime-projection-keys+)))

;;; Shared alist lookup is total by design: presentation and agreement checks
;;; need to report partial payloads instead of failing on the first missing key.
;; : (-> Alist Symbol Value Value)
;; : (-> [WorkflowCicdProjectionValue] [WorkflowCicdProjectionValue] [WorkflowCicdProjectionValue])
(def (agentic-ai-lab-user-workflow-cicd-reverse-prepend values values-rev)
  (cond
   ((null? values) values-rev)
   (else
    (agentic-ai-lab-user-workflow-cicd-reverse-prepend
     (cdr values)
     (cons (car values) values-rev)))))

;; : (-> [Alist] [Alist] [Alist] [Alist] [Alist] Values)
(def (agentic-ai-lab-user-workflow-cicd-readiness-check-summary/add-checks
      checks
      checks-rev
      runtime-summaries-rev
      handoff-summaries-rev
      unresolved-profile-refs-rev)
  (cond
   ((null? checks)
    (values checks-rev
            runtime-summaries-rev
            handoff-summaries-rev
            unresolved-profile-refs-rev))
   (else
    (let (check (car checks))
      (agentic-ai-lab-user-workflow-cicd-readiness-check-summary/add-checks
       (cdr checks)
       (cons check checks-rev)
       (agentic-ai-lab-user-workflow-cicd-reverse-prepend
        (agentic-ai-lab-user-alist-ref check 'sandbox-runtime-summaries '())
        runtime-summaries-rev)
       (agentic-ai-lab-user-workflow-cicd-reverse-prepend
        (agentic-ai-lab-user-alist-ref check 'sandbox-handoff-summaries '())
        handoff-summaries-rev)
       (agentic-ai-lab-user-workflow-cicd-reverse-prepend
        (agentic-ai-lab-user-alist-ref check 'sandbox-unresolved-profile-refs '())
        unresolved-profile-refs-rev))))))

;; : (-> [Alist] [Alist] [Alist] [Alist] [Alist] Values)
(def (agentic-ai-lab-user-workflow-cicd-readiness-check-summary/add
      readiness-rows
      checks-rev
      runtime-summaries-rev
      handoff-summaries-rev
      unresolved-profile-refs-rev)
  (cond
   ((null? readiness-rows)
    (values checks-rev
            runtime-summaries-rev
            handoff-summaries-rev
            unresolved-profile-refs-rev))
   (else
    (let-values (((checks-rev
                   runtime-summaries-rev
                   handoff-summaries-rev
                   unresolved-profile-refs-rev)
                  (agentic-ai-lab-user-workflow-cicd-readiness-check-summary/add-checks
                   (agentic-ai-lab-user-alist-ref
                    (car readiness-rows)
                    'checks
                    '())
                   checks-rev
                   runtime-summaries-rev
                   handoff-summaries-rev
                   unresolved-profile-refs-rev)))
      (agentic-ai-lab-user-workflow-cicd-readiness-check-summary/add
       (cdr readiness-rows)
       checks-rev
       runtime-summaries-rev
       handoff-summaries-rev
       unresolved-profile-refs-rev)))))

;;; Readiness check summary flattens the nested per-pipeline check rows and the
;;; three sandbox presentation columns in one owner-local pass.
;; : (-> [Alist] Alist)
(def (agentic-ai-lab-user-workflow-cicd-readiness-check-summary readiness-rows)
  (let-values (((checks-rev
                 runtime-summaries-rev
                 handoff-summaries-rev
                 unresolved-profile-refs-rev)
                (agentic-ai-lab-user-workflow-cicd-readiness-check-summary/add
                 readiness-rows
                 '()
                 '()
                 '()
                 '())))
    (list
     (cons 'checks (reverse checks-rev))
     (cons 'sandbox-runtime-summaries (reverse runtime-summaries-rev))
     (cons 'sandbox-handoff-summaries (reverse handoff-summaries-rev))
     (cons 'sandbox-unresolved-profile-refs
           (reverse unresolved-profile-refs-rev)))))

;;; Readiness rows are nested by pipeline. This helper exposes the per-check
;;; rows that presentation uses for sandbox summary columns.
;; : (-> [Alist] [Alist])
(def (agentic-ai-lab-user-workflow-cicd-readiness-checks readiness-rows)
  (agentic-ai-lab-user-alist-ref
   (agentic-ai-lab-user-workflow-cicd-readiness-check-summary readiness-rows)
   'checks
   '()))

;;; Field collection keeps repeated sandbox summary fields in declaration
;;; order; empty fields stay absent rather than fabricated.
;; agentic-ai-lab-user-workflow-cicd-checks-field-values
;; : (forall (v) (-> [Alist] Symbol [v]))
;; : (-> [Alist] Symbol [Value])
;; | doc m%
;;   Collect one repeated check field in declaration order without fabricating
;;   values for checks where the field is absent.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-user-workflow-cicd-checks-field-values
;;    '(((name . build) (tags . (fast))) ((name . test) (tags . (unit))))
;;    'tags)
;;   ;; => (fast unit)
;;   ```
(def (agentic-ai-lab-user-workflow-cicd-checks-field-values checks field)
  (foldr
   (lambda (check values)
     (foldr cons
            values
            (agentic-ai-lab-user-alist-ref check field '())))
   '()
   checks))
