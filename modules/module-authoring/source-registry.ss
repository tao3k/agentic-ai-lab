;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: maintained and user module entrypoint registry.
;;; Invariant: maintained modules enter through validated public interfaces.

(import
        :core/module-system/source/imports
        :core/module-system/source/objects
        (only-in :core/module-system/source/collection poo-flow-module-source-collection-interfaces)
        (only-in :poo-flow/modules/module-authoring/module-source-collection poo-flow-maintained-module-source))

(export poo-flow-module-tree-source-refs
        poo-flow-modules-root
        poo-flow-module-system-source
        poo-flow-module-system-source-refs
        poo-flow-src-modules-source-refs
        poo-flow-user-tree-source
        poo-flow-user-tree-entrypoint-policy
        poo-flow-user-tree-source-allowed-responsibilities
        poo-flow-user-tree-source-denied-responsibilities
        poo-flow-user-tree-source-allows?
        poo-flow-user-tree-source-policy-violations
        poo-flow-user-tree-source-valid?
        poo-flow-user-tree-init-source
        poo-flow-user-tree-config-source
        poo-flow-user-tree-source-refs)

;;; Boundary: tree entrypoints are source metadata, not filesystem reads.
;; : (-> Path Symbol Path)
(def (poo-flow-module-tree-entrypoint module-root-path entrypoint-role)
  (let* ((leaf (string-append (symbol->string entrypoint-role) ".ss"))
         (path-length (string-length module-root-path)))
    (if (and (> path-length 0)
             (char=? (string-ref module-root-path (- path-length 1)) #\/))
      (string-append module-root-path leaf)
      (string-append module-root-path "/" leaf))))

;;; Boundary: a module tree contributes one public interface entrypoint.
;; : (-> Path Symbol PooModuleSourceRef)
(def (poo-flow-module-tree-source module-root-path entrypoint-role)
  (let (entrypoint
        (poo-flow-module-tree-entrypoint module-root-path entrypoint-role))
    (make-poo-flow-module-source-ref
     'local
     entrypoint
     (list (cons 'kind 'module-tree)
           (cons 'module-tree-root module-root-path)
           (cons 'entrypoint entrypoint)
           (cons 'entrypoint-role entrypoint-role)))))

;; : (-> Path PooModuleSourceRef)
(def (poo-flow-module-tree-interface-source module-root-path)
  (poo-flow-module-tree-source module-root-path 'interface))

;; : (-> Path [PooModuleSourceRef])
(def (poo-flow-module-tree-source-refs module-root-path)
  (list (poo-flow-module-tree-interface-source module-root-path)))

;;; Boundary: modules is the maintained source collection root.
;; : Path
(def poo-flow-modules-root "modules")

;;; Boundary: framework source refs are explicit front-end entrypoints. They
;;; are metadata consumed by the Loader and never import their implementations.
;; : (-> Symbol Path PooModuleSourceRef)
(def (poo-flow-module-system-source entrypoint-role entrypoint-path)
  (let (entrypoint entrypoint-path)
    (make-poo-flow-module-source-ref
     'local
     entrypoint
     (list (cons 'kind 'framework-entrypoint)
           (cons 'entrypoint entrypoint)
           (cons 'entrypoint-role entrypoint-role)))))

;; : (-> Unit [PooModuleSourceRef])
(def (poo-flow-module-system-source-refs)
  (list
   (poo-flow-module-system-source
    'profile-config "modules/workflow/scenario/configuration/profile-config.ss")
   (poo-flow-module-system-source
    'init-syntax "modules/workflow/scenario/configuration/init-syntax.ss")
   (poo-flow-module-system-source
    'root-profile "modules/workflow/scenario/configuration/root-profile.ss")
   (poo-flow-module-system-source
    'declaration-case "modules/workflow/scenario/configuration/declaration-case.ss")))

;;; Boundary: module registry member predicate is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooModuleRegistryValue [PooModuleRegistryValue] Boolean)
(def (poo-flow-module-registry-member? value values)
  (and (member value values) #t))

;;; Boundary: module registry alist ref default is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooModuleRegistryMetadata Symbol PooModuleRegistryMetadataValue PooModuleRegistryMetadataValue)
(def (poo-flow-module-registry-alist-ref/default entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;;; Boundary: upstream module sources are declared and lazy by default.
;; : (-> [PooModuleSourceRef])
(def (poo-flow-src-modules-source-refs)
  (append
   (poo-flow-module-source-collection-interfaces poo-flow-maintained-module-source)
   (poo-flow-module-system-source-refs)))

;;; Boundary: user-root trees have a different shape from upstream modules.
;; : (-> Path Symbol Path Path)
(def (poo-flow-user-tree-entrypoint user-root-path entrypoint-role entrypoint-path)
  (let (path-length (string-length user-root-path))
    (if (and (> path-length 0)
             (char=? (string-ref user-root-path (- path-length 1)) #\/))
      (string-append user-root-path entrypoint-path)
      (string-append user-root-path "/" entrypoint-path))))

;;; Boundary: entrypoint policy is data so loaders and tools can reject misuse.
;; : (-> Symbol Alist)
(def (poo-flow-user-tree-entrypoint-policy entrypoint-role)
  (cond
   ((eq? entrypoint-role 'init)
    '((policy . init-switches-only)
      (allowed-responsibilities
       . (module-switch feature-switch module-category-switch
          custom-module-switch))
      (denied-responsibilities
       . (profile-selection object-contract field-contract
          sandbox-profile-recipe settings package-sync descriptor-realization
          runtime-execution facade-export))))
   ((eq? entrypoint-role 'config)
    '((policy . composition-declarations-only)
      (allowed-responsibilities
       . (composition-declaration profile-use scenario-use facade-export))
      (denied-responsibilities
       . (module-switch feature-switch object-contract field-contract
          package-sync descriptor-realization runtime-execution
          module-implementation))))
   (else
    '((policy . unknown-entrypoint)
      (allowed-responsibilities . ())
      (denied-responsibilities . (runtime-execution package-sync))))))

;;; Boundary: user-root source refs cover the two Doom-style entrypoints.
;; : (-> Path Symbol Path PooModuleSourceRef)
(def (poo-flow-user-tree-source user-root-path entrypoint-role entrypoint-path)
  (let* ((entrypoint
          (poo-flow-user-tree-entrypoint user-root-path
                                         entrypoint-role
                                         entrypoint-path))
         (policy
          (poo-flow-user-tree-entrypoint-policy entrypoint-role)))
    (make-poo-flow-module-source-ref
     'local
     entrypoint
     (append
      (list (cons 'kind 'user-tree)
            (cons 'user-tree-root user-root-path)
            (cons 'entrypoint entrypoint)
            (cons 'entrypoint-role entrypoint-role))
      policy))))

;; : (-> PooModuleSourceRef [Symbol])
(def (poo-flow-user-tree-source-allowed-responsibilities source-ref)
  (poo-flow-module-registry-alist-ref/default
   (poo-flow-module-source-ref-metadata source-ref)
   'allowed-responsibilities
   '()))

;; : (-> PooModuleSourceRef [Symbol])
(def (poo-flow-user-tree-source-denied-responsibilities source-ref)
  (poo-flow-module-registry-alist-ref/default
   (poo-flow-module-source-ref-metadata source-ref)
   'denied-responsibilities
   '()))

;; : (-> PooModuleSourceRef Symbol Boolean)
(def (poo-flow-user-tree-source-allows? source-ref responsibility)
  (and
   (poo-flow-module-registry-member?
    responsibility
    (poo-flow-user-tree-source-allowed-responsibilities source-ref))
   (not
    (poo-flow-module-registry-member?
     responsibility
     (poo-flow-user-tree-source-denied-responsibilities source-ref)))))

;;; Boundary: user tree source policy violations is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (forall (a) (-> PooModuleSourceRef [a] [a]))
;; : (-> PooModuleSourceRef [Symbol] [Symbol])
(def (poo-flow-user-tree-source-policy-violations source-ref responsibilities)
  (filter (lambda (responsibility)
            (not (poo-flow-user-tree-source-allows?
                  source-ref
                  responsibility)))
          responsibilities))

;; : (-> PooModuleSourceRef [Symbol] Boolean)
(def (poo-flow-user-tree-source-valid? source-ref responsibilities)
  (null? (poo-flow-user-tree-source-policy-violations source-ref
                                                      responsibilities)))

;; : (-> Path PooModuleSourceRef)
(def (poo-flow-user-tree-init-source user-root-path)
  (poo-flow-user-tree-source user-root-path 'init "init.ss"))

;; : (-> Path PooModuleSourceRef)
(def (poo-flow-user-tree-config-source user-root-path)
  (poo-flow-user-tree-source user-root-path 'config "config.ss"))

;; : (-> Path [PooModuleSourceRef])
(def (poo-flow-user-tree-source-refs user-root-path)
  (list (poo-flow-user-tree-init-source user-root-path)
        (poo-flow-user-tree-config-source user-root-path)))
