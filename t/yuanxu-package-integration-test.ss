;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product integration uses this package's actual declaration and native environment.
(import (only-in :std/test test-suite test-case check-equal?)
        (only-in :clan/poo/object .get)
        (only-in :std/source this-source-file)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :std/crypto/digest sha256)
        (only-in :yuanxu/ops/interface Ops)
        (only-in :yuanxu/ops/func run-script)
        (only-in :yuanxu/ops/progress execution-progress!)
        (only-in :yuanxu/observability/testing-script make-compiler-progress-reader TestingScript.)
        (only-in :yuanxu/module-system/source/admission module-source-read)
        (only-in :yuanxu/module-system/building/products artifact-files)
        (only-in "../init.ss" agentic-ai-lab.init.exports))
(export yuanxu-package-integration-test)
(def (product-snapshot targets directories)
  (map (lambda (path) (cons path (sha256 (call-with-input-file path read-all-as-u8vector))))
       (list-sort string<?
         (foldr append '()
           (map (lambda (directory) (artifact-files (map string->symbol targets) directory #f)) directories)))))
(def (compile-events output)
  (call-with-input-string output
    (lambda (port)
      (let loop ((events '()))
        (def line (read-line port))
        (cond ((eof-object? line) (list-sort string<? events))
              ((string-prefix? "... compile " line)
               (loop (cons (substring line 12 (string-length line)) events)))
              (else (loop events)))))))
(def yuanxu-package-integration-test
  (test-suite "Lab package consumes Yuanxu public declarations"
    (test-case "the package owns its build projection and native module demand"
      (check-equal? (procedure? (.get agentic-ai-lab.init.exports std-make-spec)) #t)
      (def started (real-time))
      (def scope (.get agentic-ai-lab.init.exports modules nix))
      (displayln "lab-business-get seconds=" (- (real-time) started))
      (force-output)
      (check-equal? (.get scope config nix) "nix")
      (check-equal? (eq? scope (.get agentic-ai-lab.init.exports modules nix)) #t))
    (test-case "package build owns only the selected real Lab closure"
      ;; Locate this package's fixture from the test source. The root test
      ;; projection admits other Lab owners and is not a consumer build input.
      (def package-root (path-normalize (path-expand ".." (path-directory (this-source-file)))))
      (def consumer (path-expand "t/qualification/yuanxu-nix-consumer" package-root))
      (def prerequisites (load-path))
      (def runtime-option (car (.get TestingScript. runtime-options)))
      (def runtime-environment
        (string-append (let (inherited-options (getenv "GAMBOPT" #f))
                       (if inherited-options (string-append inherited-options ",") ""))
                       (substring runtime-option 2 (string-length runtime-option))))
      (call-with-temporary-directory "lab-selected-package-"
        (lambda (temporary)
          (def a (path-expand "a" temporary))
          (def b (path-expand "b" temporary))
          (for-each (lambda (state) (create-directory* (path-expand "lib" state))) (list a b))
          (def completed-actions 0)
          (def (action state operation)
            (def started (real-time))
            (displayln "lab-package-action start=" operation
                       " environment=" (path-strip-directory state))
            (force-output)
            (def result
              (run-script
                (.cc (.get Ops prototypes Script)
                  command: (cond ((equal? operation "compile") '("gerbil" "pkg" "build" "."))
                                 ((equal? operation "clean") '("gerbil" "pkg" "clean" "."))
                                 ((equal? operation "use") '("gxi" "use.ss"))
                                 ((equal? operation "spec")
                                  '("./build.ss" "spec" "--modules" "nix"))
                                 (else (list "./build.ss" operation)))
                  directory: consumer timeout: 180 idle-timeout: 60
                  progress: make-compiler-progress-reader
                  environment: (.o GERBIL_PATH: state GAMBOPT: runtime-environment
                    ;; The spec command's stdout is a single Scheme datum.
                    GERBIL_BUILD_VERBOSE: (if (equal? operation "spec") "0"
                                            (getenv "GERBIL_BUILD_VERBOSE" "0"))
                    GERBIL_LOADPATH: (string-join
                                      (append (list (path-expand "lib" state)) prerequisites
                                              (list package-root)) ":")))
                '() output-port: (current-error-port)))
            (displayln "lab-package-action return=" operation
                       " environment=" (path-strip-directory state)
                       " seconds=" (- (real-time) started))
            (force-output)
            (def output (.get result output))
            (when (ormap (lambda (marker) (string-contains output marker))
                    '("*** ERROR" "ERROR CASE" "ERROR CHECK" "ERROR HARNESS" "Heap overflow" "Stack overflow"))
              (error "package action reported failure" operation output))
            ;; Successful native exit advances the lifecycle even when the
            ;; command has no compiler events (spec, use, or hot Make).
            (set! completed-actions (1+ completed-actions))
            (execution-progress! 'lab-package-action-completed completed-actions)
            output)
          (def original (module-source-read (path-expand "init.ss" package-root)))
          (def spec (call-with-input-string (action a "spec") read))
          (def targets (list-sort string<? (map cadr spec)))
          ;; Existing installed products are legitimate prerequisites, never
          ;; permission to borrow selected products or clean their environment.
          (def prerequisite-products (product-snapshot targets prerequisites))
          (def inputs
            (map (lambda (identity)
                   (def path
                     (path-expand
                       (string-append (substring identity 15 (string-length identity)) ".ss")
                       package-root))
                   (cons path (module-source-read path)))
                 (filter (cut string-prefix? "agentic-ai-lab/" <>) targets)))
          (def sentinel (path-expand "lib/unrelated.ssi" a))
          (call-with-output-file sentinel (lambda (port) (display "unrelated product" port)))
          (check-equal? (pair? targets) #t)
          (for-each (lambda (identity)
                      (unless (or (string-prefix? "agentic-ai-lab/modules/nix/" identity)
                                  (member identity '("agentic-ai-lab/nix-contracts" "yuanxu-nix-consumer/init" "yuanxu-nix-consumer/main")))
                        (error "unselected compiler owner" identity)))
                    targets)
          (check-equal? (and (member "agentic-ai-lab/modules/nix/progress" targets) #t) #t)
          (check-equal? (and (member "agentic-ai-lab/modules/nix/interface" targets) #t) #t)
          (check-equal? (compile-events (action a "compile")) targets)
          (for-each (lambda (identity)
                      (for-each (lambda (suffix)
                                  (check-equal? (file-exists? (path-expand (string-append "lib/" identity suffix) a)) #t))
                                '(".ssi" ".o1"))) targets)
          (check-equal? (compile-events (action a "compile")) '())
          (check-equal? (and (string-contains (action a "use") "LAB-SELECTED-USE-OK") #t) #t)
          ;; Both independent cold builds must match the original projection.
          ;; The hot build and business use already guard the unchanged inputs.
          (check-equal? (compile-events (action b "compile")) targets)
          (def b-products (product-snapshot targets (list (path-expand "lib" b))))
          (action a "clean")
          (check-equal? (artifact-files (map string->symbol targets) (path-expand "lib" a) #f) '())
          (check-equal? (product-snapshot targets (list (path-expand "lib" b))) b-products)
          (check-equal? (module-source-read sentinel) "unrelated product")
          (for-each (lambda (identity)
                      (for-each (lambda (suffix)
                                  (when (file-exists? (path-expand (string-append "lib/" identity suffix) a))
                                    (error "native clean retained a selected product" identity suffix))
                                  (check-equal? (file-exists? (path-expand (string-append "lib/" identity suffix) b)) #t))
                                '(".ssi" ".o1"))) targets)
          (check-equal? (product-snapshot targets prerequisites) prerequisite-products)
          (check-equal? (and (string-contains (action b "use") "LAB-SELECTED-USE-OK") #t) #t)
          (check-equal? (module-source-read (path-expand "init.ss" package-root)) original)
          (for-each (lambda (input) (check-equal? (module-source-read (car input)) (cdr input))) inputs))))))
