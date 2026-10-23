;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: this integration test imports precise Module System and User
;;; Interface owners without a module-system aggregate.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
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
        :agentic-ai-lab/modules/module-authoring/module-interface
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :yuanxu/module-system/source/collection
        (only-in :agentic-ai-lab/modules/module-authoring/module-source-collection make-agentic-ai-lab-contribution-module-load-path agentic-ai-lab-default-module-load-path agentic-ai-lab-maintained-module-source)
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-source-tree
        :agentic-ai-lab/modules/module-authoring/module-option-projection
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-runtime-presentation
        :yuanxu/module-system/catalog/values
        :yuanxu/module-system/loader/objects
        :yuanxu/module-system/projection/option-objects
        :yuanxu/module-system/projection/option-validation
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-diagnostics
        :agentic-ai-lab/modules/workflow/scenario/configuration/doctor-presentation
        :yuanxu/module-system/source/imports
        :yuanxu/module-system/source/objects
        :yuanxu/module-system/funs
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-activation
        :yuanxu/module-system/catalog/objects
        :yuanxu/module-system/authoring/syntax
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface)

(export module-system-user-interface-test)

;; : (-> Unit PooModuleInterface)
(def user-child-interface
  (yuanxu-module-interface
   "UserChildProfile"
   (yuanxu-module-option-block
    surface: (yuanxu-string-constant "agentic-ai-lab")
    child-mode: (yuanxu-string-default "helper")
    layers: (yuanxu-option-append 'List '("base"))
    priority: (yuanxu-option-override 'String "base")
    mode-lock: (yuanxu-option-conflict 'String))
   '((audience . user))))

;; : (-> Unit PooModuleDescriptor)
(def user-child-module
  (agenticAiLabModules
   user-child-interface
   (.o id: 'user-child
       group: 'tools
       flags: '(+helper)
       features: '(child-profile)
       depth: (cons -20 20)
       phase-files: '((init . "child/init.ss")
                      (config . "child/config.ss"))
       config: (yuanxu-module-option-block
                surface: "agentic-ai-lab"
                child-mode: "helper"
                layers: '("child")
                priority: "child"
                mode-lock: "stable")
       hooks: (yuanxu-module-hook-block
               (after-config child-ready)))))

;; : (-> Unit PooModuleInterface)
(def user-root-interface
  (yuanxu-module-interface
   "UserRootProfile"
   (yuanxu-module-option-block
    surface: (yuanxu-string-constant "agentic-ai-lab")
    mode: (yuanxu-string-default "interactive")
    layers: (yuanxu-option-append 'List '("base"))
    priority: (yuanxu-option-override 'String "base")
    mode-lock: (yuanxu-option-conflict 'String))
   '((audience . user)
     (surface . module-system))))

;; : (-> Unit PooModuleDescriptor)
(defagentic-ai-lab-module user-root-module
  user-root-interface
  (id 'user-root)
  (imports (yuanxu-import ":user/root#child" user-child-module))
  (config (yuanxu-module-option-block
           surface: "agentic-ai-lab"
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
  (agenticAiLabModules
   user-root-interface
   (.o id: 'invalid-user
       config: (yuanxu-module-option-block
                surface: "wrong-surface"
                unknown-option: "left-unclaimed"))))

;; : (-> Unit PooModuleSourceRef)
(def loader-child-source
  (yuanxu-local-source "loaded/child.ss"))

;; : (-> Unit PooModuleSourceRef)
(def loader-root-source
  (yuanxu-local-source "loaded/root.ss"))

;; : (-> Unit PooModuleSourceRef)
(def loader-missing-source
  (yuanxu-local-source "loaded/missing.ss"))

;; : (-> Unit PooModuleDescriptor)
(def loader-child-module
  (make-empty-agentic-ai-lab-module-descriptor
   'loaded-child
   '()
   '((loaded-child . #t))))

;; : (-> Unit PooModuleDescriptor)
(def loader-root-module
  (make-empty-agentic-ai-lab-module-descriptor
   'loaded-root
   '(loaded-child)
   '((loaded-root . #t))))

;; : (-> Unit PooModuleLoaderBackend)
(def user-static-loader
  (yuanxu-module-static-loader
   'user-static-loader
   'local
   (list (make-yuanxu-module-loader-entry loader-root-source
                                            loader-root-module)
         (make-yuanxu-module-loader-entry loader-child-source
                                            loader-child-module))))

;; : (-> Unit PooModuleValueCatalog)
(def user-catalog
  (yuanxuModuleCatalog user-root-module invalid-user-module))

;; : (-> Unit PooModuleValueCatalog)
(defagentic-ai-lab-module-set user-macro-catalog
  (modules user-root-module)
  (yuanxu-module-when #t user-child-module)
  (yuanxu-module-when #f invalid-user-module))

;; : (-> Identifier Syntax)
(defagentic-ai-lab-module-object-block agentic-ai-lab-module-user-block)

;; : (-> Unit POOObject)
(def user-generated-poo-block
  (agentic-ai-lab-module-user-block
   generated: "agentic-ai-lab"
   policy: 'slot-based))

;; : (-> Unit POOObject)
(def user-generated-hook-block
  (yuanxu-module-hook-block
   (before-init prepare-state)
   (after-config child-ready)))

;; : (-> UserInterfaceEntry [UserInterfaceEntry] Boolean)
(def (has-member? value values)
  (not (not (member value values))))

;; : (-> Unit TestSuite)
;;; This suite guards the compact user-facing module syntax from depending on
;;; internal loader or registry owners.
(def module-system-user-interface-test
  (test-suite "agentic-ai-lab module system user interface"
    (yuanxu-test-case "declares modules through explicit public owners"
      (check-equal? (agentic-ai-lab-module-descriptor? user-root-module) #t)
      (check-equal? (agentic-ai-lab-module-name user-root-module) 'user-root)
      (check-equal? (yuanxu-module-interface-id
                     (agentic-ai-lab-module-interface-object user-root-module))
                    "UserRootProfile")
      (check-equal? (agentic-ai-lab-module-group user-root-module)
                    agentic-ai-lab-brand-group)
      (let* ((imports (yuanxu-module-imports user-root-module))
             (first-import (car imports))
             (source-ref (.ref first-import 'source-ref)))
        (check-equal? (length imports) 1)
        (check-equal? (yuanxu-import? first-import) #t)
        (check-equal? (yuanxu-module-source-ref-kind source-ref) 'local)
        (check-equal? (yuanxu-module-source-ref-value source-ref)
                      ":user/root#child")
        (check-equal? (.ref first-import 'profile) user-child-module))
      (check-equal? (agentic-ai-lab-module-extensions user-root-module)
                    '(root-extension))
      (check-equal? (agentic-ai-lab-module-scripts user-root-module)
                    '(root-script))
      (check-equal? (agentic-ai-lab-module-metadata user-root-module)
                    '((audience . user)
                      (owner . public-interface))))
    (yuanxu-test-case "exposes Doom-style user predicates as explicit data checks"
      (check-equal? (agentic-ai-lab-module-group user-child-module) 'tools)
      (check-equal? (agentic-ai-lab-module-flags user-child-module) '(+helper))
      (check-equal? (agentic-ai-lab-module-features user-child-module)
                    '(child-profile))
      (check-equal? (yuanxu-module-depth-value user-child-module 'init) -20)
      (check-equal? (yuanxu-module-depth-value user-child-module 'config) 20)
      (check-equal? (yuanxu-module-phase-file user-child-module 'config)
                    "child/config.ss")
      (check-equal? (yuanxu-module-hook-values user-child-module 'after-config)
                    '(child-ready))
      (check-equal? (agentic-ai-lab-module-active? user-child-module '+helper '-missing)
                    #t)
      (check-equal? (agentic-ai-lab-module-active? user-child-module '+missing)
                    #f)
      (check-equal? (agentic-ai-lab-module-value-catalog-active? user-catalog 'user-root)
                    #t)
      (check-equal? (agentic-ai-lab-module-value-catalog-active? user-catalog 'user-child)
                    #f)
      (check-equal? (agentic-ai-lab-module-value-catalog-active? user-catalog 'invalid-user '+helper)
                    #f))
    (yuanxu-test-case "projects catalog eval and presentation for users"
      (let* ((workflow (agentic-ai-lab-module-workflow user-root-module '("after-config")))
             (evaluation (agentic-ai-lab-module-evaluate user-root-module))
             (eval-result (agenticAiLabEvalModules user-catalog 'user-root '("after-config")))
             (presentation
              (agenticAiLabModuleSystemPresentation
               user-catalog
               'user-root
               '("after-config"))))
        (check-equal? (.ref workflow 'kind) agentic-ai-lab-module-workflow-kind)
        (check-equal? (.ref evaluation 'module-ids) '(user-root user-child))
        (check-equal? (.ref evaluation 'init-module-ids)
                      '(user-child user-root))
        (check-equal? (.ref eval-result 'root-module-id) 'user-root)
        (check-equal? (.ref eval-result 'module-count) 2)
        (check-equal? (.ref eval-result 'hook-count) 1)
        (check-equal? (.ref presentation 'catalog-module-count) 2)
        (check-equal? (.ref presentation 'root-module-id) 'user-root)
        (check-equal? (.ref presentation 'brand-name) agentic-ai-lab-brand-name)
        (check-equal? (has-member? "agentic-ai-lab-module-value-catalog-active?"
                                   (.ref presentation 'user-entrypoints))
      #t)))
    (yuanxu-test-case "returns validation receipts for user config mistakes"
      (let* ((receipts
              (agentic-ai-lab-module-option-validation-receipts invalid-user-module))
             (codes
              (map yuanxu-module-option-validation-receipt-code receipts)))
        (check-equal? (length receipts) 2)
        (check-equal? (has-member? 'constant-mismatch codes) #t)
        (check-equal? (has-member? 'missing-schema codes) #t)))
    (yuanxu-test-case "loads source refs into catalogs before resolver activation"
      (let* ((sources (list loader-root-source loader-child-source))
             (backends (list user-static-loader))
             (receipts
              (yuanxu-module-load-source-receipts backends sources))
             (catalog
              (agentic-ai-lab-module-load-catalog 'loaded-user-catalog
                                            backends
                                            sources))
            (doctor
              (agentic-ai-lab-module-resolve-doctor catalog sources))
             (activation
              (agentic-ai-lab-module-resolve-and-activate catalog sources)))
        (check-equal? (map yuanxu-module-load-receipt-code receipts)
                      '(loaded loaded))
        (check-equal? (map yuanxu-module-load-receipt-backend-name receipts)
                      '(user-static-loader user-static-loader))
        (check-equal? (yuanxu-module-catalog-name catalog)
                      'loaded-user-catalog)
        (check-equal? (map agentic-ai-lab-module-name
                           (yuanxu-module-catalog-modules catalog))
                      '(loaded-root loaded-child))
        (check-equal? (yuanxu-module-doctor-report-status doctor)
                      'warning)
        (check-equal? (agentic-ai-lab-module-names
                       (agentic-ai-lab-module-activation-modules activation))
                      '(loaded-root loaded-child))))
    (yuanxu-test-case "presents doctor evidence without runtime execution"
      (let* ((doctor-presentation
              (agenticAiLabModuleDoctorPresentation user-catalog 'user-root))
             (source-presentation
              (agenticAiLabModuleSourceDoctorPresentation
               (list user-static-loader)
               (list loader-root-source loader-child-source)))
             (missing-source-presentation
              (agenticAiLabModuleSourceDoctorPresentation
               (list user-static-loader)
               (list loader-missing-source)))
             (source-doctor
              (.ref source-presentation 'module-doctor)))
        (check-equal? (.ref doctor-presentation 'kind)
                      agentic-ai-lab-module-doctor-presentation-kind)
        (check-equal? (.ref doctor-presentation 'root-module-id)
                      'user-root)
        (check-equal? (.ref doctor-presentation 'runtime-executed)
                      #f)
        (check-equal? (.ref doctor-presentation 'brand-name)
                      agentic-ai-lab-brand-name)
        (check-equal? (.ref doctor-presentation 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (.ref source-presentation 'kind)
                      agentic-ai-lab-module-source-doctor-presentation-kind)
        (check-equal? (.ref source-presentation 'loaded-count) 2)
        (check-equal? (.ref source-presentation 'load-status) 'ok)
        (check-equal? (.ref source-presentation 'brand-name)
                      agentic-ai-lab-brand-name)
        (check-equal? (.ref missing-source-presentation 'loaded-count) 0)
        (check-equal? (.ref missing-source-presentation 'missing-count) 1)
        (check-equal? (.ref missing-source-presentation 'load-status) 'error)
        (check-equal? (.ref missing-source-presentation 'module-doctor) #f)
        (check-equal? (.ref missing-source-presentation 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (.ref source-doctor 'root-module-id)
                      'loaded-root)))
    (yuanxu-test-case "uses Gerbil-hosted higher-order macros for POO blocks"
      (check-equal? (not
                     (not
                      (.slot? user-generated-poo-block 'generated)))
                    #t)
      (check-equal? (.ref user-generated-poo-block 'generated)
                    "agentic-ai-lab")
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
    (yuanxu-test-case "builds module sets with Gerbil macro authoring"
      (let* ((modules (.ref user-macro-catalog 'modules))
             (eval-result (agenticAiLabEvalModules user-macro-catalog 'user-root)))
        (check-equal? (length modules) 2)
        (check-equal? (map agentic-ai-lab-module-name modules)
                      '(user-root user-child))
        (check-equal? (agentic-ai-lab-module-value-catalog-active? user-macro-catalog
                                                             'user-child
                                                             '+helper)
                      #t)
        (check-equal? (agentic-ai-lab-module-value-catalog-active? user-macro-catalog 'invalid-user)
                      #f)
        (check-equal? (.ref eval-result 'module-count) 2))))
  )
