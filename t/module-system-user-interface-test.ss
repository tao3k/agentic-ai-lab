;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: this integration test imports precise Module System and User
;;; Interface owners without a module-system aggregate.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        (only-in :clan/poo/object .o .ref .slot?)
        :poo-flow/modules/module-authoring/module-interface
        :core/module-system/selection/objects
        :poo-flow/modules/module-authoring/module-descriptor
        :core/module-system/source/collection
        (only-in :poo-flow/modules/module-authoring/module-source-collection make-poo-flow-contribution-module-load-path poo-flow-default-module-load-path poo-flow-maintained-module-source)
        :poo-flow/modules/workflow/scenario/configuration/module-source-tree
        :poo-flow/modules/module-authoring/module-option-projection
        :poo-flow/modules/workflow/scenario/configuration/module-runtime-presentation
        :core/module-system/catalog/values
        :core/module-system/loader/objects
        :core/module-system/projection/option-objects
        :core/module-system/projection/option-validation
        :poo-flow/modules/workflow/scenario/configuration/module-diagnostics
        :poo-flow/modules/workflow/scenario/configuration/doctor-presentation
        :core/module-system/source/imports
        :core/module-system/source/objects
        :core/module-system/funs
        :poo-flow/modules/workflow/scenario/configuration/module-activation
        :core/module-system/catalog/objects
        :core/module-system/authoring/syntax
        :poo-flow/modules/workflow/scenario/configuration/interface)

(export module-system-user-interface-test)

