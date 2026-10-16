;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module doctor projection owned by Observability.
;;; Invariant: doctor presentation explains data and never activates runtime execution.
;;; Intent: borrow Doom's doctor ergonomics while keeping POO values explicit.
;;; Parser policy should treat this file as the module-system observation edge.

(import (only-in :clan/poo/object .o .ref)
        :poo-flow/modules/module-authoring/module-interface
        :core/module-system/source/imports
        :core/module-system/source/objects
        :poo-flow/modules/module-authoring/module-descriptor
        "module-diagnostics.ss"
        :core/utilities/final-projection-syntax
        (only-in :core/module-system/projection/option-objects
                 poo-flow-module-option-validation-receipt-id
                 poo-flow-module-option-validation-receipt-source-module
                 poo-flow-module-option-validation-receipt-valid?
                 poo-flow-module-option-validation-receipt-code
                 poo-flow-module-option-validation-receipt-messages
                 poo-flow-module-option-validation-receipt-metadata)
        (only-in :poo-flow/modules/workflow/scenario/configuration/module-runtime-presentation
                 poo-flow-module-evaluate
                 poo-flow-module-value-catalog-root)
        :core/module-system/loader/objects)

(export poo-flow-module-doctor-presentation-kind
        poo-flow-module-source-doctor-presentation-kind
        pooFlowModuleDoctorPresentation
        poo-flow-module-doctor-presentation
        pooFlowModuleSourceDoctorPresentation
        poo-flow-module-source-doctor-presentation)

;;; Boundary: value-catalog doctor kind identifies summaries over in-memory modules.
;; : (-> Unit ModuleKindId)
(def poo-flow-module-doctor-presentation-kind
  "poo-flow.modules.doctor-presentation.v1")

;;; Boundary: source doctor kind identifies summaries that include loader receipts.
;; : (-> Unit ModuleKindId)
(def poo-flow-module-source-doctor-presentation-kind
  "poo-flow.modules.source-doctor-presentation.v1")

;;; Boundary: validation receipt projection stays local to the doctor edge.
;; : (-> PooModuleOptionValidationReceipt Alist)
(defpoo-final-projection
  poo-flow-module-validation-receipt->alist (receipt)
  (bindings ())
  (fields ((id (poo-flow-module-option-validation-receipt-id receipt))
           (source-module
            (poo-flow-module-option-validation-receipt-source-module receipt))
           (valid? (poo-flow-module-option-validation-receipt-valid? receipt))
           (code (poo-flow-module-option-validation-receipt-code receipt))
           (messages
            (poo-flow-module-option-validation-receipt-messages receipt))
           (metadata
            (poo-flow-module-option-validation-receipt-metadata receipt)))))

;;; Boundary: import profiles are summarized without resolving source refs.
;; : (-> ModuleImportProfile Value)
(def (poo-flow-module-import-profile-summary profile)
  (cond
   ((poo-flow-module-config? profile) (poo-flow-module-name profile))
   (else profile)))

