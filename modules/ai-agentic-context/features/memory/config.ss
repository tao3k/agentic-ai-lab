;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for Context Memory Feature store specs and catalog receipts.
;;; Invariant: users author POO memory specs; runtime memory remains external.

(import
        (only-in :clan/poo/object .ref)
        :core/module-system/selection/objects
        :poo-flow/modules/module-authoring/module-config-syntax
        :poo-flow/modules/ai-agentic-context/features/memory/objects)

(export (import: :poo-flow/modules/ai-agentic-context/features/memory/objects)
        memory-store-spec
        memory-catalog
        memory-catalog-validation
        memory-catalog-validation-row
        poo-flow-ai-agentic-context-memory-poo-store-spec?
        poo-flow-ai-agentic-context-memory-poo-catalog?
        poo-flow-ai-agentic-context-memory-poo-store-spec->store-spec
        poo-flow-ai-agentic-context-memory-poo-catalog->catalog
        poo-flow-ai-agentic-context-memory-prototype-super
        poo-flow-ai-agentic-context-memory-poo-config-flags
        poo-flow-memory-configs
        poo-flow-ai-agentic-context-memory-module-bundles)

(defsyntax (poo-flow-memory-configs stx)
  (syntax-case stx ()
    ((_ config-form ...)
     (syntax
      (poo-flow-module-configs
       ai-agentic-context
       poo-flow-ai-agentic-context-memory-poo-config-flags
       (quoted :config config-form ...)
       config-form ...)))))

(defpoo-module-config-prototype
  memory-store-spec
  (slots ((kind +poo-flow-ai-agentic-context-memory-store-spec-kind+)
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
  (slots ((kind +poo-flow-ai-agentic-context-memory-catalog-kind+)
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
   (poo-flow-memory-policy-catalog-validation-receipt
    'validation-id
    catalog
    (list intent ...)
    '(metadata-entry ...)))
  ((_ validation-id catalog
      (intent ...))
   (poo-flow-memory-policy-catalog-validation-receipt
    'validation-id
    catalog
    (list intent ...))))

;; : (-> PooMemoryPolicyCatalogValidationReceipt Alist)
(def (memory-catalog-validation-row receipt)
  (poo-flow-memory-policy-catalog-validation-receipt->alist receipt))

;; : (-> Symbol POOObject)
(def (poo-flow-ai-agentic-context-memory-prototype-super name)
  (cond
   ((eq? name 'memory-store-spec) memory-store-spec)
   ((eq? name 'memory-catalog) memory-catalog)
   (else
    (error "unknown Context Memory Feature prototype super" name))))

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-ai-agentic-context-memory-poo-store-spec?
  +poo-flow-ai-agentic-context-memory-store-spec-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-ai-agentic-context-memory-poo-catalog?
  +poo-flow-ai-agentic-context-memory-catalog-kind+)

;; : (-> PooMemoryStoreSpecPrototype PooMemoryStoreSpec)
(defpoo-module-config-converter
  poo-flow-ai-agentic-context-memory-poo-store-spec->store-spec (spec)
  (constructor poo-flow-memory-store-spec)
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
(def (poo-flow-ai-agentic-context-memory-poo-store-specs->store-specs specs)
  (cond
   ((null? specs) '())
   ((pair? specs)
    (cons (poo-flow-ai-agentic-context-memory-poo-store-spec->store-spec (car specs))
          (poo-flow-ai-agentic-context-memory-poo-store-specs->store-specs
           (cdr specs))))
   (else
    (error "Context Memory Feature POO store specs must be a list" specs))))

;; : (-> PooMemoryCatalogPrototype [PooMemoryStoreSpec] PooMemoryCatalog)
(defpoo-module-config-converter
  poo-flow-ai-agentic-context-memory-poo-catalog->catalog (catalog specs)
  (constructor poo-flow-memory-catalog)
  (arguments (slot catalog-ref)
             (value specs)
             (slot metadata)))

;; : (-> [POOObject] [POOObject])
(def (poo-flow-ai-agentic-context-memory-poo-config-store-specs prototypes)
  (filter poo-flow-ai-agentic-context-memory-poo-store-spec? prototypes))

;; : (-> [POOObject] [POOObject])
(def (poo-flow-ai-agentic-context-memory-poo-config-catalogs prototypes)
  (filter poo-flow-ai-agentic-context-memory-poo-catalog? prototypes))

;; : (-> PooMemoryStoreSpec Alist)
(def (poo-flow-ai-agentic-context-memory-catalog-manifest spec)
  (poo-flow-memory-handoff-manifest->alist
   (poo-flow-memory-handoff-manifest
    (string->symbol
     (string-append
      "memory/request/"
      (symbol->string (poo-flow-memory-store-spec-ref spec))))
    spec)))

;; : (-> [PooMemoryStoreSpec] [Alist] [Alist])
(def (poo-flow-ai-agentic-context-memory-catalog-manifests/rev specs manifests-rev)
  (if (null? specs)
    manifests-rev
    (poo-flow-ai-agentic-context-memory-catalog-manifests/rev
     (cdr specs)
     (cons (poo-flow-ai-agentic-context-memory-catalog-manifest (car specs))
           manifests-rev))))

;; : (-> PooMemoryCatalog [Alist])
(def (poo-flow-ai-agentic-context-memory-catalog-manifests catalog)
  (reverse
   (poo-flow-ai-agentic-context-memory-catalog-manifests/rev
    (.ref catalog 'stores)
    '())))

;; : (-> [POOObject] Alist [UserModuleFlagEntry])
(def (memory-config-payload prototypes user-config)
  (let* ((store-specs
          (poo-flow-ai-agentic-context-memory-poo-store-specs->store-specs
           (poo-flow-ai-agentic-context-memory-poo-config-store-specs prototypes)))
         (catalogs (poo-flow-ai-agentic-context-memory-poo-config-catalogs prototypes))
         (catalog
          (if (null? catalogs)
            (poo-flow-memory-catalog 'memory-core/user store-specs)
            (poo-flow-ai-agentic-context-memory-poo-catalog->catalog
             (car catalogs)
             store-specs))))
    (list '+catalog
          '+typed-receipts
          '+runtime-manifest
          (cons ':config (list catalog))
          (cons ':memory-catalog catalog)
          (cons ':memory-manifests
                (poo-flow-ai-agentic-context-memory-catalog-manifests catalog))
          (cons ':user-config user-config))))

;; : [[PooUserModuleSelection]]
(def poo-flow-ai-agentic-context-memory-module-bundles
  (list
   (poo-flow-user-module-bundle
    (agentic ai-agentic-context +memory +catalog +typed-receipts +runtime-manifest))))

(def (poo-flow-ai-agentic-context-memory-poo-config-flags prototypes user-config)
  (cons '+memory (memory-config-payload prototypes user-config)))
