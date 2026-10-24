;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: lazy loader tests cover deferred source loading only.
;;; Invariant: lazy plans never call loader handlers until explicitly forced.

(import :yuanxu/module-system/source/projection
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
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
        (only-in :yuanxu/modules/funflow/control-plane/failure
                 execution-failure?
                 execution-failure-code)
        (only-in :yuanxu/module-system/selection/syntax yuanxu-modules!)
        :yuanxu/module-system/source/imports
        :yuanxu/module-system/source/objects
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :yuanxu/graph/interface
        :yuanxu/module-system/loader/objects
        :yuanxu/module-system/source/collection
        (only-in :agentic-ai-lab/modules/module-authoring/module-source-collection make-agentic-ai-lab-contribution-module-load-path agentic-ai-lab-default-module-load-path agentic-ai-lab-maintained-module-source agentic-ai-lab-maintained-integration-directories)
        :agentic-ai-lab/modules/building/official-contributions
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-source-selection
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-source-tree)

(export module-system-lazy-loader-test)

;;; Source reference fixture names the standard-library module without touching
;;; filesystem-backed module loading.
;; : (-> Unit PooModuleSourceRef)
(def loader-standard-library-source
  (yuanxu-standard-library-source 'standard/kernel))

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
  (make-empty-agentic-ai-lab-module-descriptor
   'standard-kernel
   '()
   '((standard-library . #t))))

;;; Loader backend fixture records calls and returns only the known standard
;;; library module source.
;; : (-> Unit PooModuleLoaderBackend)
(def user-standard-library-loader
  (make-yuanxu-module-loader-backend
   'user-standard-library-loader
   'standard-library
   (lambda (source-ref)
     (set! lazy-loader-call-count (+ lazy-loader-call-count 1))
     (if (yuanxu-module-source-ref=? source-ref loader-standard-library-source)
       loader-standard-library-module
       #f))
   '((library . standard))))

;;; Plan predicate keeps assertions about deferred receipts compact and local to
;;; the lazy-loader policy owner.
;; : (-> [YuanxuLazyLoadPlan] Boolean)
(def (lazy-loader-plans-deferred? plans)
  (cond
   ((null? plans) #t)
   ((and (not (yuanxu-lazy-load-plan-forced? (car plans)))
         (eq? (yuanxu-module-load-receipt-code
               (yuanxu-lazy-load-plan-receipt (car plans)))
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
             (agentic-ai-lab-module-tree-source-refs (car remaining-roots))
             refs-rev)))))

;;; This suite keeps lazy-loader planning observable without forcing modules to
;;; load eagerly during configuration parsing.
;; : TestSuite
;; : TestCase
(def (module-system-lazy-loader-large-registry-case)
  (yuanxu-test-case "expands large module registry manifests without loading modules"
        (for-each
         (lambda (module-count)
           (let* ((module-roots
                   (agentic-ai-lab-performance-build-list
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
             (check-equal? (yuanxu-module-source-ref-value (car source-refs))
                           "modules/generated-0/interface.ss")
             ;; Emit the scale receipt without embedding a machine-specific
             ;; timing threshold in this semantic unit test. Performance
             ;; admission belongs to a selected Observability profile.
             (displayln "[yuanxu-module-catalog] phase=projection-complete module-count="
                        module-count " p95-ms=" p95-ms
                        " selected-build-target-count=0")
             (check-equal? (and (real? p95-ms) (>= p95-ms 0)) #t)))
         '(100 1000))))

;; : TestCase
(def (module-system-lazy-loader-deferred-standard-library-case)
  (yuanxu-test-case "defers standard-library module loading until forced"
        (set! lazy-loader-call-count 0)
        (let* ((backends (list user-standard-library-loader))
               (deferred
                (yuanxu-lazy-load-source-receipt
                 backends
                 loader-standard-library-source))
               (plan
                (yuanxu-make-lazy-load-plan
                 backends
                 loader-standard-library-source
                 '((owner . standard-library))))
               (deferred-metadata
                (yuanxu-module-load-receipt-metadata deferred)))
          (check-equal? (yuanxu-module-source-ref-kind loader-standard-library-source)
                        'standard-library)
          (check-equal? (yuanxu-module-load-receipt-code deferred)
                        'deferred)
          (check-equal? (yuanxu-module-load-receipt-loaded? deferred)
                        #f)
          (check-equal? (cdr (assoc 'mode deferred-metadata))
                        'lazy)
          (check-equal? (cdr (assoc 'enabled? deferred-metadata))
                        #f)
          (check-equal? lazy-loader-call-count 0)
          (check-equal? (yuanxu-lazy-load-plan-forced? plan)
                        #f)
          (let* ((forced-plan
                  (yuanxu-force-lazy-load-plan plan))
                 (forced-receipt
                  (yuanxu-lazy-load-plan-receipt forced-plan)))
            (check-equal? (yuanxu-lazy-load-plan-forced? forced-plan)
                          #t)
            (check-equal? lazy-loader-call-count 1)
            (check-equal? (yuanxu-module-load-receipt-code forced-receipt)
                          'loaded)
            (check-equal? (agentic-ai-lab-module-name
                           (yuanxu-module-load-receipt-module forced-receipt))
                          'standard-kernel)))))

;; : TestCase
(def (module-system-lazy-loader-module-tree-case)
  (yuanxu-test-case "projects the public interface entrypoint from a module tree"
        (set! lazy-loader-call-count 0)
        (let* ((module-root "modules/nono-sandbox")
               (source-refs
                (agentic-ai-lab-module-tree-source-refs module-root))
               (interface-source (car source-refs))
               (interface-metadata
                (yuanxu-module-source-ref-metadata interface-source))
               (plans
                (agentic-ai-lab-module-tree-lazy-load-plans
                 (list user-standard-library-loader)
                 module-root
                 '((owner . module-tree)))))
          (check-equal? (length source-refs) 1)
          (check-equal? (yuanxu-module-source-ref-kind interface-source) 'local)
          (check-equal? (yuanxu-module-source-ref-value interface-source)
                        "modules/nono-sandbox/interface.ss")
          (check-equal? (cdr (assoc 'entrypoint-role interface-metadata))
                        'interface)
          (check-equal? (length plans) 1)
          (check-equal? (yuanxu-lazy-load-plan-forced? (car plans)) #f)
          (check-equal? (yuanxu-module-load-receipt-code
                         (yuanxu-lazy-load-plan-receipt (car plans)))
                        'deferred)
          (check-equal? lazy-loader-call-count 0))))

;; : TestCase
(def (module-system-lazy-loader-src-modules-case)
  (yuanxu-test-case "projects canonical modules interfaces as lazy load plans"
        (set! lazy-loader-call-count 0)
        (let* ((plans
                (agentic-ai-lab-src-modules-lazy-load-plans
                 (list user-standard-library-loader)
                 '((owner . src-modules))))
               (source-values
                (map (lambda (plan)
                       (yuanxu-module-source-ref-value
                        (yuanxu-lazy-load-plan-source plan)))
                     plans))
               (first-receipt
                (yuanxu-lazy-load-plan-receipt (car plans)))
               (first-metadata
                (yuanxu-module-load-receipt-metadata first-receipt)))
          (check-equal?
           (length plans)
           (+ (length
               (yuanxu-module-source-collection-interfaces agentic-ai-lab-maintained-module-source))
              (length (agentic-ai-lab-module-system-source-refs))))
          (check-equal? (car source-values)
                        (path-expand "modules/agent-sandbox/interface.ss"))
          ;; Integration facades remain present, but cannot advertise the
          ;; four-role Module receipt that belongs to validated Modules.
          (for-each
           (lambda (name)
             (def path (string-append "modules/" name "/interface.ss"))
             (check-equal? (and (member path source-values) #t) #t)
             (check-equal?
              (yuanxu-module-source-collection-locate agentic-ai-lab-maintained-module-source
                (cons 'custom (string->symbol name))) '())
             (for-each
              (lambda (plan)
                (def source (yuanxu-lazy-load-plan-source plan))
                (when (equal? (yuanxu-module-source-ref-value source) path)
                  (let (metadata (yuanxu-module-source-ref-metadata source))
                    (check-equal? (cdr (assoc 'kind metadata)) 'framework-entrypoint)
                    (check-equal? (assoc 'required-roles metadata) #f)))) plans))
           agentic-ai-lab-maintained-integration-directories)
          (check-equal? (if (member (path-expand "modules/sandbox-core/interface.ss")
                                    source-values)
                          #t
                          #f)
                        #t)
          (check-equal? (if (member (path-expand "modules/nono-sandbox/interface.ss")
                                    source-values)
                          #t
                          #f)
                        #t)
          (check-equal? (if (member (path-expand "modules/standards/interface.ss")
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
  (yuanxu-test-case "projects only the Doom-style init and config roots"
        (set! lazy-loader-call-count 0)
        (let* ((user-root "user-interface")
               (source-refs
                (agentic-ai-lab-user-tree-source-refs user-root))
               (init-source (car source-refs))
               (config-source (cadr source-refs))
               (init-metadata
                (yuanxu-module-source-ref-metadata init-source))
               (config-metadata
                (yuanxu-module-source-ref-metadata config-source))
               (plans
                (agentic-ai-lab-user-tree-lazy-load-plans
                 (list user-standard-library-loader)
                 user-root
                 '((owner . user-root-tree)))))
          (check-equal? (length source-refs) 2)
          (check-equal? (yuanxu-module-source-ref-value init-source)
                        "user-interface/init.ss")
          (check-equal? (yuanxu-module-source-ref-value config-source)
                        "user-interface/config.ss")
          (check-equal? (cdr (assoc 'kind config-metadata)) 'user-tree)
          (check-equal? (cdr (assoc 'policy init-metadata))
                        'init-switches-only)
          (check-equal? (agentic-ai-lab-user-tree-source-allows?
                         init-source
                         'module-switch)
                        #t)
          (check-equal? (agentic-ai-lab-user-tree-source-allows?
                         init-source
                         'feature-switch)
                        #t)
          (check-equal? (agentic-ai-lab-user-tree-source-allows?
                         init-source
                         'sandbox-profile-recipe)
                        #f)
          (check-equal? (agentic-ai-lab-user-tree-source-valid?
                         init-source
                         '(module-switch feature-switch custom-module-switch))
                        #t)
          (check-equal? (agentic-ai-lab-user-tree-source-allows?
                         init-source
                         'profile-selection)
                        #f)
          (check-equal? (agentic-ai-lab-user-tree-source-policy-violations
                         init-source
                         '(module-switch object-contract runtime-execution))
                        '(object-contract runtime-execution))
          (check-equal? (cdr (assoc 'policy config-metadata))
                        'composition-declarations-only)
          (check-equal? (agentic-ai-lab-user-tree-source-allows?
                         config-source
                         'composition-declaration)
                        #t)
          (check-equal? (agentic-ai-lab-user-tree-source-valid?
                         config-source
                         '(composition-declaration profile-use scenario-use))
                        #t)
          (check-equal? (agentic-ai-lab-user-tree-source-allows?
                         config-source
                         'runtime-execution)
                        #f)
          (check-equal? (agentic-ai-lab-user-tree-source-allows?
                         config-source
                         'module-switch)
                        #f)
          (check-equal? (length plans) 2)
          (check-equal? (yuanxu-module-load-receipt-code
                         (yuanxu-lazy-load-plan-receipt (car plans)))
                        'deferred)
          (check-equal? lazy-loader-call-count 0))))

;; : TestCase
(def (module-system-user-root-authoring-contract-case)
  (yuanxu-test-case "admits value composition and rejects advanced root mechanisms"
    (check-equal?
     (begin
       (agentic-ai-lab-user-tree-config-authoring-validate! "user-interface")
       (agentic-ai-lab-user-tree-config-authoring-validate!
        "t/fixtures/user-surface-positive")
       #t)
     #t)
    (check-exception
     (agentic-ai-lab-user-tree-config-authoring-validate!
      "t/fixtures/user-root-authoring-invalid")
     true)
    (check-exception
     (agentic-ai-lab-user-tree-config-authoring-validate!
      "t/fixtures/user-surface-raw-mop")
     true)
    (check-exception
     (agentic-ai-lab-user-tree-config-authoring-validate!
      "t/fixtures/user-surface-direct-clos")
     true)
    (check-exception
     (agentic-ai-lab-user-tree-config-authoring-validate!
      "t/fixtures/user-surface-raw-hook")
     true)))

;; : TestCase
(def (module-system-lazy-loader-aitia-submodule-source-case)
  (yuanxu-test-case "official contribution sources are optional and resolve by checkout identity"
    (check-equal?
     (map yuanxu-module-source-collection-identity
          (yuanxu-module-load-path-collections
           (make-agentic-ai-lab-contribution-module-load-path
            'example-contribution ".")))
     '(example-contribution agentic-ai-lab-maintained))
    (check-equal?
     (map yuanxu-module-source-collection-identity
          agentic-ai-lab-official-contribution-sources)
     '(agentic-ai-lab-official-contributions))
    (let (selection (caar (yuanxu-modules! :custom (lambda-aitia))))
      (if (file-exists? "packages/lambda-aitia/modules")
        (let (source-refs
              (agentic-ai-lab-module-selection-source-refs
               agentic-ai-lab-official-contribution-load-path selection))
          (check-equal?
           (map yuanxu-module-source-ref-value source-refs)
           (map path-expand '("packages/lambda-aitia/modules/ADR/interface.ss"
             "packages/lambda-aitia/modules/assurance/interface.ss"
             "packages/lambda-aitia/modules/formal-methods/interface.ss"
             "packages/lambda-aitia/modules/gitops/interface.ss"
             "packages/lambda-aitia/modules/sdlc/interface.ss"))))
        (let (failure
              (capture-lazy-loader-failure
               (lambda ()
                 (agentic-ai-lab-module-selection-source-refs
                  agentic-ai-lab-official-contribution-load-path selection))))
          (check-equal? (execution-failure? failure) #t)
          (check-equal? (execution-failure-code failure)
                        'missing-module-source))))))

;; : TestCase
(def (module-system-lazy-loader-auto-import-removal-case)
  (yuanxu-test-case "removes auto-imported entrypoints through POO extension"
        (set! lazy-loader-call-count 0)
        (let* ((source-refs
                (agentic-ai-lab-user-tree-source-refs "user-interface"))
               (disable-config
                (yuanxu-graph-contribution
                 yuanxu-module-auto-import-root-identity
                 (list
                  (yuanxu-graph-node-remove
                   "user-interface/config.ss"))))
               (result
                (yuanxu-module-auto-imports-resolve
                 source-refs
                 (list disable-config)))
               (resolved-source-values
                (map yuanxu-module-source-ref-value
                     (yuanxu-module-auto-imports-result-source-refs result))))
          (check-equal? (yuanxu-graph-result-applied? result) #t)
          (check-equal? (length resolved-source-values) 1)
          (check-equal? (member "user-interface/config.ss"
                                resolved-source-values)
                        #f)
          (check-equal? resolved-source-values
                        '("user-interface/init.ss"))
          (check-equal? lazy-loader-call-count 0))))

;; : TestSuite
(def module-system-lazy-loader-test
  (test-suite "agentic-ai-lab module system lazy loader"
    (module-system-lazy-loader-large-registry-case)
    (module-system-lazy-loader-deferred-standard-library-case)
    (module-system-lazy-loader-module-tree-case)
    (module-system-lazy-loader-src-modules-case)
    (module-system-lazy-loader-user-root-case)
    (module-system-user-root-authoring-contract-case)
    (module-system-lazy-loader-aitia-submodule-source-case)
    (module-system-lazy-loader-auto-import-removal-case)))
