;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: this integration test imports precise Module System and User
;;; Interface owners without a module-system aggregate.

(import (only-in :clan/poo/type Record String List)
        (only-in :clan/poo/mop make-instance Function)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
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
        (only-in :clan/poo/object .o .def .ref .slot? .get)
        :agentic-ai-lab/modules/module-authoring/module-interface
        :tao3k/yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :tao3k/yuanxu/module-system/source/collection
        (only-in :agentic-ai-lab/modules/module-authoring/module-source-collection make-agentic-ai-lab-contribution-module-load-path agentic-ai-lab-default-module-load-path agentic-ai-lab-maintained-module-source)
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-source-tree
        :agentic-ai-lab/modules/module-authoring/module-option-projection
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-runtime-presentation
        :tao3k/yuanxu/module-system/catalog/values
        :tao3k/yuanxu/module-system/loader/objects
        :tao3k/yuanxu/module-system/projection/option-objects
        :tao3k/yuanxu/module-system/projection/option-validation
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-diagnostics
        :agentic-ai-lab/modules/workflow/scenario/configuration/doctor-presentation
        :tao3k/yuanxu/module-system/source/imports
        :tao3k/yuanxu/module-system/source/objects
        :tao3k/yuanxu/module-system/funs
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-activation
        :tao3k/yuanxu/module-system/catalog/objects
        :tao3k/yuanxu/module-system/authoring/syntax)

(export module-system-user-interface-test)

