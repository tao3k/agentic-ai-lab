;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module doctor projection owned by Observability.
;;; Invariant: doctor presentation explains data and never activates runtime execution.
;;; Intent: borrow Doom's doctor ergonomics while keeping POO values explicit.
;;; Parser policy should treat this file as the module-system observation edge.

(import (only-in :clan/poo/object .o .ref)
        :agentic-ai-lab/modules/module-authoring/module-interface
        :yuanxu/module-system/source/imports
        :yuanxu/module-system/source/objects
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        "module-diagnostics.ss"
        :yuanxu/utilities/final-projection-syntax
        (only-in :yuanxu/module-system/projection/option-objects
                 yuanxu-module-option-validation-receipt-id
                 yuanxu-module-option-validation-receipt-source-module
                 yuanxu-module-option-validation-receipt-valid?
                 yuanxu-module-option-validation-receipt-code
                 yuanxu-module-option-validation-receipt-messages
                 yuanxu-module-option-validation-receipt-metadata)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/module-runtime-presentation
                 agentic-ai-lab-module-evaluate
                 agentic-ai-lab-module-value-catalog-root)
        :yuanxu/module-system/loader/objects)

(export agentic-ai-lab-module-doctor-presentation-kind
        agentic-ai-lab-module-source-doctor-presentation-kind
        agenticAiLabModuleDoctorPresentation
        agentic-ai-lab-module-doctor-presentation
        agenticAiLabModuleSourceDoctorPresentation
        agentic-ai-lab-module-source-doctor-presentation)

;;; Boundary: value-catalog doctor kind identifies summaries over in-memory modules.
;; : (-> Unit ModuleKindId)
(def agentic-ai-lab-module-doctor-presentation-kind
  "agentic-ai-lab.modules.doctor-presentation.v1")

;;; Boundary: source doctor kind identifies summaries that include loader receipts.
;; : (-> Unit ModuleKindId)
(def agentic-ai-lab-module-source-doctor-presentation-kind
  "agentic-ai-lab.modules.source-doctor-presentation.v1")

;;; Boundary: validation receipt projection stays local to the doctor edge.
;; : (-> PooModuleOptionValidationReceipt Alist)
(defpoo-final-projection
  agentic-ai-lab-module-validation-receipt->alist (receipt)
  (bindings ())
  (fields ((id (yuanxu-module-option-validation-receipt-id receipt))
           (source-module
            (yuanxu-module-option-validation-receipt-source-module receipt))
           (valid? (yuanxu-module-option-validation-receipt-valid? receipt))
           (code (yuanxu-module-option-validation-receipt-code receipt))
           (messages
            (yuanxu-module-option-validation-receipt-messages receipt))
           (metadata
            (yuanxu-module-option-validation-receipt-metadata receipt)))))

;;; Boundary: import profiles are summarized without resolving source refs.
;; : (-> ModuleImportProfile Value)
(def (agentic-ai-lab-module-import-profile-summary profile)
  (cond
   ((agentic-ai-lab-module-config? profile) (agentic-ai-lab-module-name profile))
   (else profile)))

