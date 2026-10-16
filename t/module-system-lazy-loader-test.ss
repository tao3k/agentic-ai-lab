;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: lazy loader tests cover deferred source loading only.
;;; Invariant: lazy plans never call loader handlers until explicitly forced.

(import :core/module-system/source/projection
        (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-exception
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        "./support/performance"
        (only-in :asp-gerbil-scheme/benchmark-api benchmark-p95-elapsed-ms)
        (only-in :poo-flow/modules/workflow/control-plane/failure
                 execution-failure?
                 execution-failure-code)
        (only-in :core/module-system/selection/syntax poo-flow-modules!)
        :core/module-system/source/imports
        :core/module-system/source/objects
        :poo-flow/modules/module-authoring/module-descriptor
        :core/extension-graph/interface
        :core/module-system/loader/objects
        :core/module-system/source/collection
        (only-in :poo-flow/modules/module-authoring/module-source-collection make-poo-flow-contribution-module-load-path poo-flow-default-module-load-path poo-flow-maintained-module-source)
        :poo-flow/modules/building/official-contributions
        :poo-flow/modules/workflow/scenario/configuration/module-source-selection
        :poo-flow/modules/workflow/scenario/configuration/module-source-tree)

(export module-system-lazy-loader-test)

;;; Source reference fixture names the standard-library module without touching
;;; filesystem-backed module loading.
;; : (-> Unit PooModuleSourceRef)
(def loader-standard-library-source
  (poo-flow-standard-library-source 'standard/kernel))

;;; Mutable call count is scoped to this owner to prove deferred loading without
;;; reaching into loader internals.
;; : (-> Unit Integer)
(def lazy-loader-call-count 0)

;;; Optional contribution checkouts are external package state.  Capture the
;;; typed loader result so the absent-checkout branch proves the public
;;; contract without requiring CI to initialize every contribution submodule.
;; : (-> Thunk Value)
(def (capture-lazy-loader-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;;; Module fixture is inert descriptor data used by the test loader backend.
;; : (-> Unit PooModuleDescriptor)
(def loader-standard-library-module
  (make-empty-poo-flow-module-descriptor
   'standard-kernel
   '()
   '((standard-library . #t))))

;;; Loader backend fixture records calls and returns only the known standard
;;; library module source.
;; : (-> Unit PooModuleLoaderBackend)
(def user-standard-library-loader
  (make-poo-flow-module-loader-backend
   'user-standard-library-loader
   'standard-library
   (lambda (source-ref)
     (set! lazy-loader-call-count (+ lazy-loader-call-count 1))
     (if (poo-flow-module-source-ref=? source-ref loader-standard-library-source)
       loader-standard-library-module
       #f))
   '((library . standard))))

;;; Plan predicate keeps assertions about deferred receipts compact and local to
;;; the lazy-loader policy owner.
;; : (-> [PooFlowLazyLoadPlan] Boolean)
(def (lazy-loader-plans-deferred? plans)
  (cond
   ((null? plans) #t)
   ((and (not (poo-flow-lazy-load-plan-forced? (car plans)))
         (eq? (poo-flow-module-load-receipt-code
               (poo-flow-lazy-load-plan-receipt (car plans)))
              'deferred))
    (lazy-loader-plans-deferred? (cdr plans)))
   (else #f)))

;; : (forall (a) (-> [a] [a] [a]))
(def (lazy-loader-values/rev-onto values values-rev)
  (let loop ((remaining-values values)
             (result values-rev))
    (if (null? remaining-values)
      result
      (loop (cdr remaining-values)
            (cons (car remaining-values) result)))))

;; : (-> [String] [PooModuleSourceRef])
(def (lazy-loader-module-tree-source-refs module-roots)
  (let loop ((remaining-roots module-roots)
             (refs-rev '()))
    (if (null? remaining-roots)
      (reverse refs-rev)
      (loop (cdr remaining-roots)
            (lazy-loader-values/rev-onto
             (poo-flow-module-tree-source-refs (car remaining-roots))
             refs-rev)))))

;;; This suite keeps lazy-loader planning observable without forcing modules to
;;; load eagerly during configuration parsing.
;; : TestSuite
;; : TestCase
(def (module-system-lazy-loader-large-registry-case)
  (poo-flow-test-case "expands large module registry manifests without loading modules"
        (for-each
         (lambda (module-count)
           (let* ((module-roots
                   (poo-flow-performance-build-list
                    module-count
                    (lambda (index)
                      (string-append "modules/generated-"
                                     (number->string index)))))
                  (source-refs
                   (lazy-loader-module-tree-source-refs module-roots))
                  (p95-ms
                   (benchmark-p95-elapsed-ms
                    5
                    (lambda ()
                      (lazy-loader-module-tree-source-refs module-roots)))))
             (check-equal? (length source-refs) module-count)
             (check-equal? (poo-flow-module-source-ref-value (car source-refs))
                           "modules/generated-0/interface.ss")
             ;; Emit the scale receipt without embedding a machine-specific
             ;; timing threshold in this semantic unit test. Performance
             ;; admission belongs to a selected Observability profile.
             (displayln "[poo-flow-module-catalog] phase=projection-complete module-count="
                        module-count " p95-ms=" p95-ms
                        " selected-build-target-count=0")
             (check-equal? (and (real? p95-ms) (>= p95-ms 0)) #t)))
         '(100 1000))))

;; : TestCase
(def (module-system-lazy-loader-deferred-standard-library-case)
  (poo-flow-test-case "defers standard-library module loading until forced"
        (set! lazy-loader-call-count 0)
        (let* ((backends (list user-standard-library-loader))
               (deferred
                (poo-flow-lazy-load-source-receipt
                 backends
                 loader-standard-library-source))
               (plan
                (poo-flow-make-lazy-load-plan
                 backends
                 loader-standard-library-source
                 '((owner . standard-library))))
               (deferred-metadata
                (poo-flow-module-load-receipt-metadata deferred)))
          (check-equal? (poo-flow-module-source-ref-kind loader-standard-library-source)
                        'standard-library)
          (check-equal? (poo-flow-module-load-receipt-code deferred)
                        'deferred)
          (check-equal? (poo-flow-module-load-receipt-loaded? deferred)
                        #f)
          (check-equal? (cdr (assoc 'mode deferred-metadata))
                        'lazy)
          (check-equal? (cdr (assoc 'enabled? deferred-metadata))
                        #f)
          (check-equal? lazy-loader-call-count 0)
          (check-equal? (poo-flow-lazy-load-plan-forced? plan)
                        #f)
          (let* ((forced-plan
                  (poo-flow-force-lazy-load-plan plan))
                 (forced-receipt
                  (poo-flow-lazy-load-plan-receipt forced-plan)))
            (check-equal? (poo-flow-lazy-load-plan-forced? forced-plan)
                          #t)
            (check-equal? lazy-loader-call-count 1)
            (check-equal? (poo-flow-module-load-receipt-code forced-receipt)
                          'loaded)
            (check-equal? (poo-flow-module-name
                           (poo-flow-module-load-receipt-module forced-receipt))
                          'standard-kernel)))))

;; : TestCase
(def (module-system-lazy-loader-module-tree-case)
  (poo-flow-test-case "projects the public interface entrypoint from a module tree"
        (set! lazy-loader-call-count 0)
        (let* ((module-root "modules/nono-sandbox")
               (source-refs
                (poo-flow-module-tree-source-refs module-root))
               (interface-source (car source-refs))
               (interface-metadata
                (poo-flow-module-source-ref-metadata interface-source))
               (plans
                (poo-flow-module-tree-lazy-load-plans
                 (list user-standard-library-loader)
                 module-root
                 '((owner . module-tree)))))
          (check-equal? (length source-refs) 1)
          (check-equal? (poo-flow-module-source-ref-kind interface-source) 'local)
          (check-equal? (poo-flow-module-source-ref-value interface-source)
                        "modules/nono-sandbox/interface.ss")
          (check-equal? (cdr (assoc 'entrypoint-role interface-metadata))
                        'interface)
          (check-equal? (length plans) 1)
          (check-equal? (poo-flow-lazy-load-plan-forced? (car plans)) #f)
          (check-equal? (poo-flow-module-load-receipt-code
                         (poo-flow-lazy-load-plan-receipt (car plans)))
                        'deferred)
          (check-equal? lazy-loader-call-count 0))))

;; : TestCase
(def (module-system-lazy-loader-src-modules-case)
  (poo-flow-test-case "projects canonical modules interfaces as lazy load plans"
        (set! lazy-loader-call-count 0)
        (let* ((plans
                (poo-flow-src-modules-lazy-load-plans
                 (list user-standard-library-loader)
                 '((owner . src-modules))))
               (source-values
                (map (lambda (plan)
                       (poo-flow-module-source-ref-value
                        (poo-flow-lazy-load-plan-source plan)))
                     plans))
               (first-receipt
                (poo-flow-lazy-load-plan-receipt (car plans)))
               (first-metadata
                (poo-flow-module-load-receipt-metadata first-receipt)))
          (check-equal?
           (length plans)
           (+ (length
               (poo-flow-module-source-collection-interfaces poo-flow-maintained-module-source))
              (length (poo-flow-module-system-source-refs))))
          (check-equal? (car source-values)
                        "modules/agent-sandbox/interface.ss")
          (check-equal? (if (member "modules/sandbox-core/interface.ss"
                                    source-values)
                          #t
                          #f)
                        #t)
          (check-equal? (if (member "modules/nono-sandbox/interface.ss"
                                    source-values)
                          #t
                          #f)
                        #t)
          (check-equal? (if (member "modules/standards/interface.ss"
                                    source-values)
                          #t
                          #f)
                        #t)
          (check-equal? (if (member "modules/workflow/scenario/configuration/profile-config.ss"
                                    source-values)
                          #t
                          #f)
                        #t)
          (check-equal? (if (member "modules/workflow/scenario/configuration/init-syntax.ss"
                                    source-values)
                          #t
                          #f)
                        #t)
          (check-equal? (if (member "modules/workflow/scenario/configuration/root-profile.ss"
                                    source-values)
                          #t
                          #f)
                        #t)
          (check-equal? (if (member "modules/workflow/scenario/configuration/declaration-case.ss"
                                    source-values)
                          #t
                          #f)
                        #t)
          (check-equal? (if (member "modules/workflow/interface.ss"
                                    source-values)
                          #t
                          #f)
                        #t)
          ;; The former workflow binding macros duplicated public constructors;
          ;; discovery must not resurrect that removed DSL surface.
          (check-equal? (if (member "modules/workflow/syntax.ss"
                                    source-values)
                          #t
                          #f)
                        #f)
          (check-equal? (lazy-loader-plans-deferred? plans) #t)
          (check-equal? (cdr (assoc 'mode first-metadata)) 'lazy)
          (check-equal? (cdr (assoc 'owner first-metadata)) 'src-modules)
          (check-equal? lazy-loader-call-count 0))))

;; : TestCase
(def (module-system-lazy-loader-user-root-case)
  (poo-flow-test-case "projects only the Doom-style init and config roots"
        (set! lazy-loader-call-count 0)
        (let* ((user-root "user-interface")
               (source-refs
                (poo-flow-user-tree-source-refs user-root))
               (init-source (car source-refs))
               (config-source (cadr source-refs))
               (init-metadata
                (poo-flow-module-source-ref-metadata init-source))
               (config-metadata
                (poo-flow-module-source-ref-metadata config-source))
               (plans
                (poo-flow-user-tree-lazy-load-plans
                 (list user-standard-library-loader)
                 user-root
                 '((owner . user-root-tree)))))
          (check-equal? (length source-refs) 2)
          (check-equal? (poo-flow-module-source-ref-value init-source)
                        "user-interface/init.ss")
          (check-equal? (poo-flow-module-source-ref-value config-source)
                        "user-interface/config.ss")
          (check-equal? (cdr (assoc 'kind config-metadata)) 'user-tree)
          (check-equal? (cdr (assoc 'policy init-metadata))
                        'init-switches-only)
          (check-equal? (poo-flow-user-tree-source-allows?
                         init-source
                         'module-switch)
                        #t)
          (check-equal? (poo-flow-user-tree-source-allows?
                         init-source
                         'feature-switch)
                        #t)
          (check-equal? (poo-flow-user-tree-source-allows?
                         init-source
                         'sandbox-profile-recipe)
                        #f)
          (check-equal? (poo-flow-user-tree-source-valid?
                         init-source
                         '(module-switch feature-switch custom-module-switch))
                        #t)
          (check-equal? (poo-flow-user-tree-source-allows?
                         init-source
                         'profile-selection)
                        #f)
          (check-equal? (poo-flow-user-tree-source-policy-violations
                         init-source
                         '(module-switch object-contract runtime-execution))
                        '(object-contract runtime-execution))
          (check-equal? (cdr (assoc 'policy config-metadata))
                        'composition-declarations-only)
          (check-equal? (poo-flow-user-tree-source-allows?
                         config-source
                         'composition-declaration)
                        #t)
          (check-equal? (poo-flow-user-tree-source-valid?
                         config-source
                         '(composition-declaration profile-use scenario-use))
                        #t)
          (check-equal? (poo-flow-user-tree-source-allows?
                         config-source
                         'runtime-execution)
                        #f)
          (check-equal? (poo-flow-user-tree-source-allows?
                         config-source
                         'module-switch)
                        #f)
          (check-equal? (length plans) 2)
          (check-equal? (poo-flow-module-load-receipt-code
                         (poo-flow-lazy-load-plan-receipt (car plans)))
                        'deferred)
          (check-equal? lazy-loader-call-count 0))))

;; : TestCase
(def (module-system-user-root-authoring-contract-case)
  (poo-flow-test-case "admits value composition and rejects advanced root mechanisms"
    (check-equal?
     (begin
       (poo-flow-user-tree-config-authoring-validate! "user-interface")
       (poo-flow-user-tree-config-authoring-validate!
        "t/fixtures/user-surface-positive")
       #t)
     #t)
    (check-exception
     (poo-flow-user-tree-config-authoring-validate!
      "t/fixtures/user-root-authoring-invalid")
     true)
    (check-exception
     (poo-flow-user-tree-config-authoring-validate!
      "t/fixtures/user-surface-raw-mop")
     true)
    (check-exception
     (poo-flow-user-tree-config-authoring-validate!
      "t/fixtures/user-surface-direct-clos")
     true)
    (check-exception
     (poo-flow-user-tree-config-authoring-validate!
      "t/fixtures/user-surface-raw-hook")
     true)))

;; : TestCase
(def (module-system-lazy-loader-aitia-submodule-source-case)
  (poo-flow-test-case "official contribution sources are optional and resolve by checkout identity"
    (check-equal?
     (map poo-flow-module-source-collection-identity
          (poo-flow-module-load-path-collections
           (make-poo-flow-contribution-module-load-path
            'example-contribution ".")))
     '(example-contribution poo-flow-maintained))
    (check-equal?
     (map poo-flow-module-source-collection-identity
          poo-flow-official-contribution-sources)
     '(poo-flow-official-contributions))
    (let (selection (caar (poo-flow-modules! :custom (lambda-aitia))))
      (if (file-exists? "packages/lambda-aitia/modules")
        (let (source-refs
              (poo-flow-module-selection-source-refs
               poo-flow-official-contribution-load-path selection))
          (check-equal?
           (map poo-flow-module-source-ref-value source-refs)
           '("packages/lambda-aitia/modules/ADR/interface.ss"
             "packages/lambda-aitia/modules/assurance/interface.ss"
             "packages/lambda-aitia/modules/formal-methods/interface.ss"
             "packages/lambda-aitia/modules/gitops/interface.ss"
             "packages/lambda-aitia/modules/sdlc/interface.ss")))
        (let (failure
              (capture-lazy-loader-failure
               (lambda ()
                 (poo-flow-module-selection-source-refs
                  poo-flow-official-contribution-load-path selection))))
          (check-equal? (execution-failure? failure) #t)
          (check-equal? (execution-failure-code failure)
                        'missing-module-source))))))

;; : TestCase
(def (module-system-lazy-loader-auto-import-removal-case)
  (poo-flow-test-case "removes auto-imported entrypoints through POO extension"
        (set! lazy-loader-call-count 0)
        (let* ((source-refs
                (poo-flow-user-tree-source-refs "user-interface"))
               (disable-config
                (poo-flow-module-extension-contribution
                 poo-flow-module-auto-import-root-identity
                 (list
                  (poo-flow-module-extension-node-remove
                   "user-interface/config.ss"))))
               (result
                (poo-flow-module-auto-imports-resolve
                 source-refs
                 (list disable-config)))
               (resolved-source-values
                (map poo-flow-module-source-ref-value
                     (poo-flow-module-auto-imports-result-source-refs result))))
          (check-equal? (poo-flow-module-extension-result-stable? result) #t)
          (check-equal? (length resolved-source-values) 1)
          (check-equal? (member "user-interface/config.ss"
                                resolved-source-values)
                        #f)
          (check-equal? resolved-source-values
                        '("user-interface/init.ss"))
          (check-equal? lazy-loader-call-count 0))))

;; : TestSuite
(def module-system-lazy-loader-test
  (test-suite "poo-flow module system lazy loader"
    (module-system-lazy-loader-large-registry-case)
    (module-system-lazy-loader-deferred-standard-library-case)
    (module-system-lazy-loader-module-tree-case)
    (module-system-lazy-loader-src-modules-case)
    (module-system-lazy-loader-user-root-case)
    (module-system-user-root-authoring-contract-case)
    (module-system-lazy-loader-aitia-submodule-source-case)
    (module-system-lazy-loader-auto-import-removal-case)))
