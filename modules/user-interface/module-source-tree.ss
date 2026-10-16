;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO Flow root and user module tree loading over Core lazy plans.
;;; Invariant: static entrypoint metadata lives in module-registry and stays loader-free.

(import (only-in :clan/poo/object .o)
        :poo-flow/modules/workflow/control-plane/failure
        (only-in :poo-flow/modules/module-authoring/module-interface
                 poo-flow-module-interface)
        (only-in :poo-flow/modules/module-authoring/module-source-admission
                 poo-flow-module-authoring-admit-port
                 poo-flow-module-authoring-admission-accepted?
                 poo-flow-module-authoring-admission-diagnostics)
        (only-in :poo-flow/modules/module-authoring/semantic-module
                 poo-flow-user-root-module-authoring-profile)
        :poo-flow/modules/module-authoring/module-imports
        :core/module-system/source/objects
        :poo-flow/modules/module-authoring/module-source-collection
        :poo-flow/modules/user-interface/module-source-selection
        :poo-flow/modules/user-interface/module-activation
        :core/module-system/catalog/objects
        :core/extension-graph/interface
        :core/module-system/loader/objects
        :poo-flow/modules/module-authoring/source-registry)

(export (import: :poo-flow/modules/module-authoring/source-registry)
        poo-flow-module-tree-lazy-load-plans
        poo-flow-src-modules-lazy-load-plans
        poo-flow-module-auto-import-root-identity
        poo-flow-module-auto-import-entry-node
        poo-flow-module-auto-imports-node
        poo-flow-module-auto-imports-resolve
        poo-flow-module-auto-imports-result-source-refs
        poo-flow-user-tree-config-authoring-validate!
        poo-flow-user-tree-lazy-load-plans
        poo-flow-module-selection-source-refs
        poo-flow-module-bundles-source-refs
        poo-flow-module-selection-lazy-load-plans
        poo-flow-module-bundles-lazy-load-plans
        poo-flow-module-load-source
        poo-flow-module-load-sources
        poo-flow-module-load-catalog)

;; : (-> [PooModuleLoaderBackend] [PooModuleSourceRef] Alist [PooFlowLazyLoadPlan] [PooFlowLazyLoadPlan])
(def (poo-flow-module-source-refs->lazy-load-plans/rev
      backends
      source-refs
      metadata
      plans-rev)
  (if (null? source-refs)
    plans-rev
    (poo-flow-module-source-refs->lazy-load-plans/rev
     backends
     (cdr source-refs)
     metadata
     (cons (poo-flow-make-lazy-load-plan backends
                                          (car source-refs)
                                          metadata)
           plans-rev))))