;; : (-> Unit PooModuleInterface)
(def user-child-interface
  (yuanxu-module-interface
   "UserChildProfile"
   (Record
    surface: [String constant: "agentic-ai-lab"]
    child-mode: [String default: "helper"]
    layers: [(List String) policy: 'append default: '("base")]
    priority: [String policy: 'override default: "base"]
    mode-lock: [String policy: 'conflict])
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
   (Record
    surface: [String constant: "agentic-ai-lab"]
    mode: [String default: "interactive"]
    layers: [(List String) policy: 'append default: '("base")]
    priority: [String policy: 'override default: "base"]
    mode-lock: [String policy: 'conflict])
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

;; : (-> Unit ModuleLoaderBackend)
(def user-static-loader
  (yuanxu-module-static-loader
   'user-static-loader
   'local
   (list (make-instance ModuleSourceBinding source: loader-root-source
                                            module: loader-root-module)
         (make-instance ModuleSourceBinding source: loader-child-source
                                            module: loader-child-module))))

;; : (-> Unit PooModuleValueCatalog)
(def user-catalog
  (yuanxuModuleCatalog user-root-module invalid-user-module))

;; : (-> Unit PooModuleValueCatalog)
(defyuanxu-module-set user-macro-catalog
  (modules user-root-module)
  (yuanxu-module-when #t user-child-module)
  (yuanxu-module-when #f invalid-user-module))

;; : (-> Identifier Syntax)
(defyuanxu-module-object-block agentic-ai-lab-module-user-block)

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
    (yuanxu-test-case "workflow root and aggregate share only their own runtime preview"
      (def trace '())
      (def (declaration label)
        (.o (:: @ (Record value: [String]))
          .element?: (lambda (candidate)
                       (set! trace (append trace (list (list label (.get candidate value))))) #t)))
      (def child-module
        (agentic-ai-lab-modules (yuanxu-module-interface "Child" (declaration 'child) '())
          (.o id: 'preview-child config: (.o value: "child"))))
      (def root-module
        (agentic-ai-lab-modules (yuanxu-module-interface "Root" (declaration 'root) '())
          (.o id: 'preview-root imports: (list child-module child-module)
              config: (.o value: "parent"))))
      (def workflow (agentic-ai-lab-module-workflow root-module))
      (check-equal? trace '())
      (def root-receipts (.get workflow root-validation-receipts))
      (check-equal? trace '((root "parent")))
      (def combined (.get workflow validation-receipts))
      (check-equal? trace '((root "parent") (child "child")))
      (check-equal? (map (cut .get <> source-module) combined) '(preview-root preview-child))
      (check-equal? (eq? (car combined) (car root-receipts)) #t)
      (check-equal? (eq? root-receipts (.get workflow evaluation root-validation-receipts)) #t)
      (set! trace '())
      (def fresh (agentic-ai-lab-module-workflow root-module))
      (.get fresh validation-receipts)
      (.get fresh root-validation-receipts)
      (check-equal? trace '((root "parent") (child "child")))
      (set! trace '())
      (.def (derived @ workflow)
        config: =>.+ (.o config: =>.+ (.o value: "derived")))
      (.get derived validation-receipts)
      (.get derived root-validation-receipts)
      (check-equal? trace '((root "derived") (child "child")))
      (check-equal? (.get (car (.get derived root-options)) value) "derived")
      (check-equal? (eq? root-receipts (.get workflow root-validation-receipts)) #t)
      (check-equal? (.get (car (.get workflow root-options)) value) "parent")
      (check-equal? trace '((root "derived") (child "child"))))
    (yuanxu-test-case "one preview closure serves workflow and all doctor metadata consumers"
      (def leaf (make-empty-agentic-ai-lab-module-descriptor 'closure-leaf '() '()))
      (def left (make-empty-agentic-ai-lab-module-descriptor 'closure-left (list leaf) '()))
      (def right (make-empty-agentic-ai-lab-module-descriptor 'closure-right (list leaf) '()))
      (def base (make-empty-agentic-ai-lab-module-descriptor 'closure-root '() '()))
      (.def (root @ base) imports: (list root left right 'missing))
      (def catalog (yuanxuModuleCatalog root))
      (def productions 0)
      (def evaluation (agentic-ai-lab-module-evaluate root))
      (def (count-production modules) (set! productions (+ productions 1)) modules)
      (.def (observed @ evaluation) (modules => count-production))
      (.def (workflow @ (agentic-ai-lab-module-workflow root)) evaluation: observed)
      (.def (doctor @ (agenticAiLabModuleDoctorPresentation catalog 'closure-root)) evaluation: observed)
      (check-equal? productions 0)
      (def cached (.get observed modules))
      (check-equal? (.get workflow evaluation module-ids)
                    '(closure-root closure-left closure-leaf closure-right))
      (.get observed init-module-ids)
      (.get observed config-module-ids)
      (.get observed hooks)
      (.get observed extensions)
      (.get observed scripts)
      (.get observed options)
      (.get workflow validation-receipts)
      (check-equal? (.get doctor module-ids) (.get observed module-ids))
      (check-equal? (.get doctor doctor-status) 'error)
      (.get doctor diagnostics)
      (.get doctor import-graph)
      (.get doctor contributions)
      (.get doctor validation-receipt-count)
      (check-equal? productions 1)
      (check-equal? (agentic-ai-lab-module-doctor-report->alist (.get doctor doctor-report))
                    (agentic-ai-lab-module-doctor-report->alist (agentic-ai-lab-module-doctor (list root))))
      (def fresh (agentic-ai-lab-module-evaluate root))
      (.def (observed-fresh @ fresh) (modules => count-production))
      (.get observed-fresh modules)
      (check-equal? productions 2)
      (def added (make-empty-agentic-ai-lab-module-descriptor 'closure-added '() '()))
      (.def (changed @ root) imports: (list added 'missing))
      (.def (derived @ observed) config: changed)
      (check-equal? (.get derived module-ids) '(closure-root closure-added))
      (check-equal? productions 3)
      (check-equal? (eq? (.get observed modules) cached) #t)
      (def original-doctor (agenticAiLabModuleDoctorPresentation catalog 'closure-root))
      (def doctor-ids (.get original-doctor module-ids))
      (.def (derived-doctor @ original-doctor) config: changed)
      (check-equal? (.get derived-doctor module-ids) '(closure-root closure-added))
      (check-equal? (eq? (.get original-doctor module-ids) doctor-ids) #t))
    (yuanxu-test-case "returns validation receipts for user config mistakes"
      (let* ((receipts
              (agentic-ai-lab-module-option-validation-receipts invalid-user-module))
             (codes
              (map (cut .ref <> 'code) receipts)))
        (check-equal? (length receipts) 6)
        (check-equal? (length (filter (lambda (receipt)
                                      (not (.ref receipt 'valid?)))
                                    receipts)) 3)
        (check-equal? (has-member? 'constant-mismatch codes) #t)
        (check-equal? (has-member? 'missing-schema codes) #t)
        (let (missing (find (lambda (receipt) (eq? (.ref receipt 'code) 'missing-field)) receipts))
          (check-equal? (.ref missing 'id) "mode-lock")
          (check-equal? (.ref (car (.ref missing 'messages)) 'path) '(mode-lock)))))
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
        (check-equal? (map (cut .get <> code) receipts)
                      '(loaded loaded))
        (check-equal? (map (cut .get <> backend-name) receipts)
                      '(user-static-loader user-static-loader))
        (check-equal? (.get catalog name)
                      'loaded-user-catalog)
        (check-equal? (map agentic-ai-lab-module-name
                           (yuanxu-module-catalog-modules catalog))
                      '(loaded-root loaded-child))
        (check-equal? (yuanxu-module-doctor-report-status doctor)
                      'warning)
        (check-equal? (agentic-ai-lab-module-names
                       (agentic-ai-lab-module-activation-modules activation))
                      '(loaded-root loaded-child))))
    (yuanxu-test-case "doctor metadata stays cold and each preview owns its diagnostic demand"
      (def values-read 0)
      (def checked 0)
      (def body-calls 0)
      (def raw-handler (lambda (value) (set! body-calls (+ body-calls 1)) value))
      (def declaration
        (.o (:: @ (Record endpoint: [String] handler: [(Function (list String) (list String))]))
          .element?: (lambda (_) (set! checked (+ checked 1)) #t)))
      (def interface (yuanxu-module-interface "Doctor" declaration '()))
      (def module
        (agentic-ai-lab-modules interface
          (.o id: 'doctor-cold config:
              (.o endpoint: (begin (set! values-read (+ values-read 1)) "localhost")
                  handler: raw-handler
                  unclaimed: (error "doctor forced an unclaimed value")))))
      (def catalog (yuanxuModuleCatalog module))
      (def preview (agenticAiLabModuleDoctorPresentation catalog 'doctor-cold))
      (check-equal? values-read 0)
      (check-equal? checked 0)
      (check-equal? (.ref preview 'kind) agentic-ai-lab-module-doctor-presentation-kind)
      (check-equal? (cdr (assoc 'option-count (car (.ref preview 'contributions)))) 3)
      (check-equal? values-read 0)
      (check-equal? checked 0)
      (check-equal? (.ref preview 'validation-receipt-count) 3)
      (check-equal? values-read 1)
      (check-equal? checked 1)
      (check-equal? (.ref preview 'validation-receipt-count) 3)
      (check-equal? checked 1)
      (def fresh (agenticAiLabModuleDoctorPresentation catalog 'doctor-cold))
      (check-equal? checked 1)
      (check-equal? (.ref fresh 'validation-receipt-count) 3)
      (check-equal? checked 2)
      (check-equal? values-read 1)
      (check-equal? body-calls 0)
      (check-equal? (eq? (.ref (.ref module 'config) 'handler) raw-handler) #t)
      ;; Inspection follows the constructor's interface/config boundary, not a
      ;; product brand predicate that would fall back to reading the values.
      (def shared-interface (.o (:: @ interface) kind: 'shared-interface))
      (def shared
        (agentic-ai-lab-modules shared-interface
          (.o config: (.o endpoint: "shared" unclaimed: (error "shared payload forced")))))
      (check-equal? (length (agentic-ai-lab-module-option-names shared)) 2))
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
