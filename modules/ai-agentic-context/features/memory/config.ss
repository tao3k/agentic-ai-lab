;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for Context Memory Feature store specs and catalog receipts.
;;; Invariant: users author POO memory specs; runtime memory remains external.

(import
        (only-in :clan/poo/object .ref)
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/module-authoring/module-config-syntax
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects)

(export (import: :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects)
        memory-store-spec
        memory-catalog
        memory-catalog-validation
        memory-catalog-validation-row
        agentic-ai-lab-ai-agentic-context-memory-poo-store-spec?
        agentic-ai-lab-ai-agentic-context-memory-poo-catalog?
        agentic-ai-lab-ai-agentic-context-memory-poo-store-spec->store-spec
        agentic-ai-lab-ai-agentic-context-memory-poo-catalog->catalog
        agentic-ai-lab-ai-agentic-context-memory-prototype-super
        agentic-ai-lab-ai-agentic-context-memory-poo-config-flags
        agentic-ai-lab-memory-configs
        agentic-ai-lab-ai-agentic-context-memory-module-bundles)

(defsyntax (agentic-ai-lab-memory-configs stx)
  (syntax-case stx ()
    ((_ config-form ...)
     (syntax
      (agentic-ai-lab-module-configs
       ai-agentic-context
       agentic-ai-lab-ai-agentic-context-memory-poo-config-flags
       (quoted :config config-form ...)
       config-form ...)))))