;;; Boundary: import summaries expose source metadata and profile identity only.
;; : (-> ModuleImportValue Alist)
(def (agentic-ai-lab-module-import-summary import-value)
  (if (yuanxu-import? import-value)
    (let ((source-ref (.ref import-value 'source-ref))
          (profile (.ref import-value 'profile)))
      (list (cons 'source
                  (if source-ref
                    (yuanxu-module-source-ref->alist source-ref)
                    #f))
            (cons 'profile
                  (agentic-ai-lab-module-import-profile-summary profile))))
    (list (cons 'source #f)
          (cons 'profile
                (agentic-ai-lab-module-import-profile-summary import-value)))))

;;; Boundary: import graph is a per-module projection, not a resolver action.
;; : (-> PooModuleDescriptor Alist)
(def (agentic-ai-lab-module-import-graph-entry module)
  (cons (agentic-ai-lab-module-name module)
        (map agentic-ai-lab-module-import-summary
             (yuanxu-module-imports module))))

;;; Boundary: full import graph keeps named imports unresolved for doctor visibility.
;; : (-> [PooModuleDescriptor] Alist)
(def (agentic-ai-lab-module-import-graph modules)
  (map agentic-ai-lab-module-import-graph-entry modules))

;;; Boundary: contribution summary counts descriptor payloads without interpreting them.
;; : (-> PooModuleDescriptor Alist)
(def (agentic-ai-lab-module-contribution-summary module)
  (list (cons 'module (agentic-ai-lab-module-name module))
        (cons 'import-count (length (yuanxu-module-imports module)))
        (cons 'task-count (length (agentic-ai-lab-module-task-descriptors module)))
        (cons 'flow-count (length (agentic-ai-lab-module-flow-descriptors module)))
        (cons 'option-count (length (agentic-ai-lab-module-options module)))
        (cons 'extension-count (length (agentic-ai-lab-module-extensions module)))
        (cons 'script-count (length (agentic-ai-lab-module-scripts module)))
        (cons 'hook-count (length (agentic-ai-lab-module-hooks module)))))

;;; Boundary: contribution summaries are intentionally shallow for CLI-sized output.
;; : (-> [PooModuleDescriptor] [Alist])
(def (agentic-ai-lab-module-contribution-summaries modules)
  (map agentic-ai-lab-module-contribution-summary modules))

;;; Boundary: loader status is a presentation signal, not a strict-load action.
;; : (-> [PooModuleLoadReceipt] Boolean)
(def (agentic-ai-lab-module-load-receipts-all-loaded? receipts)
  (cond
   ((null? receipts) #t)
   ((yuanxu-module-load-receipt-loaded? (car receipts))
    (agentic-ai-lab-module-load-receipts-all-loaded? (cdr receipts)))
   (else #f)))

;;; Boundary: missing count is derived from receipts without inspecting sources.
;; : (-> [PooModuleLoadReceipt] Fixnum)
(def (agentic-ai-lab-module-load-receipts-missing-count receipts)
  (cond
   ((null? receipts) 0)
   ((yuanxu-module-load-receipt-loaded? (car receipts))
    (agentic-ai-lab-module-load-receipts-missing-count (cdr receipts)))
   (else
    (+ 1 (agentic-ai-lab-module-load-receipts-missing-count (cdr receipts))))))

;;; Boundary: empty source lists are distinct from failed source loads.
;; : (-> [PooModuleSourceRef] [PooModuleLoadReceipt] Symbol)
(def (agentic-ai-lab-module-load-status source-refs receipts)
  (cond
   ((null? source-refs) 'empty)
   ((agentic-ai-lab-module-load-receipts-all-loaded? receipts) 'ok)
   (else 'error)))

;;; Boundary: root doctor presentation is the shared data projection for both callers.
;; : (-> PooModuleDescriptor POOObject)
(def (agentic-ai-lab-module-root-doctor-presentation root-module)
  (let* ((closed-modules (agentic-ai-lab-module-closure (list root-module)))
         (doctor-report (agentic-ai-lab-module-doctor closed-modules))
         (evaluation-value (agentic-ai-lab-module-evaluate root-module))
         (validation-receipts
         (.ref evaluation-value 'validation-receipts)))
    (.o kind: agentic-ai-lab-module-doctor-presentation-kind
        root-module-id: (agentic-ai-lab-module-name root-module)
        module-ids: (agentic-ai-lab-module-names closed-modules)
        doctor-status: (yuanxu-module-doctor-report-status doctor-report)
        doctor-ok: (yuanxu-module-doctor-ok? doctor-report)
        diagnostics:
        (map agentic-ai-lab-module-diagnostic->alist
             (yuanxu-module-doctor-report-diagnostics doctor-report))
        import-graph: (agentic-ai-lab-module-import-graph closed-modules)
        contributions: (agentic-ai-lab-module-contribution-summaries closed-modules)
        validation-receipt-count: (length validation-receipts)
        module-evaluation-kind: (.ref evaluation-value 'kind)
        brand-name: agentic-ai-lab-brand-name
        brand-group: agentic-ai-lab-brand-group
        scheme-owner: agentic-ai-lab-scheme-owner
        module-system-owner: agentic-ai-lab-module-system-owner
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
(def (agenticAiLabModuleDoctorPresentation catalog . maybe-root-module-id)
  (agentic-ai-lab-module-root-doctor-presentation
   (agentic-ai-lab-module-value-catalog-root
    catalog
    (if (null? maybe-root-module-id) #f (car maybe-root-module-id)))))

;; : (-> PooModuleValueCatalog MaybeModuleName POOObject)
(def agentic-ai-lab-module-doctor-presentation
  agenticAiLabModuleDoctorPresentation)

;;; Boundary: source doctor ignores failed loads here because receipts retain failures.
;; : (-> [PooModuleLoadReceipt] [PooModuleDescriptor])
(def (agentic-ai-lab-module-loaded-modules-from-receipts receipts)
  (cond
   ((null? receipts) '())
   ((yuanxu-module-load-receipt-loaded? (car receipts))
    (cons (yuanxu-module-load-receipt-module (car receipts))
          (agentic-ai-lab-module-loaded-modules-from-receipts (cdr receipts))))
   (else
    (agentic-ai-lab-module-loaded-modules-from-receipts (cdr receipts)))))

;;; Boundary: source doctor surfaces loader evidence before descriptor diagnostics.
;; : (-> [PooModuleLoaderBackend] [PooModuleSourceRef] POOObject)
(def (agenticAiLabModuleSourceDoctorPresentation backends source-refs)
  (let* ((load-receipts-value
         (yuanxu-module-load-source-receipts backends source-refs))
         (loaded-modules
          (agentic-ai-lab-module-loaded-modules-from-receipts load-receipts-value))
         (root-module
          (if (null? loaded-modules) #f (car loaded-modules)))
         (missing-count-value
          (agentic-ai-lab-module-load-receipts-missing-count load-receipts-value))
         (load-status-value
          (agentic-ai-lab-module-load-status source-refs load-receipts-value)))
    (.o kind: agentic-ai-lab-module-source-doctor-presentation-kind
        source-count: (length source-refs)
        loaded-count: (length loaded-modules)
        missing-count: missing-count-value
        load-status: load-status-value
        load-receipts:
        (map yuanxu-module-load-receipt->alist load-receipts-value)
        module-doctor:
        (if root-module
          (agentic-ai-lab-module-root-doctor-presentation root-module)
          #f)
        brand-name: agentic-ai-lab-brand-name
        brand-group: agentic-ai-lab-brand-group
        scheme-owner: agentic-ai-lab-scheme-owner
        module-system-owner: agentic-ai-lab-module-system-owner
        runtime-owner: "marlin-agent-core"
        runtime-boundary-owner: "marlin-agent-core"
        runtime-parses-scheme-source: #f
        scheme-manufactures-runtime-handlers: #f
        runtime-executed: #f
        replayable: #t)))

;; : (-> [PooModuleLoaderBackend] [PooModuleSourceRef] POOObject)
(def agentic-ai-lab-module-source-doctor-presentation
  agenticAiLabModuleSourceDoctorPresentation)