;;; Boundary: import summaries expose source metadata and profile identity only.
;; : (-> ModuleImportValue Alist)
(def (poo-flow-module-import-summary import-value)
  (if (poo-flow-import? import-value)
    (let ((source-ref (.ref import-value 'source-ref))
          (profile (.ref import-value 'profile)))
      (list (cons 'source
                  (if source-ref
                    (poo-flow-module-source-ref->alist source-ref)
                    #f))
            (cons 'profile
                  (poo-flow-module-import-profile-summary profile))))
    (list (cons 'source #f)
          (cons 'profile
                (poo-flow-module-import-profile-summary import-value)))))

;;; Boundary: import graph is a per-module projection, not a resolver action.
;; : (-> PooModuleDescriptor Alist)
(def (poo-flow-module-import-graph-entry module)
  (cons (poo-flow-module-name module)
        (map poo-flow-module-import-summary
             (poo-flow-module-imports module))))

;;; Boundary: full import graph keeps named imports unresolved for doctor visibility.
;; : (-> [PooModuleDescriptor] Alist)
(def (poo-flow-module-import-graph modules)
  (map poo-flow-module-import-graph-entry modules))

;;; Boundary: contribution summary counts descriptor payloads without interpreting them.
;; : (-> PooModuleDescriptor Alist)
(def (poo-flow-module-contribution-summary module)
  (list (cons 'module (poo-flow-module-name module))
        (cons 'import-count (length (poo-flow-module-imports module)))
        (cons 'task-count (length (poo-flow-module-task-descriptors module)))
        (cons 'flow-count (length (poo-flow-module-flow-descriptors module)))
        (cons 'option-count (length (poo-flow-module-options module)))
        (cons 'extension-count (length (poo-flow-module-extensions module)))
        (cons 'script-count (length (poo-flow-module-scripts module)))
        (cons 'hook-count (length (poo-flow-module-hooks module)))))

;;; Boundary: contribution summaries are intentionally shallow for CLI-sized output.
;; : (-> [PooModuleDescriptor] [Alist])
(def (poo-flow-module-contribution-summaries modules)
  (map poo-flow-module-contribution-summary modules))

;;; Boundary: loader status is a presentation signal, not a strict-load action.
;; : (-> [PooModuleLoadReceipt] Boolean)
(def (poo-flow-module-load-receipts-all-loaded? receipts)
  (cond
   ((null? receipts) #t)
   ((poo-flow-module-load-receipt-loaded? (car receipts))
    (poo-flow-module-load-receipts-all-loaded? (cdr receipts)))
   (else #f)))

;;; Boundary: missing count is derived from receipts without inspecting sources.
;; : (-> [PooModuleLoadReceipt] Fixnum)
(def (poo-flow-module-load-receipts-missing-count receipts)
  (cond
   ((null? receipts) 0)
   ((poo-flow-module-load-receipt-loaded? (car receipts))
    (poo-flow-module-load-receipts-missing-count (cdr receipts)))
   (else
    (+ 1 (poo-flow-module-load-receipts-missing-count (cdr receipts))))))

;;; Boundary: empty source lists are distinct from failed source loads.
;; : (-> [PooModuleSourceRef] [PooModuleLoadReceipt] Symbol)
(def (poo-flow-module-load-status source-refs receipts)
  (cond
   ((null? source-refs) 'empty)
   ((poo-flow-module-load-receipts-all-loaded? receipts) 'ok)
   (else 'error)))

;;; Boundary: root doctor presentation is the shared data projection for both callers.
;; : (-> PooModuleDescriptor POOObject)
(def (poo-flow-module-root-doctor-presentation root-module)
  (let* ((closed-modules (poo-flow-module-closure (list root-module)))
         (doctor-report (poo-flow-module-doctor closed-modules))
         (evaluation-value (poo-flow-module-evaluate root-module))
         (validation-receipts
         (.ref evaluation-value 'validation-receipts)))
    (.o kind: poo-flow-module-doctor-presentation-kind
        root-module-id: (poo-flow-module-name root-module)
        module-ids: (poo-flow-module-names closed-modules)
        doctor-status: (poo-flow-module-doctor-report-status doctor-report)
        doctor-ok: (poo-flow-module-doctor-ok? doctor-report)
        diagnostics:
        (map poo-flow-module-diagnostic->alist
             (poo-flow-module-doctor-report-diagnostics doctor-report))
        import-graph: (poo-flow-module-import-graph closed-modules)
        contributions: (poo-flow-module-contribution-summaries closed-modules)
        validation-receipt-count: (length validation-receipts)
        module-evaluation-kind: (.ref evaluation-value 'kind)
        brand-name: poo-flow-brand-name
        brand-group: poo-flow-brand-group
        scheme-owner: poo-flow-scheme-owner
        module-system-owner: poo-flow-module-system-owner
        runtime-owner: "marlin-agent-core"
        runtime-boundary-owner: "marlin-agent-core"
        runtime-parses-scheme-source: #f
        scheme-manufactures-runtime-handlers: #f
        runtime-executed: #f
        replayable: #t)))

;;; Boundary: value-catalog doctor mirrors system presentation root selection.
;;; Intent: callers can inspect already-built module values without invoking source loaders.
;;; Runtime activation remains an explicit resolver step outside this presentation helper.
;; : (-> PooModuleValueCatalog MaybeModuleName POOObject)
(def (pooFlowModuleDoctorPresentation catalog . maybe-root-module-id)
  (poo-flow-module-root-doctor-presentation
   (poo-flow-module-value-catalog-root
    catalog
    (if (null? maybe-root-module-id) #f (car maybe-root-module-id)))))

;; : (-> PooModuleValueCatalog MaybeModuleName POOObject)
(def poo-flow-module-doctor-presentation
  pooFlowModuleDoctorPresentation)

;;; Boundary: source doctor ignores failed loads here because receipts retain failures.
;; : (-> [PooModuleLoadReceipt] [PooModuleDescriptor])
(def (poo-flow-module-loaded-modules-from-receipts receipts)
  (cond
   ((null? receipts) '())
   ((poo-flow-module-load-receipt-loaded? (car receipts))
    (cons (poo-flow-module-load-receipt-module (car receipts))
          (poo-flow-module-loaded-modules-from-receipts (cdr receipts))))
   (else
    (poo-flow-module-loaded-modules-from-receipts (cdr receipts)))))

;;; Boundary: source doctor surfaces loader evidence before descriptor diagnostics.
;; : (-> [PooModuleLoaderBackend] [PooModuleSourceRef] POOObject)
(def (pooFlowModuleSourceDoctorPresentation backends source-refs)
  (let* ((load-receipts-value
         (poo-flow-module-load-source-receipts backends source-refs))
         (loaded-modules
          (poo-flow-module-loaded-modules-from-receipts load-receipts-value))
         (root-module
          (if (null? loaded-modules) #f (car loaded-modules)))
         (missing-count-value
          (poo-flow-module-load-receipts-missing-count load-receipts-value))
         (load-status-value
          (poo-flow-module-load-status source-refs load-receipts-value)))
    (.o kind: poo-flow-module-source-doctor-presentation-kind
        source-count: (length source-refs)
        loaded-count: (length loaded-modules)
        missing-count: missing-count-value
        load-status: load-status-value
        load-receipts:
        (map poo-flow-module-load-receipt->alist load-receipts-value)
        module-doctor:
        (if root-module
          (poo-flow-module-root-doctor-presentation root-module)
          #f)
        brand-name: poo-flow-brand-name
        brand-group: poo-flow-brand-group
        scheme-owner: poo-flow-scheme-owner
        module-system-owner: poo-flow-module-system-owner
        runtime-owner: "marlin-agent-core"
        runtime-boundary-owner: "marlin-agent-core"
        runtime-parses-scheme-source: #f
        scheme-manufactures-runtime-handlers: #f
        runtime-executed: #f
        replayable: #t)))

;; : (-> [PooModuleLoaderBackend] [PooModuleSourceRef] POOObject)
(def poo-flow-module-source-doctor-presentation
  pooFlowModuleSourceDoctorPresentation)
