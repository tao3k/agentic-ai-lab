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
        (only-in :core/module-system/authoring/admission
                 poo-flow-module-authoring-admit-port
                 poo-flow-module-authoring-admission-accepted?
                 poo-flow-module-authoring-admission-diagnostics)
        (only-in :poo-flow/modules/module-authoring/semantic-module poo-flow-user-root-module-authoring-profile)
        :core/module-system/source/imports
        :core/module-system/source/objects
        :core/module-system/source/collection
        (only-in :poo-flow/modules/module-authoring/module-source-collection make-poo-flow-contribution-module-load-path poo-flow-default-module-load-path poo-flow-maintained-module-source)
        :poo-flow/modules/workflow/scenario/configuration/module-source-selection
        :poo-flow/modules/workflow/scenario/configuration/module-activation
        :core/module-system/catalog/objects
        :core/module-system/source/projection
        :core/module-system/loader/objects
        :poo-flow/modules/module-authoring/source-registry)

(export (import: :poo-flow/modules/module-authoring/source-registry)
        poo-flow-module-tree-lazy-load-plans
        poo-flow-src-modules-lazy-load-plans
        poo-flow-user-tree-config-authoring-validate!
        poo-flow-user-tree-lazy-load-plans
        poo-flow-module-selection-source-refs
        poo-flow-module-bundles-source-refs
        poo-flow-module-selection-lazy-load-plans
        poo-flow-module-bundles-lazy-load-plans
        poo-flow-module-load-source
        poo-flow-module-load-sources
        poo-flow-module-load-catalog)

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
