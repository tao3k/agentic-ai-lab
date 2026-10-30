;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object "./qualification/opentofu/objects.ss"
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/error Error? Error-message)
        (only-in :yuanxu/module-system/source/admission module-source-read module-source-admit-current!)
        (only-in :agentic-ai-lab/modules/nix/objects NixSource.)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/object-types/contracts yuanxu-predicate-contract))
(export ops-selected-packages-test)
(def SelectedPackages. (.get Ops prototypes SelectedPackages))
(def ObjectContract (yuanxu-predicate-contract 'ops/test-object object? (lambda (_v _c) '())))
(def (selection accepted? (other '()) (observe void))
  (let (request
        (.o identity: 'package input-files: '(("selection.json" . "{}"))
            .realize: (lambda (_directory check!)
                        (.o guard-imports: '() guard-forms: '()
                            admission: (.call ObjectContract .admit (if accepted? (.o) #f) #f)
                            admit-current: (lambda () (check!) (observe))))))
    (.o build-graph:
        (.o source-inputs: '() other-projections: other external-packages: (list request)
            admit-current: void))))
(def ops-selected-packages-test
  (test-suite "Native Ops consumes selected external packages"
    (yuanxu-test-case "native chains normalize boundaries and opaque callbacks keep fresh guards"
      (call-with-temporary-directory "ops-native-package-prefix"
        (lambda (root)
          ;; Real Nix publication and SelectedPackages composition; only the
          ;; external commands are probes. AWS retains real Nix in init .run.
          (def path (path-expand "configuration.ss" root))
          (def (write-source! text)
            (call-with-output-file (list path: path truncate: #t) (cut display text <>)))
          (write-source! "version-one")
          (def observed (list (cons path (module-source-read path))))
          (def checks 0)
          (def instantiations 0)
          (def change? #f)
          (def native-change? #f)
          (def override? #f)
          (def promote? #f)
          (def entry-to-change #f)
          (.def (Source @ NixSource.)
            .instantiate: (lambda ()
                            (set! instantiations (+ instantiations 1))
                            (when native-change? (write-source! "version-two"))
                            (when entry-to-change
                              (call-with-output-file (list path: entry-to-change truncate: #t)
                                (cut display "changed during native action" <>)))
                            "/nix/store/native-prefix.drv")
            .realize: (lambda (_derivation) "/nix/store/native-prefix-artifact")
            .guard-form: (lambda (_derivation) #t))
          (def request
            (.o identity: 'package input-files: '()
              .realize:
              (lambda (_directory check!)
                (def native (.call Source .prepare check!))
                (if override?
                  (.cc native 'admit-current
                    (lambda () (check!) (when change? (write-source! "version-two"))))
                  native))))
          (def selected
            (.o build-graph:
              (.o source-inputs: observed other-projections: '()
                external-packages: (list request)
                admit-current: (lambda ()
                                 (set! checks (+ checks 1))
                                 (module-source-admit-current! observed)))))
          (def (prepare name (requests (list request)))
            (.call (.cc SelectedPackages.
                       selection:
                       (.cc selected 'build-graph
                         (.cc (.get selected build-graph) 'external-packages requests))
                       directory: (path-expand name root)) .run))
          (def (stale? exception)
            (and (Error? exception)
                 (string=? (Error-message exception)
                   "stale selected build input; regenerate the build entry")))
          (def result (prepare "native"))
          (set! checks 0)
          (.call result admit-current)
          ;; One initial check plus one fresh native post-effect check.
          (check-equal? checks 2)
          (def multi
            (prepare "multi" (list (.cc request 'identity 'first)
                                    (.cc request 'identity 'second))))
          (set! checks 0)
          (.call multi admit-current)
          ;; Every effect still has a fresh tail: one initial plus two tails.
          (check-equal? checks 3)
          ;; Check the composition law beyond one adjacent pair. These native
          ;; command probes require no process or second test runner.
          (for-each
            (lambda (names)
              (def batch
                (prepare (string-append "native-" (number->string (length names)))
                  (map (lambda (name) (.cc request 'identity name)) names)))
              (set! checks 0)
              (.call batch admit-current)
              (check-equal? checks (+ 1 (length names))))
            '(() (a b c d) (a b c d e f g h)))
          (set! native-change? #t)
          (check-exception (.call result admit-current) stale?)
          (set! native-change? #f)
          ;; A replaced method must not inherit the native prefix allowance.
          (write-source! "version-one")
          (set! change? #f)
          (set! override? #t)
          (def custom (prepare "custom"))
          (set! change? #t)
          (check-exception (.call custom admit-current) stale?)
          (write-source! "version-one")
          (set! change? #f)
          (set! override? #f)
          (def opaque
            (.cc request 'identity 'opaque '.realize
              (lambda (_directory check!)
                (def native (.call Source .prepare check!))
                (def invoke (.get native admit-current))
                (def operation (.get native %source-operation))
                (def value
                  (.cc native 'admit-current
                    (lambda ()
                      (check!)
                      ;; Fault injection: installing native-looking metadata
                      ;; AFTER an opaque call must not certify its return.
                      (when promote?
                        (.put! value '%source-operation operation)
                        (.put! value 'admit-current invoke)
                        (.get value admit-current))
                      (when change? (write-source! "version-two")))))
                value)))
          (def opaque-first (prepare "opaque-first" (list opaque request)))
          (set! instantiations 0)
          (set! change? #t)
          (check-exception (.call opaque-first admit-current) stale?)
          ;; The next native entry must refuse BEFORE its query can execute.
          (check-equal? instantiations 0)
          (write-source! "version-one")
          (set! change? #f)
          (def opaque-last (prepare "opaque-last" (list request opaque)))
          (set! promote? #t)
          (set! change? #t)
          (check-exception (.call opaque-last admit-current) stale?)
          ;; Tail reuse covers inputs only. The separately generated entry
          ;; must still be checked AFTER a native action that modifies it.
          (write-source! "version-one")
          (set! change? #f)
          (set! entry-to-change (.get result guard-entry))
          (check-exception (.call result admit-current) stale?))))
    (yuanxu-test-case "a warm package callback cannot borrow its preceding source window"
      (call-with-temporary-directory "ops-package-warm-source"
        (lambda (root)
          ;; A callback probe, not a Nix fixture: the real AWS Case exercises
          ;; the same SelectedPackages boundary with Nix and Schema updates.
          (def source (path-expand "configuration.ss" root))
          (def (write-source! text)
            (call-with-output-file (list path: source truncate: #t)
              (cut display text <>)))
          (write-source! "version-one")
          (def observed (list (cons source (module-source-read source))))
          (def change? #f)
          (def request
            (.o identity: 'package input-files: '()
              .realize:
              (lambda (_directory check!)
                (.o guard-imports: '() guard-forms: '()
                  admit-current:
                  (lambda ()
                    (check!)
                    (when change? (write-source! "version-two")))))))
          (def selected
            (.o build-graph:
              (.o source-inputs: observed other-projections: '()
                external-packages: (list request)
                admit-current: (lambda () (module-source-admit-current! observed)))))
          (def result
            (.call (.cc SelectedPackages. selection: selected
                       directory: (path-expand "output" root)) .run))
          ;; Warm state does not make the replaceable callback effect-free.
          (.call result admit-current)
          (set! change? #t)
          (check-exception (.call result admit-current)
            (lambda (exception)
              (and (Error? exception)
                   (string=? (Error-message exception)
                     "stale selected build input; regenerate the build entry")))))))
    (yuanxu-test-case "source guard never repeats external package checking"
      (call-with-temporary-directory "ops-package-guards"
        (lambda (root)
          (def checks 0)
          (def result
            (.call (.cc SelectedPackages.
                     selection: (selection #t '() (lambda () (set! checks (+ checks 1))))
                     directory: root) .run))
          (check-equal? checks 1)
          (.call result sources-current)
          (check-equal? checks 1)
          (.call result admit-current)
          (check-equal? checks 2))))
    (yuanxu-test-case "publishes only after final admission and rechecks an edited guard"
      (call-with-temporary-directory "ops-packages"
        (lambda (root)
          (let (operation (.cc SelectedPackages. 'selection (selection #t) 'directory root))
            (let (result (.call operation .run))
              (check-equal? (file-exists? (.get result guard-entry)) #t)
              (.call result admit-current)
              (call-with-output-file (list path: (.get result guard-entry) truncate: #t)
                (cut display "tampered" <>))
              (check-exception (.call result admit-current) error?))))))
    (yuanxu-test-case "rejects failed admission and unsupported selected projections"
      (call-with-temporary-directory "ops-packages-reject"
        (lambda (root)
          (check-exception
           (.call (.cc SelectedPackages. 'selection (selection #f) 'directory (path-expand "invalid" root)) .run)
           error?)
          (check-exception
           (.call (.cc SelectedPackages. 'selection (selection #t '(unsupported)) 'directory (path-expand "other" root)) .run)
           error?))))
    (yuanxu-test-case "value validation cannot publish after changing package provenance"
      (call-with-temporary-directory "ops-package-admission-mutation"
        (lambda (root)
          (def current? #t)
          (def checks 0)
          (def validated? #f)
          (def request
            (.o identity: 'package input-files: '()
                .realize:
                (lambda (_directory check!)
                  (.o guard-imports: '() guard-forms: '()
                      admission: (begin (set! validated? #t) (set! current? #f)
                                   (.call ObjectContract .admit (.o) #f))
                      admit-current:
                      (lambda () (check!) (set! checks (1+ checks))
                        (unless current? (error "package changed during value admission")))))))
          (def view
            (.o build-graph:
                (.o source-inputs: '() other-projections: '()
                    external-packages: (list request) admit-current: void)))
          (check-exception
            (.call (.cc SelectedPackages. selection: view directory: root) .run) error?)
          (check-equal? validated? #t)
          (check-equal? checks 1))))))
