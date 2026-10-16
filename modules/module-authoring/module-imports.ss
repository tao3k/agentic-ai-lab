;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO Flow import conventions over Core SourceRef identities.
;;; Invariant: imports describe source refs or inline profiles.
;;; They never load files, query registries, or evaluate modules.
;;; Intent: callers can inspect provenance and profile payloads before any loader exists.
;;; Ownership: Core owns SourceRef identity; this file owns product import
;;; forms and custom source conventions consumed by descriptors and catalogs.
;;; Descriptors may inspect the profile slot to expand inline modules.
;;; Catalogs may compare source refs by kind/value for deterministic lookup.
;;; Future loader backends must consume these values from outside this owner.
;;; Agents should import Core for SourceRef mechanics and this module for
;;; POO Flow import conventions.
;;; No function here may read a path, query a registry, or evaluate a profile.
;; | SourceRefValue = Path | Symbol | PooModuleSourceRef | Value
;; | PooModuleSourceRefCandidate = Value

(import (only-in :clan/poo/object .o .ref .slot? object?)
        :poo-flow/modules/module-authoring/module-interface
        :core/module-system/source/objects)

(export make-poo-flow-module-custom-interface-source
        make-poo-flow-module-custom-collection-source
        poo-flow-module-custom-interface-entrypoint
        poo-flow-local-source
        poo-flow-custom-source
        poo-flow-standard-library-source
        poo-flow-source-ref
        poo-flow-module-import-source-ref?
        poo-flow-module-import-local-source?
        poo-flow-module-import-normalize-source
        poo-flow-import
        poo-flow-imports
        poo-flow-imports-append
        poo-flow-extensions
        poo-flow-extensions-append
        poo-flow-import?)

;;; Boundary: custom module directories are user-owned; the module-system only
;;; records the interface.ss entrypoint that a future loader may consume.
;; : (-> Path Path)
(def (poo-flow-module-custom-interface-entrypoint module-root-path)
  (let ((path-length (string-length module-root-path)))
    (if (and (> path-length 0)
             (char=? (string-ref module-root-path (- path-length 1)) #\/))
      (string-append module-root-path "interface.ss")
      (string-append module-root-path "/interface.ss"))))

;;; Boundary: custom sources stay local source refs so loader matching remains
;;; deterministic; root/entrypoint details live in metadata.
;; : (-> Path PooModuleSourceRef)
(def (make-poo-flow-module-custom-interface-source module-root-path)
  (let ((entrypoint
         (poo-flow-module-custom-interface-entrypoint module-root-path)))
    (make-poo-flow-module-source-ref 'local entrypoint
                                     (list
                                      (cons 'kind
                                            poo-flow-module-import-local-source-kind)
                                      (cons 'custom-module-root module-root-path)
                                      (cons 'entrypoint entrypoint)
                                      (cons 'entrypoint-role 'interface)))))

;;; Boundary: an explicit @ modules path selects a directory collection. The
;;; loader expands its direct child module trees; the declaration macro does no
;;; filesystem discovery itself.
;; : (-> Path PooModuleSourceRef)
(def (make-poo-flow-module-custom-collection-source modules-root-path)
  (make-poo-flow-module-source-ref
   'local
   modules-root-path
   (list (cons 'kind 'custom-module-collection)
         (cons 'modules-root modules-root-path)
         (cons 'entrypoint-role 'discover))))

;;; Boundary: import-local sources are catalog-compatible source refs.
;; : (-> Path PooModuleSourceRef)
(def (poo-flow-local-source source-path)
  (make-poo-flow-module-source-ref 'local source-path
                                   (list (cons 'kind poo-flow-module-import-local-source-kind))))

;;; Boundary: user-facing shorthand for a custom module directory.
;; : (-> Path PooModuleSourceRef)
(def (poo-flow-custom-source module-root-path)
  (make-poo-flow-module-custom-interface-source module-root-path))

;;; Boundary: shorthand for upstream standard-library module source refs.
;; : (-> Symbol PooModuleSourceRef)
(def (poo-flow-standard-library-source module-name)
  (make-poo-flow-module-standard-library-source module-name))

;;; Boundary: arbitrary source values are wrapped without interpretation.
;; : (-> SourceRefInput PooModuleSourceRef)
(def (poo-flow-source-ref source-value)
  (cond
   ((poo-flow-module-source-ref? source-value) source-value)
   (else
    (make-poo-flow-module-source-ref
     'source
     source-value
     (list (cons 'kind poo-flow-module-import-source-ref-kind))))))

;; : (-> SourceRefInput Boolean)
(def (poo-flow-module-import-source-ref? value)
  (poo-flow-module-source-ref? value))

;; : (-> SourceRefInput Boolean)
(def (poo-flow-module-import-local-source? value)
  (and (poo-flow-module-source-ref? value)
       (eq? (poo-flow-module-source-ref-kind value) 'local)))

;;; Boundary: module import normalize source is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> SourceRefInput PooModuleSourceRef)
(def (poo-flow-module-import-normalize-source source-value)
  (cond
   ((string? source-value)
    (poo-flow-local-source source-value))
   ((poo-flow-module-import-source-ref? source-value)
    source-value)
   (else
    (poo-flow-source-ref source-value))))

;;; Boundary: import values keep source identity separate from profile payloads.
;;; Intent: a source/profile pair can be resolved or projected without parsing a file path.
;; : (-> MaybePooModuleSourceRef ModuleImportProfile PooImport)
(def (make-poo-flow-import source-ref-value profile-value)
  (.o kind: poo-flow-module-import-kind
      source-ref: source-ref-value
      profile: profile-value))

;;; Boundary: one-arg import is profile-only, two-arg import binds source+profile.
;; : (-> ModuleImportArg... PooImport)
(def (poo-flow-import . import-values)
  (cond
   ;; Profile-only imports are already in-memory module/profile values.
   ((= (length import-values) 1)
    (make-poo-flow-import #f (car import-values)))
   ;; Source/profile imports preserve source identity without invoking a loader.
   ((= (length import-values) 2)
    (make-poo-flow-import
     (poo-flow-module-import-normalize-source (car import-values))
     (cadr import-values)))
   (else
    (error "poo-flow-import expects profile or source/profile"))))

;;; Boundary: import lists preserve caller order for closure expansion.
;; : (-> ModuleImportValue... [ModuleImportValue])
(def (poo-flow-imports . import-values)
  import-values)

;;; Boundary: inherited imports are prepended before direct imports.
;; : (-> [PooImport] [PooImport] [PooImport])
(def (poo-flow-imports-append inherited-imports direct-imports)
  (append inherited-imports direct-imports))

;;; Boundary: extensions stay first-class values until projection.
;; : (-> ModuleExtension... [ModuleExtension])
(def (poo-flow-extensions . extension-values)
  extension-values)

;;; Boundary: inherited extensions are prepended before direct extensions.
;; : (-> [ModuleExtension] [ModuleExtension] [ModuleExtension])
(def (poo-flow-extensions-append inherited-extensions direct-extensions)
  (append inherited-extensions direct-extensions))

;; : (-> ModuleImportCandidate Boolean)
(def (poo-flow-import? value)
  (and (object? value)
       (.slot? value 'kind)
       (poo-flow-module-kind=? (.ref value 'kind) poo-flow-module-import-kind)))
