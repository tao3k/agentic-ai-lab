;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :clan/poo/object .get .cc .o)
        (only-in :std/source this-source-file)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :std/crypto/digest sha256)
        (only-in :yuanxu/ops/interface Ops)
        (only-in :yuanxu/ops/func run-script)
        (only-in :yuanxu/ops/progress execution-progress! make-test-progress-reader)
        (only-in :yuanxu/observability/testing-script make-compiler-progress-reader TestingScript.)
        (only-in :yuanxu/module-system/building/products artifact-files)
        (only-in :yuanxu/module-system/building/products current-build-output-directory)
        (only-in :yuanxu/module-system/source/admission module-source-read
                 call-with-module-source-operation-measurement call-with-module-source-read-cache)
        (only-in "./qualification/yuanxu-deployment-consumer/init.ss" yuanxu-deployment-consumer.init.exports)
        (rename-in (only-in "./qualification/yuanxu-deployment-consumer/build.ss" main)
                   (main deployment-build-main)))
(export yuanxu-deployment-downstream-test)

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

(def (compile-events output)
  (call-with-input-string output
    (lambda (port)
      (let loop ((events '()))
        (let (line (read-line port))
          (cond ((eof-object? line) (list-sort string<? events))
                ((string-prefix? "... compile " line)
                 (loop (cons (substring line 12 (string-length line)) events)))
                (else (loop events))))))))
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
          (def compiler-context-paths #f)
          (def (action state operation)
            (def start (real-time))
            (def returned-at #f)
            (displayln "LAB-DEPLOYMENT-ACTION start=" operation " environment=" (path-strip-directory state)
                       " epoch=" (time->seconds (current-time)))
            (force-output)
            (def result
              (measure-phase (list 'process operation (path-strip-directory state)) (lambda () (run-script
                (.cc (.get Ops prototypes Script)
                  command: (if (equal? operation "use") '("gxi" "use.ss") (list "gxi" "build.ss" operation))
                  directory: consumer timeout: 120 idle-timeout: 60
                  progress:
                  (lambda ()
                    (def read-progress (make-compiler-progress-reader))
                    (lambda (line)
                      ;; Observe delivery without granting liveness: only the
                      ;; original compiler reader advances the watchdog.
                      (when (string-prefix? "BUILD-STAGE main return at=" line)
                        (set! returned-at (time->seconds (current-time)))
                        (displayln "LAB-DEPLOYMENT-RETURN-RECEIVED epoch=" returned-at)
                        (force-output))
                      (read-progress line)))
                  environment: (.o GERBIL_PATH: state GAMBOPT: runtime-options
                    GERBIL_BUILD_VERBOSE: "2"
                    ;; Deliberately output-first for EVERY action. The init-owned
                    ;; projection must establish its input context itself.
                    GERBIL_LOADPATH: (string-join (cons (path-expand "lib" state) prerequisites) ":")))
                '() output-port: (current-error-port)))))
            (def output (.get result output))
            (when returned-at
              (displayln "LAB-DEPLOYMENT-RETURN-WAIT seconds="
                         (- (time->seconds (current-time)) returned-at))
              (force-output))
            (unless (equal? operation "use")
              ;; Products may override domain libraries at runtime. They must
              ;; never replace the native compiler's prerequisite Contexts.
              (let (contexts
                (call-with-input-string output
                  (lambda (port)
                    (let loop ((rows '()))
                      (let (line (read-line port))
                        (cond ((eof-object? line) (list-sort string<? rows))
                              ((string-prefix? "(BUILD-BOOTSTRAP-ROOT " line)
                               (loop (cons (car (reverse (call-with-input-string line read))) rows)))
                              (else (loop rows))))))))
              (check-equal? (pair? contexts) #t)
              (check-equal? (ormap (cut string-prefix? (string-append (path-expand "lib" state) "/") <>) contexts) #f)
              (if compiler-context-paths (check-equal? contexts compiler-context-paths)
                  (set! compiler-context-paths contexts))))
            (when (ormap (lambda (marker) (string-contains output marker))
                         '("*** ERROR" "ERROR CASE" "ERROR CHECK" "ERROR HARNESS" "Heap overflow" "Stack overflow"))
              (error "Deployment action reported failure" operation output))
            (displayln "LAB-DEPLOYMENT-ACTION return=" operation " seconds=" (- (real-time) start)
                       " epoch=" (time->seconds (current-time)))
            (force-output)
            (set! completed (1+ completed))
            (execution-progress! 'lab-deployment-actions completed)
            output)
          (def (cold-from-source-plan state)
            ;; Same native build.ss entry, same guarded POO source plan, another
            ;; native libdir. Artifact-cold does not require reparsing that plan.
            (def output
              (measure-phase 'cold-b (lambda () (call-with-output-string
                (lambda (port)
                  (parameterize ((current-build-output-directory (path-expand "lib" state))
                                 (current-output-port port) (current-directory consumer))
                    (deployment-build-main "compile")))))))
            (display output) (force-output)
            output)
          ;; Source projection must not first warm business scopes. All first
          ;; .get/lazy/identity assertions execute in the independent B runtime.
          (defvalues (spec spec-times)
            (measure-phase 'specification (lambda () (call-with-module-source-operation-measurement
              (lambda ()
                (call-with-output-string
                  (lambda (out)
                    (parameterize ((current-output-port out) (current-directory consumer))
                      (deployment-build-main "spec"))))) accounting?: #f))))
          (check-equal? (hash-ref spec-times '(calls scope-factory) 0) 0)
          (check-equal? (hash-ref spec-times '(calls candidate-read) 0) 4)
          (execution-progress! 'lab-deployment-spec 1)
          (def targets (list-sort string<? (map cadr (call-with-input-string spec read))))
          (def selected-owners '(agentic-ai-lab/modules/nix/interface
                                 yuanxu/modules/json-schema/interface
                                 yuanxu/modules/funflow/interface
                                 agentic-ai-lab/modules/services/opentofu/interface))
          (def owner-prefixes '("agentic-ai-lab/modules/nix/" "agentic-ai-lab/modules/services/opentofu/"
                                "yuanxu/modules/json-schema/" "yuanxu/modules/funflow/"))
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
                                (and (string-prefix? "yuanxu/" target)
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
                               ((string-prefix? "yuanxu/" target)
                                (path-expand (string-append "core/" (substring target 7 (string-length target)) ".ss") root))
                               (else #f))) targets))))
          (def source-before (map module-source-read inputs))
          (check-equal? (interface-products a-lib) '())
          (for-each (lambda (state)
                      (def library (path-expand "lib" state))
                      (check-equal? (interface-products library) '())
                      (check-equal? (compile-events (if (equal? state a) (action state "compile")
                                                     (cold-from-source-plan state))) targets)
                      (check-equal? (interface-products library) targets)
                      (check-equal? (pair? (artifact-files identities library)) #t))
                    (list a b))
          (def b-products (measure-phase 'b-hashes-before (lambda () (product-digests (artifact-files identities b-lib)))))
          (def sentinel (path-expand "unrelated.ssi" a-lib))
          (call-with-output-file sentinel (lambda (port) (display "unrelated product" port)))
          (action a "clean")
          (check-equal? (interface-products a-lib) '("unrelated"))
          (check-equal? (artifact-files identities a-lib #f) '())
          (check-equal? (module-source-read sentinel) "unrelated product")
          (check-equal? (measure-phase 'b-hashes-after-clean (lambda () (product-digests (artifact-files identities b-lib)))) b-products)
          (check-equal? (compile-events (action b "compile")) '())
          (displayln "LAB-DEPLOYMENT-STAGE test-start at=" (real-time)) (force-output)
          (def test-result
            ;; The selected Suite consumes B's production products through the
            ;; existing harness. Test discovery supplies the exact file list.
            (.call (.cc TestingScript. source: acceptance-tests timeout: 120 idle-timeout: 60
                     progress: (lambda ()
                                 (make-test-progress-reader
                                   (lambda (line)
                                     (when (or (string=? line "OK\n") (string=? line "OK"))
                                       (displayln "LAB-DEPLOYMENT-STAGE child-ok at=" (real-time))
                                       (force-output)))))
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
