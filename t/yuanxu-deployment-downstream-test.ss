;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :clan/poo/object .get .cc .o)
        (only-in :std/source this-source-file)
        (only-in :gerbil/runtime/loader load-path set-load-path!)
        (only-in :gerbil/expander __module-registry module-context? module-context-path)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :std/crypto/digest sha256)
        (only-in :tao3k/yuanxu/ops/progress current-execution-progress execution-progress! make-test-progress-reader)
        (only-in :tao3k/yuanxu/observability/testing-script TestingScript. make-compiler-progress-reader)
        (only-in :tao3k/yuanxu/module-system/building/source-closure yuanxu-bootstrap-contexts)
        (only-in :tao3k/yuanxu/module-system/building/products artifact-files)
        (only-in :tao3k/yuanxu/module-system/building/products current-build-output-directory)
        (only-in :tao3k/yuanxu/module-system/source/admission module-source-read
                 call-with-module-source-operation-measurement call-with-module-source-read-cache)
        (only-in "./qualification/yuanxu-build-events.ss" compile-events)
        (only-in "./qualification/yuanxu-deployment-consumer/init.ss" yuanxu-deployment-consumer.init.exports)
        (rename-in (only-in "./qualification/yuanxu-deployment-consumer/build.ss" main)
                   (main deployment-build-main)))
(export yuanxu-deployment-downstream-test)