;; : (-> [PooModuleLoaderBackend] [PooModuleSourceRef] Alist [PooFlowLazyLoadPlan])
(def (poo-flow-module-source-refs->lazy-load-plans backends source-refs metadata)
  (reverse
   (poo-flow-module-source-refs->lazy-load-plans/rev
    backends
    source-refs
    metadata
    '())))

;;; Boundary: tree loading remains lazy data until callers force a plan.
;; : (-> [PooModuleLoaderBackend] Path [PooFlowLazyLoadPlan])
(def (poo-flow-module-tree-lazy-load-plans backends module-root-path
                                           . maybe-metadata)
  (let (metadata
        (if (null? maybe-metadata) '() (car maybe-metadata)))
    (poo-flow-module-source-refs->lazy-load-plans
     backends
     (poo-flow-module-tree-source-refs module-root-path)
     metadata)))

;;; Boundary: modules lazy plans never call loader handlers.
;; : (-> [PooModuleLoaderBackend] [PooFlowLazyLoadPlan])
(def (poo-flow-src-modules-lazy-load-plans backends . maybe-metadata)
  (let (metadata
        (if (null? maybe-metadata) '() (car maybe-metadata)))
    (poo-flow-module-source-refs->lazy-load-plans
     backends
     (poo-flow-src-modules-source-refs)
     metadata)))

;;; Boundary: the ordinary config root composes maintained values.  Admission
;;; reads inert Scheme data and rejects attempts to reopen the maintainer-only
;;; .def/.o layer before a lazy plan can expose the source.
;; : (-> Path PooModuleAuthoringAdmission)
(def (poo-flow-user-tree-config-authoring-validate! user-root-path)
  (let* ((source-ref (poo-flow-user-tree-config-source user-root-path))
         (path (poo-flow-module-source-ref-value source-ref))
         (interface
          (poo-flow-module-interface
           "user-root-config" (.o)
           '((source-owner . user))
           authoring: (poo-flow-user-root-module-authoring-profile)))
         (admission
          (call-with-input-file
           path
           (lambda (port)
             (poo-flow-module-authoring-admit-port
              interface 'config port)))))
    (unless (poo-flow-module-authoring-admission-accepted? admission)
      (error "POO-FLOW-MODULE-E010 user config must compose maintained values"
             path
             (car (poo-flow-module-authoring-admission-diagnostics
                   admission))))
    admission))

;;; Boundary: user-root tree loading is lazy and never evaluates init.ss or
;;; config.ss.  It does admit config.ss as inert data before publishing plans.
;; : (-> [PooModuleLoaderBackend] Path [PooFlowLazyLoadPlan])
(def (poo-flow-user-tree-lazy-load-plans backends user-root-path
                                         . maybe-metadata)
  (poo-flow-user-tree-config-authoring-validate! user-root-path)
  (let (metadata
        (if (null? maybe-metadata) '() (car maybe-metadata)))
    (poo-flow-module-source-refs->lazy-load-plans
     backends
     (poo-flow-user-tree-source-refs user-root-path)
     metadata)))

;; : (-> [PooModuleLoaderBackend] PooModuleLoadPath PooUserModuleSelection [PooFlowLazyLoadPlan])
(def (poo-flow-module-selection-lazy-load-plans backends load-path selection
                                                . maybe-metadata)
  (poo-flow-module-source-refs->lazy-load-plans
   backends
   (poo-flow-module-selection-source-refs load-path selection)
   (if (null? maybe-metadata) '() (car maybe-metadata))))

;; : (-> [PooModuleLoaderBackend] PooModuleLoadPath [[PooUserModuleSelection]] [PooFlowLazyLoadPlan])
(def (poo-flow-module-bundles-lazy-load-plans backends load-path module-bundles
                                              . maybe-metadata)
  (poo-flow-module-source-refs->lazy-load-plans
   backends
   (poo-flow-module-bundles-source-refs load-path module-bundles)
   (if (null? maybe-metadata) '() (car maybe-metadata))))

;;; Boundary: auto-import plans are POO nodes over source refs, not evaluator IO.
;; : PooFlowModuleAutoImportRootIdentity
(def poo-flow-module-auto-import-root-identity 'auto-imports)

;;; Boundary: loader alist ref default is the policy-visible edge for module-
;;; system behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> PooModuleLoaderMetadata Symbol PooModuleLoaderMetadataValue PooModuleLoaderMetadataValue)
(def (poo-flow-loader-alist-ref/default entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;;; Boundary: each source ref is an importable entrypoint node.
;; : (-> PooModuleSourceRef PooModuleExtensionNode)
(def (poo-flow-module-auto-import-entry-node source-ref)
  (let* ((metadata (poo-flow-module-source-ref-metadata source-ref))
         (entrypoint-role
          (poo-flow-loader-alist-ref/default metadata 'entrypoint-role #f))
         (tree-kind
          (poo-flow-loader-alist-ref/default metadata 'kind #f)))
    (poo-flow-module-extension-node
     (poo-flow-module-source-ref-value source-ref)
     (list (cons 'source-ref source-ref)
           (cons 'entrypoint-role entrypoint-role)
           (cons 'tree-kind tree-kind)
           (cons 'allowed-responsibilities
                 (poo-flow-loader-alist-ref/default
                  metadata
                  'allowed-responsibilities
                  '()))
           (cons 'denied-responsibilities
                 (poo-flow-loader-alist-ref/default
                  metadata
                  'denied-responsibilities
                  '()))
           (cons 'enabled? #t))
     '())))

;;; Boundary: auto-import roots are POO graphs so extensions can remove entries.
;; : (-> [PooModuleSourceRef] PooModuleExtensionNode)
(def (poo-flow-module-auto-imports-node source-refs)
  (poo-flow-module-extension-node
   poo-flow-module-auto-import-root-identity
   '((namespace . auto-imports))
   (map poo-flow-module-auto-import-entry-node source-refs)))

;;; Boundary: disabling an auto import is a regular node-remove contribution.
;; : (-> [PooModuleSourceRef] [PooModuleExtensionContribution] PooModuleExtensionResult)
(def (poo-flow-module-auto-imports-resolve source-refs contributions)
  (poo-flow-module-extension-resolve
   (poo-flow-module-auto-imports-node source-refs)
   contributions))

;; : (-> PooModuleExtensionNode MaybePooModuleSourceRef)
(def (poo-flow-module-auto-import-entry-source-ref entry-node)
  (poo-flow-loader-alist-ref/default
   (poo-flow-module-extension-node-slots entry-node)
   'source-ref
   #f))

;;; Boundary: resolved source refs are read after POO removals/extensions apply.
;; : (-> PooModuleExtensionResult [PooModuleSourceRef])
(def (poo-flow-module-auto-imports-result-source-refs result)
  (let (root (poo-flow-module-extension-result-root result))
    (map poo-flow-module-auto-import-entry-source-ref
         (poo-flow-module-extension-node-children root))))

;;; Boundary: strict loading raises typed failures before resolver activation.
;; : (-> [PooModuleLoaderBackend] PooModuleSourceRef PooModuleDescriptor)
(def (poo-flow-module-load-source backends source-ref)
  (let (receipt (poo-flow-module-load-source-receipt backends source-ref))
    (if (poo-flow-module-load-receipt-loaded? receipt)
      (poo-flow-module-load-receipt-module receipt)
      (raise-control-plane-failure
       'module-system
       'missing-module-loader
       "poo module source was not loaded by any backend"
       (list (cons 'source (poo-flow-module-source-ref->alist source-ref))
             (cons 'receipt (poo-flow-module-load-receipt->alist receipt)))))))

;;; Boundary: multi-source loading preserves requested source order.
;; : (-> [PooModuleLoaderBackend] [PooModuleSourceRef] [PooModuleDescriptor])
(def (poo-flow-module-load-sources backends source-refs)
  (if (null? source-refs)
    '()
    (cons (poo-flow-module-load-source backends (car source-refs))
          (poo-flow-module-load-sources backends (cdr source-refs)))))

;;; Boundary: loaded catalogs hand descriptor data to the existing resolver owner.
;; : (-> CatalogName [PooModuleLoaderBackend] [PooModuleSourceRef] PooModuleCatalog)
(def (poo-flow-module-load-catalog catalog-name backends source-refs)
  (make-poo-flow-module-catalog
   catalog-name
   (map make-poo-flow-module-catalog-entry
        source-refs
        (poo-flow-module-load-sources backends source-refs))))
