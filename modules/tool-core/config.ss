;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for tool-core specs and catalog receipts.
;;; Invariant: users author POO tool specs; runtime execution remains external.

(import
        (only-in :clan/poo/object .ref)
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/module-authoring/module-config-syntax
        :agentic-ai-lab/modules/tool-core/objects)

(export (import: :agentic-ai-lab/modules/tool-core/objects)
        tool-spec
        tool-catalog
        tool-catalog-validation
        tool-catalog-validation-row
        agentic-ai-lab-tool-core-poo-spec?
        agentic-ai-lab-tool-core-poo-catalog?
        agentic-ai-lab-tool-core-poo-spec->tool-spec
        agentic-ai-lab-tool-core-poo-catalog->catalog
        agentic-ai-lab-tool-core-poo-config-flags
        agentic-ai-lab-tool-configs
        agentic-ai-lab-tool-core-module-bundles)

(defsyntax (agentic-ai-lab-tool-configs stx)
  (syntax-case stx ()
    ((_ config-form ...)
     (syntax
      (agentic-ai-lab-module-configs
       tool-core
       agentic-ai-lab-tool-core-poo-config-flags
       (quoted :config config-form ...)
       config-form ...)))))

;; : PooToolSpecPrototype
(defpoo-module-config-prototype
  tool-spec
  (slots ((kind +agentic-ai-lab-tool-core-spec-kind+)
          (tool-ref #f)
          (tool-kind 'custom)
          (actions '())
          (input-schema '())
          (output-schema '())
          (runtime-owner "marlin-agent-core")
          (handoff-operation 'tool/custom)
          (sandbox-required? #f)
          (sandbox-profile-ref #f)
          (runtime-backend 'marlin-tool-adapter)
          (metadata '())
          (runtime-executed #f))))

;; : PooToolCatalogPrototype
(defpoo-module-config-prototype
  tool-catalog
  (slots ((kind +agentic-ai-lab-tool-core-catalog-kind+)
          (catalog-ref 'tool-core/catalog)
          (tools '())
          (metadata '())
          (runtime-owner "marlin-agent-core")
          (runtime-executed #f))))

;; tool-catalog-validation
;;   : (-> Symbol PooToolCatalog PooSessionPolicy PooSessionPolicy [Alist]
;;          PooToolPolicyCatalogValidationReceipt)
;;   | doc m%
;;       Validation belongs to tool-core's user facade: users pass a concrete
;;       catalog plus effective session tool policies and receive a report-only
;;       receipt. Scheme never dispatches the tool.
;;
;;       # Examples
;;       ```scheme
;;       (tool-catalog-validation 'tool-check catalog agent-policy hook-policy)
;;       ;; => validation receipt
;;       ```
;;     %
(def (tool-catalog-validation validation-id
                              catalog
                              agent-tool-policy
                              hook-tool-policy
                              . maybe-metadata)
  (apply agentic-ai-lab-tool-policy-catalog-validation-receipt
         validation-id
         catalog
         agent-tool-policy
         hook-tool-policy
         maybe-metadata))

;; : (-> PooToolPolicyCatalogValidationReceipt Alist)
(def (tool-catalog-validation-row receipt)
  (agentic-ai-lab-tool-policy-catalog-validation-receipt->alist receipt))

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  agentic-ai-lab-tool-core-poo-spec?
  +agentic-ai-lab-tool-core-spec-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  agentic-ai-lab-tool-core-poo-catalog?
  +agentic-ai-lab-tool-core-catalog-kind+)

;; : (-> PooToolSpecPrototype PooToolSpec)
(defpoo-module-config-converter
  agentic-ai-lab-tool-core-poo-spec->tool-spec (spec)
  (constructor agentic-ai-lab-tool-spec)
  (arguments (slot tool-ref)
             (slot tool-kind)
             (slot actions)
             (slot input-schema)
             (slot output-schema)
             (slot runtime-owner)
             (slot handoff-operation)
             (slot sandbox-required?)
             (slot sandbox-profile-ref)
             (slot runtime-backend)
             (slot metadata)))

;; : (-> [PooToolSpecPrototype] [PooToolSpec])
(def (agentic-ai-lab-tool-core-poo-specs->tool-specs specs)
  (cond
   ((null? specs) '())
   ((pair? specs)
    (cons (agentic-ai-lab-tool-core-poo-spec->tool-spec (car specs))
          (agentic-ai-lab-tool-core-poo-specs->tool-specs (cdr specs))))
   (else
    (error "tool-core POO specs must be a list" specs))))

;; : (-> PooToolCatalogPrototype [PooToolSpec] PooToolCatalog)
(defpoo-module-config-converter
  agentic-ai-lab-tool-core-poo-catalog->catalog (catalog specs)
  (constructor agentic-ai-lab-tool-catalog)
  (arguments (slot catalog-ref)
             (value specs)
             (slot metadata)))

;; : (-> [POOObject] [POOObject])
(def (agentic-ai-lab-tool-core-poo-config-specs prototypes)
  (filter agentic-ai-lab-tool-core-poo-spec? prototypes))

;; : (-> [POOObject] [POOObject])
(def (agentic-ai-lab-tool-core-poo-config-catalogs prototypes)
  (filter agentic-ai-lab-tool-core-poo-catalog? prototypes))

;; : (-> PooToolSpec Alist)
(def (agentic-ai-lab-tool-core-catalog-manifest spec)
  (agentic-ai-lab-tool-handoff-manifest->alist
   (agentic-ai-lab-tool-handoff-manifest
    (string->symbol
     (string-append
      "tool/request/"
      (symbol->string (agentic-ai-lab-tool-spec-ref spec))))
    spec)))

;; : (-> [PooToolSpec] [Alist] [Alist])
(def (agentic-ai-lab-tool-core-catalog-manifests/rev specs manifests-rev)
  (if (null? specs)
    manifests-rev
    (agentic-ai-lab-tool-core-catalog-manifests/rev
     (cdr specs)
     (cons (agentic-ai-lab-tool-core-catalog-manifest (car specs))
           manifests-rev))))

;; : (-> PooToolCatalog [Alist])
(def (agentic-ai-lab-tool-core-catalog-manifests catalog)
  (reverse
   (agentic-ai-lab-tool-core-catalog-manifests/rev
    (.ref catalog 'tools)
    '())))

;; : (-> [POOObject] Alist [UserModuleFlagEntry])
(def (agentic-ai-lab-tool-core-poo-config-flags prototypes user-config)
  (let* ((specs
          (agentic-ai-lab-tool-core-poo-specs->tool-specs
           (agentic-ai-lab-tool-core-poo-config-specs prototypes)))
         (catalogs (agentic-ai-lab-tool-core-poo-config-catalogs prototypes))
         (catalog
          (if (null? catalogs)
            (agentic-ai-lab-tool-catalog 'tool-core/user specs)
            (agentic-ai-lab-tool-core-poo-catalog->catalog (car catalogs) specs))))
    (list '+catalog
          '+typed-receipts
          '+runtime-manifest
          (cons ':config (list catalog))
          (cons ':tool-catalog catalog)
          (cons ':tool-manifests
                (agentic-ai-lab-tool-core-catalog-manifests catalog))
          (cons ':user-config user-config))))

;; : [[PooUserModuleSelection]]
(def agentic-ai-lab-tool-core-module-bundles
  (list
   (yuanxu-user-module-bundle
    (session tool-core +catalog +typed-receipts +runtime-manifest))))