(defpoo-module-config-prototype
  memory-store-spec
  (slots ((kind +agentic-ai-lab-ai-agentic-context-memory-store-spec-kind+)
          (store-ref #f)
          (store-kind 'custom)
          (namespace 'session)
          (scopes '())
          (recall-policies '())
          (commit-policies '())
          (runtime-owner "marlin-agent-core")
          (handoff-operation 'memory/custom)
          (durable? #f)
          (runtime-backend 'marlin-memory-adapter)
          (metadata '())
          (runtime-executed #f))))

(defpoo-module-config-prototype
  memory-catalog
  (slots ((kind +agentic-ai-lab-ai-agentic-context-memory-catalog-kind+)
          (catalog-ref 'memory-core/catalog)
          (stores '())
          (metadata '())
          (runtime-owner "marlin-agent-core")
          (runtime-executed #f))))

;; memory-catalog-validation
;;   : (-> Syntax PooMemoryPolicyCatalogValidationReceipt)
;;   | doc m%
;;       Validation belongs to the Memory Feature facade: users pass a concrete
;;       catalog and session memory intents, then receive a report-only receipt.
;;       Scheme never recalls, commits, or persists memory.
;;
;;       # Examples
;;       ```scheme
;;       (memory-catalog-validation memory-check catalog
;;         (intent recall-plan))
;;       ;; => validation receipt
;;       ```
;;     %
(defrules memory-catalog-validation (metadata)
  ((_ validation-id catalog
      (intent ...)
      (metadata metadata-entry ...))
   (agentic-ai-lab-memory-policy-catalog-validation-receipt
    'validation-id
    catalog
    (list intent ...)
    '(metadata-entry ...)))
  ((_ validation-id catalog
      (intent ...))
   (agentic-ai-lab-memory-policy-catalog-validation-receipt
    'validation-id
    catalog
    (list intent ...))))

;; : (-> PooMemoryPolicyCatalogValidationReceipt Alist)
(def (memory-catalog-validation-row receipt)
  (agentic-ai-lab-memory-policy-catalog-validation-receipt->alist receipt))

;; : (-> Symbol POOObject)
(def (agentic-ai-lab-ai-agentic-context-memory-prototype-super name)
  (cond
   ((eq? name 'memory-store-spec) memory-store-spec)
   ((eq? name 'memory-catalog) memory-catalog)
   (else
    (error "unknown Context Memory Feature prototype super" name))))

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  agentic-ai-lab-ai-agentic-context-memory-poo-store-spec?
  +agentic-ai-lab-ai-agentic-context-memory-store-spec-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  agentic-ai-lab-ai-agentic-context-memory-poo-catalog?
  +agentic-ai-lab-ai-agentic-context-memory-catalog-kind+)

;; : (-> PooMemoryStoreSpecPrototype PooMemoryStoreSpec)
(defpoo-module-config-converter
  agentic-ai-lab-ai-agentic-context-memory-poo-store-spec->store-spec (spec)
  (constructor agentic-ai-lab-memory-store-spec)
  (arguments (slot store-ref)
             (slot store-kind)
             (slot namespace)
             (slot scopes)
             (slot recall-policies)
             (slot commit-policies)
             (slot runtime-owner)
             (slot handoff-operation)
             (slot durable?)
             (slot runtime-backend)
             (slot metadata)))

;; : (-> [PooMemoryStoreSpecPrototype] [PooMemoryStoreSpec])
(def (agentic-ai-lab-ai-agentic-context-memory-poo-store-specs->store-specs specs)
  (cond
   ((null? specs) '())
   ((pair? specs)
    (cons (agentic-ai-lab-ai-agentic-context-memory-poo-store-spec->store-spec (car specs))
          (agentic-ai-lab-ai-agentic-context-memory-poo-store-specs->store-specs
           (cdr specs))))
   (else
    (error "Context Memory Feature POO store specs must be a list" specs))))

;; : (-> PooMemoryCatalogPrototype [PooMemoryStoreSpec] PooMemoryCatalog)
(defpoo-module-config-converter
  agentic-ai-lab-ai-agentic-context-memory-poo-catalog->catalog (catalog specs)
  (constructor agentic-ai-lab-memory-catalog)
  (arguments (slot catalog-ref)
             (value specs)
             (slot metadata)))

;; : (-> [POOObject] [POOObject])
(def (agentic-ai-lab-ai-agentic-context-memory-poo-config-store-specs prototypes)
  (filter agentic-ai-lab-ai-agentic-context-memory-poo-store-spec? prototypes))

;; : (-> [POOObject] [POOObject])
(def (agentic-ai-lab-ai-agentic-context-memory-poo-config-catalogs prototypes)
  (filter agentic-ai-lab-ai-agentic-context-memory-poo-catalog? prototypes))

;; : (-> PooMemoryStoreSpec Alist)
(def (agentic-ai-lab-ai-agentic-context-memory-catalog-manifest spec)
  (agentic-ai-lab-memory-handoff-manifest->alist
   (agentic-ai-lab-memory-handoff-manifest
    (string->symbol
     (string-append
      "memory/request/"
      (symbol->string (agentic-ai-lab-memory-store-spec-ref spec))))
    spec)))

;; : (-> [PooMemoryStoreSpec] [Alist] [Alist])
(def (agentic-ai-lab-ai-agentic-context-memory-catalog-manifests/rev specs manifests-rev)
  (if (null? specs)
    manifests-rev
    (agentic-ai-lab-ai-agentic-context-memory-catalog-manifests/rev
     (cdr specs)
     (cons (agentic-ai-lab-ai-agentic-context-memory-catalog-manifest (car specs))
           manifests-rev))))

;; : (-> PooMemoryCatalog [Alist])
(def (agentic-ai-lab-ai-agentic-context-memory-catalog-manifests catalog)
  (reverse
   (agentic-ai-lab-ai-agentic-context-memory-catalog-manifests/rev
    (.ref catalog 'stores)
    '())))

;; : (-> [POOObject] Alist [UserModuleFlagEntry])
(def (memory-config-payload prototypes user-config)
  (let* ((store-specs
          (agentic-ai-lab-ai-agentic-context-memory-poo-store-specs->store-specs
           (agentic-ai-lab-ai-agentic-context-memory-poo-config-store-specs prototypes)))
         (catalogs (agentic-ai-lab-ai-agentic-context-memory-poo-config-catalogs prototypes))
         (catalog
          (if (null? catalogs)
            (agentic-ai-lab-memory-catalog 'memory-core/user store-specs)
            (agentic-ai-lab-ai-agentic-context-memory-poo-catalog->catalog
             (car catalogs)
             store-specs))))
    (list '+catalog
          '+typed-receipts
          '+runtime-manifest
          (cons ':config (list catalog))
          (cons ':memory-catalog catalog)
          (cons ':memory-manifests
                (agentic-ai-lab-ai-agentic-context-memory-catalog-manifests catalog))
          (cons ':user-config user-config))))

;; : [[PooUserModuleSelection]]
(def agentic-ai-lab-ai-agentic-context-memory-module-bundles
  (list
   (yuanxu-user-module-bundle
    (agentic ai-agentic-context +memory +catalog +typed-receipts +runtime-manifest))))

(def (agentic-ai-lab-ai-agentic-context-memory-poo-config-flags prototypes user-config)
  (cons '+memory (memory-config-payload prototypes user-config)))