(def (report-specification-work times)
  ;; Nested spans are inclusive. Print only fixed stage names, never source
  ;; paths or the private accounting table.
  (for-each
    (lambda (stage)
      (let (calls (hash-ref times (list 'calls stage) 0))
        (when (positive? calls)
          (let (user (hash-get times (list 'cpu-user stage)))
            (write (append (list 'LAB-DEPLOYMENT-SPEC-WORK stage
                                 (cons 'calls calls)
                                 (cons 'wall (hash-ref times stage)))
                           (if user
                             (list (cons 'cpu (+ user (hash-ref times (list 'cpu-system stage)))))
                             '()))))
          (newline))))
    '(build-main build-specification build-selected-graph build-projection
      reader-bootstrap reader-native-import reader-role-import reader-preparation-start
      reader-interface-start reader-admission-start metadata-replay build-current))
  (force-output))

(def (measure-phase name action)
  ;; One native sample per coarse phase, with no read observer or scope demand.
  (def failed? #f)
  (def failure #f)
  (def stats
    (##exec-stats
      (lambda ()
        (with-catch
          (lambda (error) (set! failed? #t) (set! failure error) '())
          (lambda () (call-with-values action list))))))
  (write (list 'LAB-DEPLOYMENT-PHASE name
               (cons 'wall (cdr (assq 'real-time stats)))
               (cons 'user (cdr (assq 'user-time stats)))
               (cons 'system (cdr (assq 'sys-time stats)))
               (cons 'gc-wall (cdr (assq 'gc-real-time stats)))
               (cons 'failed? failed?)))
  (newline) (force-output)
  (if failed? (raise failure) (apply values (cdr (assq 'result stats)))))

;; Relay completed native compiler work while retaining its exact transcript.
(def (call-with-compiler-output action)
  (call-with-output-string
    (lambda (output)
      (defvalues (reader writer) (open-string-pipe '(direction: input)))
      (def progress (current-execution-progress))
      (def receive (make-compiler-progress-reader))
      (def drain
        (make-thread
          (lambda ()
            (parameterize ((current-execution-progress progress))
              (let loop ((line (read-line reader #\newline #t)))
                (unless (eof-object? line)
                  (receive line)
                  (display line output)
                  (loop (read-line reader #\newline #t))))))))
      (thread-start! drain)
      (dynamic-wind void
        (lambda () (parameterize ((current-output-port writer)) (action)))
        (lambda ()
          (close-output-port writer)
          (dynamic-wind void (lambda () (thread-join! drain))
            (lambda () (close-input-port reader))))))))

(def (interface-products directory (prefix ""))
  (list-sort string<?
    (foldl (lambda (name found)
             (let ((path (path-expand name directory)) (id (string-append prefix name)))
               (cond ((eq? (file-info-type (file-info path)) 'directory)
                      (append (interface-products path (string-append id "/")) found))
                     ((string-suffix? ".ssi" name) (cons (path-strip-extension id) found))
                     (else found))))
           '() (directory-files directory))))
(def (product-digests files)
  (map (lambda (path) (cons path (sha256 (call-with-input-file path read-all-as-u8vector)))) files))

(def yuanxu-deployment-downstream-test
  (test-suite "Independent downstream selects OpenTofu by deployment category"
    (test-case "first business read, selected native build and isolated cleanup"
      (check-equal?
        (compile-events
          (string-append
            "... compile ... execute compile job (compile-file example.scm)\nexample/target\n"
            "... compile example/other... execute compile job (compile-file other.scm)\n"))
        '("example/other" "example/target"))
      ;; The native harness has finished importing the suite. Report that
      ;; boundary before beginning a separate source projection phase.
      (execution-progress! 'lab-deployment-suite 1)
      (def root (path-normalize (path-expand ".." (path-directory (this-source-file)))))
      (def consumer (path-expand "t/qualification/yuanxu-deployment-consumer" root))
      (def prerequisites (load-path))
      (def runtime-options (getenv "GAMBOPT"))
      (call-with-temporary-directory "lab-deployment-"
        (lambda (temporary)
          (def a (path-expand "a" temporary))
          (def b (path-expand "b" temporary))
          (def a-lib (path-expand "lib" a))
          (def b-lib (path-expand "lib" b))
          (for-each create-directory* (list a-lib b-lib))
          (def completed 0)
          (def compiler-contexts '())
          (def (check-compiler-contexts!)
            (for-each
              (lambda (row)
                (check-equal? (eq? (cdr row) (hash-get __module-registry (car row))) #t))
              compiler-contexts))
          (def (from-source-plan state operation phase)
            ;; The same init-owned plan can address independent output roots.
            ;; Start output-first as the subprocess does. The native entry still
            ;; checks source authority before and after every artifact effect.
            (check-compiler-contexts!)
            (def libdir (path-expand "lib" state))
            (def previous (load-path))
            (def output
              (measure-phase phase
                (lambda ()
                  (call-with-compiler-output
                    (lambda ()
                      (parameterize ((current-build-output-directory libdir)
                                     (current-directory consumer))
                        (dynamic-wind
                          (lambda () (set-load-path! (cons libdir prerequisites)))
                          (lambda () (deployment-build-main operation))
                          (lambda () (set-load-path! previous)))))))))
            (check-compiler-contexts!)
            (display output) (force-output)
            (set! completed (1+ completed))
            (execution-progress! 'lab-deployment-actions completed)
            output)
          ;; Source projection must not first warm business scopes. All first
          ;; .get/lazy/identity assertions execute in the independent B runtime.
          (displayln "LAB-DEPLOYMENT-SPEC-START")
          (force-output)
          (defvalues (spec spec-times)
            (measure-phase 'specification (lambda () (call-with-module-source-operation-measurement
              (lambda ()
                (call-with-output-string
                  (lambda (out)
                    (parameterize ((current-output-port out) (current-directory consumer))
                      (deployment-build-main "spec"))))) accounting?: 'stages))))
          (report-specification-work spec-times)
          (check-equal? (hash-ref spec-times '(calls scope-factory) 0) 0)
          (check-equal? (hash-ref spec-times '(calls candidate-read) 0) 4)
          ;; Capture the exact native prerequisites of the source plan before
          ;; either output exists. A/B may resolve new products; they may not
          ;; replace the compiler contexts already bound to this plan.
          (hash-for-each
            (lambda (_ context)
              (when (module-context? context)
                (let (path (module-context-path context))
                  (when (and (string? path) (eq? context (hash-get __module-registry path)))
                    (check-equal? (string-prefix? temporary path) #f)
                    (set! compiler-contexts (cons (cons path context) compiler-contexts))))))
            (yuanxu-bootstrap-contexts))
          (check-equal? (pair? compiler-contexts) #t)
          (execution-progress! 'lab-deployment-spec 1)
          (def targets (list-sort string<? (map cadr (call-with-input-string spec read))))
          (def selected-owners '(agentic-ai-lab/modules/nix/interface
                                 yuanxu/modules/json-schema/interface
                                 yuanxu/modules/funflow/interface
                                 agentic-ai-lab/modules/services/opentofu/interface))
          (def owner-prefixes '("agentic-ai-lab/modules/nix/" "agentic-ai-lab/modules/services/opentofu/"
                                "tao3k/yuanxu/modules/json-schema/" "tao3k/yuanxu/modules/funflow/"))
          (def (selected-target? target) (ormap (cut string-prefix? <> target) owner-prefixes))
          (def selected-tests (.get yuanxu-deployment-consumer.init.exports tests))
          (def test-files (measure-phase 'test-discovery (lambda () (.get selected-tests spec))))
          (def qualification-tests (.get selected-tests qualification))
          (def runtime-tests (measure-phase 'qualification-discovery (lambda () (.get qualification-tests spec))))
          (check-equal? (length runtime-tests) 1)
          (check-equal? (.get qualification-tests selected-graph module-order) selected-owners)
          (def acceptance-files
            (.call selected-tests .for-files (append runtime-tests test-files)))
          (def module-current! (.get selected-tests admit-current))
          (def qualification-current! (.get qualification-tests admit-current))
          (def files-current! (.get acceptance-files admit-current))
          ;; One source object retains ALL discovery guards. The harness checks
          ;; it independently before/after execution; only pure reads within
          ;; each boundary share the existing observation window.
          (def acceptance-tests
            (.cc acceptance-files 'admit-current
              (lambda ()
                (measure-phase 'test-source-current
                  (lambda ()
                    (call-with-module-source-read-cache
                      (lambda () (module-current!) (qualification-current!) (files-current!))))))))
          (check-equal? (.get acceptance-tests selected-graph module-order) selected-owners)
          (check-equal? (.get selected-tests selected-graph module-order) selected-owners)
          (check-equal? (list-sort string<? test-files)
            (list-sort string<? (map (cut path-expand <> root)
              '("core/modules/json-schema/tests/atomic-test.ss"
                "core/modules/funflow/tests/atomic-test.ss"
                "modules/services/opentofu/tests/module-test.ss"))))
          ;; Dependency edges, not matching tags, bring these owners into Make.
          (for-each (lambda (prefix)
                      (check-equal? (and (member (string-append prefix "interface") targets) #t) #t))
                    owner-prefixes)
          (check-equal? (and (member "yuanxu-deployment-consumer/main" targets) #t) #t)
          (check-equal? (and (member "yuanxu-deployment-consumer/init" targets) #t) #t)
          ;; Package-kernel libraries (e.g. nix-contracts) may join through native
          ;; imports; unrelated managed Module roots may never enter this set.
          (check-equal? (filter (lambda (target)
                                (and (string-prefix? "agentic-ai-lab/modules/" target)
                                     (not (selected-target? target)))) targets) '())
          (check-equal? (filter (lambda (target)
                                (and (string-prefix? "tao3k/yuanxu/" target)
                                     (not (selected-target? target)))) targets) '())
          (def identities (map string->symbol targets))
          (def (installed-products)
            (foldr append '() (map (lambda (directory) (artifact-files identities directory #f)) prerequisites)))
          (def installed-before (measure-phase 'prerequisite-hashes-before (lambda () (product-digests (installed-products)))))
          (def inputs
            (cons (path-expand "init.ss" root)
              (cons (path-expand "init.ss" consumer)
                (filter-map (lambda (target)
                              (cond
                               ((string-prefix? "agentic-ai-lab/" target)
                                (path-expand (string-append (substring target 15 (string-length target)) ".ss") root))
                               ((string-prefix? "tao3k/yuanxu/" target)
                                (path-expand (string-append "core/" (substring target 7 (string-length target)) ".ss") root))
                               (else #f))) targets))))
          (def source-before (map module-source-read inputs))
          (check-equal? (interface-products a-lib) '())
          (for-each (lambda (state)
                      (def library (path-expand "lib" state))
                      (check-equal? (interface-products library) '())
                      (check-equal? (compile-events (from-source-plan state "compile" (if (equal? state a) 'cold-a 'cold-b))) targets)
                      (check-equal? (interface-products library) targets)
                      (check-equal? (pair? (artifact-files identities library)) #t))
                    (list a b))
          (def b-products (measure-phase 'b-hashes-before (lambda () (product-digests (artifact-files identities b-lib)))))
          (def sentinel (path-expand "unrelated.ssi" a-lib))
          (call-with-output-file sentinel (lambda (port) (display "unrelated product" port)))
          (from-source-plan a "clean" 'clean-a)
          (check-equal? (interface-products a-lib) '("unrelated"))
          (check-equal? (artifact-files identities a-lib #f) '())
          (check-equal? (module-source-read sentinel) "unrelated product")
          (check-equal? (measure-phase 'b-hashes-after-clean (lambda () (product-digests (artifact-files identities b-lib)))) b-products)
          (check-equal? (compile-events (from-source-plan b "compile" 'hot-b)) '())
          (displayln "LAB-DEPLOYMENT-STAGE test-start at=" (real-time)) (force-output)
          (def test-result
            ;; The selected Suite consumes B's production products through the
            ;; existing harness. Test discovery supplies the exact file list.
            (.call (.cc TestingScript. source: acceptance-tests timeout: 120 idle-timeout: 60
                     progress: (lambda ()
                                 (make-test-progress-reader
                                   (lambda (line)
                                     (cond
                                      ((or (string=? line "OK\n") (string=? line "OK"))
                                       (displayln "LAB-DEPLOYMENT-STAGE child-ok at=" (real-time))
                                       (force-output))
                                      ((or (string-prefix? "HARNESS " line)
                                           (string-prefix? "MODULE " line)
                                           (string-prefix? "LAB-DEPLOYMENT-USE " line)
                                           (string-prefix? "LAB-DEPLOYMENT-GET " line))
                                       ;; Keep real child boundaries visible even if .run is interrupted.
                                       (display (string-append "LAB-DEPLOYMENT-CHILD at="
                                                  (number->string (real-time)) " " line))
                                       (force-output))))))
                     environment: (.o GERBIL_PATH: b GAMBOPT: runtime-options
                       GERBIL_LOADPATH: (string-join (cons b-lib prerequisites) ":"))) .run))
          (check-equal? (.get test-result status) 0)
          (displayln "LAB-DEPLOYMENT-STAGE test-return at=" (real-time)) (force-output)
          (check-equal? (compile-events (.get test-result output)) '())
          (display (.get test-result output))
          (execution-progress! 'lab-deployment-selected-tests 1)
          (for-each (lambda (marker)
                      (check-equal? (and (string-contains (.get test-result output) marker) #t) #t))
                    '("schema=map-string" "LAB-DEPLOYMENT-PRODUCT-USE-OK"))
          (check-equal? (product-digests (installed-products)) installed-before)
          (displayln "LAB-DEPLOYMENT-STAGE prerequisite-hashes at=" (real-time)) (force-output)
          (check-equal? (map module-source-read inputs) source-before)
          (displayln "LAB-DEPLOYMENT-DOWNSTREAM-OK targets=" (length targets)
                     " profile=deployment roots=1 owners=4 selected-tests=3 runtime-qualification=1 cold=A/B hot=0 clean-isolation=ok"))))))
