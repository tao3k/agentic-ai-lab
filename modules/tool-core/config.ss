;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for tool-core specs and catalog receipts.
;;; Invariant: users author POO tool specs; runtime execution remains external.

(import
        (only-in :clan/poo/object .ref)
        :core/module-system/selection/objects
        :poo-flow/modules/module-authoring/module-config-syntax
        :poo-flow/modules/tool-core/objects)

(export (import: :poo-flow/modules/tool-core/objects)
        tool-spec
        tool-catalog
        tool-catalog-validation
        tool-catalog-validation-row
        poo-flow-tool-core-poo-spec?
        poo-flow-tool-core-poo-catalog?
        poo-flow-tool-core-poo-spec->tool-spec
        poo-flow-tool-core-poo-catalog->catalog
        poo-flow-tool-core-poo-config-flags
        poo-flow-tool-configs
        poo-flow-tool-core-module-bundles)

(defsyntax (poo-flow-tool-configs stx)
  (syntax-case stx ()
    ((_ config-form ...)
     (syntax
      (poo-flow-module-configs
       tool-core
       poo-flow-tool-core-poo-config-flags
       (quoted :config config-form ...)
       config-form ...)))))

;; : PooToolSpecPrototype
(defpoo-module-config-prototype
  tool-spec
  (slots ((kind +poo-flow-tool-core-spec-kind+)
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
  (slots ((kind +poo-flow-tool-core-catalog-kind+)
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
  (apply poo-flow-tool-policy-catalog-validation-receipt
         validation-id
         catalog
         agent-tool-policy
         hook-tool-policy
         maybe-metadata))

;; : (-> PooToolPolicyCatalogValidationReceipt Alist)
(def (tool-catalog-validation-row receipt)
  (poo-flow-tool-policy-catalog-validation-receipt->alist receipt))

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-tool-core-poo-spec?
  +poo-flow-tool-core-spec-kind+)

;; : (-> POOObject Boolean)
(defpoo-module-config-kind-predicate
  poo-flow-tool-core-poo-catalog?
  +poo-flow-tool-core-catalog-kind+)

;; : (-> PooToolSpecPrototype PooToolSpec)
(defpoo-module-config-converter
  poo-flow-tool-core-poo-spec->tool-spec (spec)
  (constructor poo-flow-tool-spec)
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
(def (poo-flow-tool-core-poo-specs->tool-specs specs)
  (cond
   ((null? specs) '())
   ((pair? specs)
    (cons (poo-flow-tool-core-poo-spec->tool-spec (car specs))
          (poo-flow-tool-core-poo-specs->tool-specs (cdr specs))))
   (else
    (error "tool-core POO specs must be a list" specs))))

;; : (-> PooToolCatalogPrototype [PooToolSpec] PooToolCatalog)
(defpoo-module-config-converter
  poo-flow-tool-core-poo-catalog->catalog (catalog specs)
  (constructor poo-flow-tool-catalog)
  (arguments (slot catalog-ref)
             (value specs)
             (slot metadata)))

;; : (-> [POOObject] [POOObject])
(def (poo-flow-tool-core-poo-config-specs prototypes)
  (filter poo-flow-tool-core-poo-spec? prototypes))

;; : (-> [POOObject] [POOObject])
(def (poo-flow-tool-core-poo-config-catalogs prototypes)
  (filter poo-flow-tool-core-poo-catalog? prototypes))

;; : (-> PooToolSpec Alist)
(def (poo-flow-tool-core-catalog-manifest spec)
  (poo-flow-tool-handoff-manifest->alist
   (poo-flow-tool-handoff-manifest
    (string->symbol
     (string-append
      "tool/request/"
      (symbol->string (poo-flow-tool-spec-ref spec))))
    spec)))

;; : (-> [PooToolSpec] [Alist] [Alist])
(def (poo-flow-tool-core-catalog-manifests/rev specs manifests-rev)
  (if (null? specs)
    manifests-rev
    (poo-flow-tool-core-catalog-manifests/rev
     (cdr specs)
     (cons (poo-flow-tool-core-catalog-manifest (car specs))
           manifests-rev))))

;; : (-> PooToolCatalog [Alist])
(def (poo-flow-tool-core-catalog-manifests catalog)
  (reverse
   (poo-flow-tool-core-catalog-manifests/rev
    (.ref catalog 'tools)
    '())))

;; : (-> [POOObject] Alist [UserModuleFlagEntry])
(def (poo-flow-tool-core-poo-config-flags prototypes user-config)
  (let* ((specs
          (poo-flow-tool-core-poo-specs->tool-specs
           (poo-flow-tool-core-poo-config-specs prototypes)))
         (catalogs (poo-flow-tool-core-poo-config-catalogs prototypes))
         (catalog
          (if (null? catalogs)
            (poo-flow-tool-catalog 'tool-core/user specs)
            (poo-flow-tool-core-poo-catalog->catalog (car catalogs) specs))))
    (list '+catalog
          '+typed-receipts
          '+runtime-manifest
          (cons ':config (list catalog))
          (cons ':tool-catalog catalog)
          (cons ':tool-manifests
                (poo-flow-tool-core-catalog-manifests catalog))
          (cons ':user-config user-config))))

;; : [[PooUserModuleSelection]]
(def poo-flow-tool-core-module-bundles
  (list
   (poo-flow-user-module-bundle
    (session tool-core +catalog +typed-receipts +runtime-manifest))))