;; : (-> Unit PooModuleInterface)
(def user-child-interface
  (poo-flow-module-interface
   "UserChildProfile"
   (poo-flow-module-option-block
    surface: (poo-flow-string-constant "poo-flow")
    child-mode: (poo-flow-string-default "helper")
    layers: (poo-flow-option-append 'List '("base"))
    priority: (poo-flow-option-override 'String "base")
    mode-lock: (poo-flow-option-conflict 'String))
   '((audience . user))))

;; : (-> Unit PooModuleDescriptor)
(def user-child-module
  (pooFlowModules
   user-child-interface
   (.o id: 'user-child
       group: 'tools
       flags: '(+helper)
       features: '(child-profile)
       depth: (cons -20 20)
       phase-files: '((init . "child/init.ss")
                      (config . "child/config.ss"))
       config: (poo-flow-module-option-block
                surface: "poo-flow"
                child-mode: "helper"
                layers: '("child")
                priority: "child"
                mode-lock: "stable")
       hooks: (poo-flow-module-hook-block
               (after-config child-ready)))))

;; : (-> Unit PooModuleInterface)
(def user-root-interface
  (poo-flow-module-interface
   "UserRootProfile"
   (poo-flow-module-option-block
    surface: (poo-flow-string-constant "poo-flow")
    mode: (poo-flow-string-default "interactive")
    layers: (poo-flow-option-append 'List '("base"))
    priority: (poo-flow-option-override 'String "base")
    mode-lock: (poo-flow-option-conflict 'String))
   '((audience . user)
     (surface . module-system))))

;; : (-> Unit PooModuleDescriptor)
(defpoo-flow-module user-root-module
  user-root-interface
  (id 'user-root)
  (imports (poo-flow-import ":user/root#child" user-child-module))
  (config (poo-flow-module-option-block
           surface: "poo-flow"
           mode: "interactive"
           layers: '("root")
           priority: "root"
           mode-lock: "stable"))
  (extensions 'root-extension)
  (scripts 'root-script)
  (metadata '((audience . user)
              (owner . public-interface))))

;; : (-> Unit PooModuleDescriptor)
(def invalid-user-module
  (pooFlowModules
   user-root-interface
   (.o id: 'invalid-user
       config: (poo-flow-module-option-block
                surface: "wrong-surface"
                unknown-option: "left-unclaimed"))))

;; : (-> Unit PooModuleSourceRef)
(def loader-child-source
  (poo-flow-local-source "loaded/child.ss"))

;; : (-> Unit PooModuleSourceRef)
(def loader-root-source
  (poo-flow-local-source "loaded/root.ss"))

;; : (-> Unit PooModuleSourceRef)
(def loader-missing-source
  (poo-flow-local-source "loaded/missing.ss"))

;; : (-> Unit PooModuleDescriptor)
(def loader-child-module
  (make-empty-poo-flow-module-descriptor
   'loaded-child
   '()
   '((loaded-child . #t))))

;; : (-> Unit PooModuleDescriptor)
(def loader-root-module
  (make-empty-poo-flow-module-descriptor
   'loaded-root
   '(loaded-child)
   '((loaded-root . #t))))

;; : (-> Unit PooModuleLoaderBackend)
(def user-static-loader
  (poo-flow-module-static-loader
   'user-static-loader
   'local
   (list (make-poo-flow-module-loader-entry loader-root-source
                                            loader-root-module)
         (make-poo-flow-module-loader-entry loader-child-source
                                            loader-child-module))))

;; : (-> Unit PooModuleValueCatalog)
(def user-catalog
  (pooFlowModuleCatalog user-root-module invalid-user-module))

;; : (-> Unit PooModuleValueCatalog)
(defpoo-flow-module-set user-macro-catalog
  (modules user-root-module)
  (poo-flow-module-when #t user-child-module)
  (poo-flow-module-when #f invalid-user-module))

;; : (-> Identifier Syntax)
(defpoo-flow-module-object-block poo-flow-module-user-block)

;; : (-> Unit POOObject)
(def user-generated-poo-block
  (poo-flow-module-user-block
   generated: "poo-flow"
   policy: 'slot-based))

;; : (-> Unit POOObject)
(def user-generated-hook-block
  (poo-flow-module-hook-block
   (before-init prepare-state)
   (after-config child-ready)))

;; : (-> UserInterfaceEntry [UserInterfaceEntry] Boolean)
(def (has-member? value values)
  (not (not (member value values))))

;; : (-> Unit TestSuite)
;;; This suite guards the compact user-facing module syntax from depending on
;;; internal loader or registry owners.
(def module-system-user-interface-test
  (test-suite "poo-flow module system user interface"
    (poo-flow-test-case "declares modules through explicit public owners"
      (check-equal? (poo-flow-module-descriptor? user-root-module) #t)
      (check-equal? (poo-flow-module-name user-root-module) 'user-root)
      (check-equal? (poo-flow-module-interface-id
                     (poo-flow-module-interface-object user-root-module))
                    "UserRootProfile")
      (check-equal? (poo-flow-module-group user-root-module)
                    poo-flow-brand-group)
      (let* ((imports (poo-flow-module-imports user-root-module))
             (first-import (car imports))
             (source-ref (.ref first-import 'source-ref)))
        (check-equal? (length imports) 1)
        (check-equal? (poo-flow-import? first-import) #t)
        (check-equal? (poo-flow-module-source-ref-kind source-ref) 'local)
        (check-equal? (poo-flow-module-source-ref-value source-ref)
                      ":user/root#child")
        (check-equal? (.ref first-import 'profile) user-child-module))
      (check-equal? (poo-flow-module-extensions user-root-module)
                    '(root-extension))
      (check-equal? (poo-flow-module-scripts user-root-module)
                    '(root-script))
      (check-equal? (poo-flow-module-metadata user-root-module)
                    '((audience . user)
                      (owner . public-interface))))
    (poo-flow-test-case "exposes Doom-style user predicates as explicit data checks"
      (check-equal? (poo-flow-module-group user-child-module) 'tools)
      (check-equal? (poo-flow-module-flags user-child-module) '(+helper))
      (check-equal? (poo-flow-module-features user-child-module)
                    '(child-profile))
      (check-equal? (poo-flow-module-depth-value user-child-module 'init) -20)
      (check-equal? (poo-flow-module-depth-value user-child-module 'config) 20)
      (check-equal? (poo-flow-module-phase-file user-child-module 'config)
                    "child/config.ss")
      (check-equal? (poo-flow-module-hook-values user-child-module 'after-config)
                    '(child-ready))
      (check-equal? (poo-flow-module-active? user-child-module '+helper '-missing)
                    #t)
      (check-equal? (poo-flow-module-active? user-child-module '+missing)
                    #f)
      (check-equal? (poo-flow-module-value-catalog-active? user-catalog 'user-root)
                    #t)
      (check-equal? (poo-flow-module-value-catalog-active? user-catalog 'user-child)
                    #f)
      (check-equal? (poo-flow-module-value-catalog-active? user-catalog 'invalid-user '+helper)
                    #f))
    (poo-flow-test-case "projects catalog eval and presentation for users"
      (let* ((workflow (poo-flow-module-workflow user-root-module '("after-config")))
             (evaluation (poo-flow-module-evaluate user-root-module))
             (eval-result (pooFlowEvalModules user-catalog 'user-root '("after-config")))
             (presentation
              (pooFlowModuleSystemPresentation
               user-catalog
               'user-root
               '("after-config"))))
        (check-equal? (.ref workflow 'kind) poo-flow-module-workflow-kind)
        (check-equal? (.ref evaluation 'module-ids) '(user-root user-child))
        (check-equal? (.ref evaluation 'init-module-ids)
                      '(user-child user-root))
        (check-equal? (.ref eval-result 'root-module-id) 'user-root)
        (check-equal? (.ref eval-result 'module-count) 2)
        (check-equal? (.ref eval-result 'hook-count) 1)
        (check-equal? (.ref presentation 'catalog-module-count) 2)
        (check-equal? (.ref presentation 'root-module-id) 'user-root)
        (check-equal? (.ref presentation 'brand-name) poo-flow-brand-name)
        (check-equal? (has-member? "poo-flow-module-value-catalog-active?"
                                   (.ref presentation 'user-entrypoints))
      #t)))
    (poo-flow-test-case "returns validation receipts for user config mistakes"
      (let* ((receipts
              (poo-flow-module-option-validation-receipts invalid-user-module))
             (codes
              (map poo-flow-module-option-validation-receipt-code receipts)))
        (check-equal? (length receipts) 2)
        (check-equal? (has-member? 'constant-mismatch codes) #t)
        (check-equal? (has-member? 'missing-schema codes) #t)))
    (poo-flow-test-case "loads source refs into catalogs before resolver activation"
      (let* ((sources (list loader-root-source loader-child-source))
             (backends (list user-static-loader))
             (receipts
              (poo-flow-module-load-source-receipts backends sources))
             (catalog
              (poo-flow-module-load-catalog 'loaded-user-catalog
                                            backends
                                            sources))
            (doctor
              (poo-flow-module-resolve-doctor catalog sources))
             (activation
              (poo-flow-module-resolve-and-activate catalog sources)))
        (check-equal? (map poo-flow-module-load-receipt-code receipts)
                      '(loaded loaded))
        (check-equal? (map poo-flow-module-load-receipt-backend-name receipts)
                      '(user-static-loader user-static-loader))
        (check-equal? (poo-flow-module-catalog-name catalog)
                      'loaded-user-catalog)
        (check-equal? (map poo-flow-module-name
                           (poo-flow-module-catalog-modules catalog))
                      '(loaded-root loaded-child))
        (check-equal? (poo-flow-module-doctor-report-status doctor)
                      'warning)
        (check-equal? (poo-flow-module-names
                       (poo-flow-module-activation-modules activation))
                      '(loaded-root loaded-child))))
    (poo-flow-test-case "presents doctor evidence without runtime execution"
      (let* ((doctor-presentation
              (pooFlowModuleDoctorPresentation user-catalog 'user-root))
             (source-presentation
              (pooFlowModuleSourceDoctorPresentation
               (list user-static-loader)
               (list loader-root-source loader-child-source)))
             (missing-source-presentation
              (pooFlowModuleSourceDoctorPresentation
               (list user-static-loader)
               (list loader-missing-source)))
             (source-doctor
              (.ref source-presentation 'module-doctor)))
        (check-equal? (.ref doctor-presentation 'kind)
                      poo-flow-module-doctor-presentation-kind)
        (check-equal? (.ref doctor-presentation 'root-module-id)
                      'user-root)
        (check-equal? (.ref doctor-presentation 'runtime-executed)
                      #f)
        (check-equal? (.ref doctor-presentation 'brand-name)
                      poo-flow-brand-name)
        (check-equal? (.ref doctor-presentation 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (.ref source-presentation 'kind)
                      poo-flow-module-source-doctor-presentation-kind)
        (check-equal? (.ref source-presentation 'loaded-count) 2)
        (check-equal? (.ref source-presentation 'load-status) 'ok)
        (check-equal? (.ref source-presentation 'brand-name)
                      poo-flow-brand-name)
        (check-equal? (.ref missing-source-presentation 'loaded-count) 0)
        (check-equal? (.ref missing-source-presentation 'missing-count) 1)
        (check-equal? (.ref missing-source-presentation 'load-status) 'error)
        (check-equal? (.ref missing-source-presentation 'module-doctor) #f)
        (check-equal? (.ref missing-source-presentation 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (.ref source-doctor 'root-module-id)
                      'loaded-root)))
    (poo-flow-test-case "uses Gerbil-hosted higher-order macros for POO blocks"
      (check-equal? (not
                     (not
                      (.slot? user-generated-poo-block 'generated)))
                    #t)
      (check-equal? (.ref user-generated-poo-block 'generated)
                    "poo-flow")
      (check-equal? (.ref user-generated-poo-block 'policy)
                    'slot-based)
      (check-equal? (not
                     (not
                      (.slot? user-generated-hook-block 'before-init)))
                    #t)
      (check-equal? (.ref user-generated-hook-block 'before-init)
                    '(prepare-state))
      (check-equal? (.ref user-generated-hook-block 'after-config)
                    '(child-ready)))
    (poo-flow-test-case "builds module sets with Gerbil macro authoring"
      (let* ((modules (.ref user-macro-catalog 'modules))
             (eval-result (pooFlowEvalModules user-macro-catalog 'user-root)))
        (check-equal? (length modules) 2)
        (check-equal? (map poo-flow-module-name modules)
                      '(user-root user-child))
        (check-equal? (poo-flow-module-value-catalog-active? user-macro-catalog
                                                             'user-child
                                                             '+helper)
                      #t)
        (check-equal? (poo-flow-module-value-catalog-active? user-macro-catalog 'invalid-user)
                      #f)
        (check-equal? (.ref eval-result 'module-count) 2))))
  )
