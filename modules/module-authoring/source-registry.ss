;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: maintained and user module entrypoint registry.
;;; Invariant: maintained modules enter through validated public interfaces.

(import
        :tao3k/yuanxu/module-system/source/imports
        :tao3k/yuanxu/module-system/source/objects
        (only-in :tao3k/yuanxu/module-system/source/collection yuanxu-module-source-collection-interfaces)
        (only-in :agentic-ai-lab/modules/module-authoring/module-source-collection
                 agentic-ai-lab-maintained-module-source agentic-ai-lab-maintained-service-source agentic-ai-lab-maintained-integration-directories))

(export agentic-ai-lab-module-tree-source-refs
        agentic-ai-lab-modules-root
        agentic-ai-lab-module-system-source
        agentic-ai-lab-module-system-source-refs
        agentic-ai-lab-src-modules-source-refs
        agentic-ai-lab-user-tree-config-source)

;;; Boundary: tree entrypoints are source metadata, not filesystem reads.
;; : (-> Path Symbol Path)
(def (agentic-ai-lab-module-tree-entrypoint module-root-path entrypoint-role)
  (let* ((leaf (string-append (symbol->string entrypoint-role) ".ss"))
         (path-length (string-length module-root-path)))
    (if (and (> path-length 0)
             (char=? (string-ref module-root-path (- path-length 1)) #\/))
      (string-append module-root-path leaf)
      (string-append module-root-path "/" leaf))))

;;; Boundary: a module tree contributes one public interface entrypoint.
;; : (-> Path Symbol PooModuleSourceRef)
(def (agentic-ai-lab-module-tree-source module-root-path entrypoint-role)
  (let (entrypoint
        (agentic-ai-lab-module-tree-entrypoint module-root-path entrypoint-role))
    (make-yuanxu-module-source-ref
     'local
     entrypoint
     (list (cons 'kind 'module-tree)
           (cons 'module-tree-root module-root-path)
           (cons 'entrypoint entrypoint)
           (cons 'entrypoint-role entrypoint-role)))))

;; : (-> Path PooModuleSourceRef)
(def (agentic-ai-lab-module-tree-interface-source module-root-path)
  (agentic-ai-lab-module-tree-source module-root-path 'interface))

;; : (-> Path [PooModuleSourceRef])
(def (agentic-ai-lab-module-tree-source-refs module-root-path)
  (list (agentic-ai-lab-module-tree-interface-source module-root-path)))

;;; Boundary: modules is the maintained source collection root.
;; : Path
(def agentic-ai-lab-modules-root "modules")

;;; Boundary: framework source refs are explicit front-end entrypoints. They
;;; are metadata consumed by the Loader and never import their implementations.
;; : (-> Symbol Path PooModuleSourceRef)
(def (agentic-ai-lab-module-system-source entrypoint-role entrypoint-path)
  (let (entrypoint entrypoint-path)
    (make-yuanxu-module-source-ref
     'local
     entrypoint
     (list (cons 'kind 'framework-entrypoint)
           (cons 'entrypoint entrypoint)
           (cons 'entrypoint-role entrypoint-role)))))

;; : (-> Unit [PooModuleSourceRef])
(def (agentic-ai-lab-module-system-source-refs)
  (append (list
   (agentic-ai-lab-module-system-source
    'declaration-case "modules/workflow/scenario/configuration/declaration-case.ss"))
    ;; These owned front ends are importable entries, not four-role Modules.
    (map (lambda (name)
           (agentic-ai-lab-module-system-source 'interface
             (string-append "modules/" name "/interface.ss")))
         agentic-ai-lab-maintained-integration-directories)))

;;; Boundary: module registry member predicate is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooModuleRegistryValue [PooModuleRegistryValue] Boolean)
(def (agentic-ai-lab-module-registry-member? value values)
  (and (member value values) #t))

;;; Boundary: module registry alist ref default is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooModuleRegistryMetadata Symbol PooModuleRegistryMetadataValue PooModuleRegistryMetadataValue)
(def (agentic-ai-lab-module-registry-alist-ref/default entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;;; Boundary: upstream module sources are declared and lazy by default.
;; : (-> [PooModuleSourceRef])
(def (agentic-ai-lab-src-modules-source-refs)
  (append
   (yuanxu-module-source-collection-interfaces agentic-ai-lab-maintained-module-source)
   (yuanxu-module-source-collection-interfaces agentic-ai-lab-maintained-service-source)
   (agentic-ai-lab-module-system-source-refs)))

;;; Boundary: user-root trees have a different shape from upstream modules.
;; : (-> Path Symbol Path Path)
(def (agentic-ai-lab-user-tree-config-source user-root-path)
  (def path (path-expand "config.ss" user-root-path))
  (make-yuanxu-module-source-ref 'local path
    (list (cons 'entrypoint path) (cons 'entrypoint-role 'config) (cons 'source-owner 'user))))
