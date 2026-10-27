;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Entry projection only: installed native harnesses still own the suites.
(import :clan/poo/object
        (only-in "./qualification.ss" qualification-script)
        (only-in "../../../init.ss" agentic-ai-lab.init.exports)
        (only-in "../../../dev/modules/testing/native-harness-entry.ss"
                 make-native-harness-progress-reader)
        (only-in :std/source this-source-file))
(def root (path-expand "../../.." (path-directory (this-source-file))))
(def watch "packages/python-runtime/tools/watch.py")
(def (watched command) (append (list "python3" watch) command))
(def (absolute file) (path-expand file root))

(def (selected-script name vm arguments)
  (def (interpreted file) (list "gxi" vm file))
  (def (native files command seconds count (inputs '()) (lines '()))
    (qualification-script files command seconds case-count: count
      inputs: (cons (this-source-file) inputs) required-lines: lines))
  (def (runner file test count (lines '()) (command (interpreted file)))
    (native (list test) (watched command) 45 count (list file watch) lines))
  (case (string->symbol name)
    ((gerbil-runtime)
     (native '("t/gerbil-runtime-import-test.ss")
       (list "gerbil" vm "test" "t/gerbil-runtime-import-test.ss") 90 #f))
    ((gerbil-tool)
     (let* ((executable (car arguments))
            (file (cadr arguments))
            (home (getenv "GERBIL_HOME")))
       (unless (file-exists? executable) (error "test executable is missing" executable))
       (.cc (native (list file) (list executable vm file) 90 #f)
         'environment (.o GERBIL_HOME: home
                          GAMBOPT: (string-append "~~=" home ",~~bin=" home "/bin,~~lib=" home "/lib")))))
    ((runtime-ffi)
     (let (file (car arguments))
       (native (list file) (list "gerbil" vm "env" "gxtest" file) 120 #f)))
    ((module-ownership)
     (let (file "t/qualification/module-ownership/run.ss")
       (qualification-script (list file) (interpreted file) 120
         inputs: (list (this-source-file))
         harness: "HARNESS-OK module-ownership 7 suites")))
    ((query-native temporal-native)
     (let* ((query? (equal? name "query-native"))
            (files (map absolute
                     (if query?
                       '("t/query-core-test.ss" "t/query-orgize-source-test.ss" "t/evidence-assessment-core-test.ss")
                       '("t/temporal-applicability-test.ss" "t/temporal-lifecycle-test.ss"))))
            (executable (car arguments)))
       (unless (file-exists? executable) (error "test executable is missing" executable))
       (.cc (native files
              (watched (append (list executable vm "-v" "5") files))
              45 (if query? 24 13) (list watch))
         'environment (.o AGENTIC_AI_LAB_TEST_PROGRESS: "1"))))
    ((query-source)
     (runner "t/harness/query-orgize-source-runner.ss" "t/query-orgize-source-test.ss" 4))
    ((temporal-support)
     (runner "t/harness/temporal-support-runner.ss" "t/temporal-support-test.ss" 9 '()
       (list "gerbil" vm "env" "gerbil" vm "t/harness/temporal-support-runner.ss")))
    ((temporal-evaluator)
     (runner "t/harness/temporal-evaluator-runner.ss" "t/temporal-evaluator-test.ss" 58))
    ((ascent-temporal)
     (runner "t/harness/ascent-temporal-runner.ss" "t/ascent-temporal-lens-test.ss" #f
       '("CASE-OK POO values keep native evidence separate from cut authority"
         "CASE-OK explicit cut bridge preserves uncertainty and original identity binding")
       (list "gerbil" vm "env" "gerbil" vm "t/harness/ascent-temporal-runner.ss")))
    ((context-temporal)
     (let* ((demand
              (.call (.get agentic-ai-lab.init.exports tests) .for-files
                (list (absolute "t/qualification/context-temporal/interface.ss"))
                (list (this-source-file) (absolute watch)
                      (absolute "t/qualification/testing/native-harness.ss")
                      (absolute "dev/modules/testing/native-harness-entry.ss"))))
            (files (.get demand spec)))
       (.cc (.get demand execution)
         ;; Emit actual preparation timing so a compiler refusal remains
         ;; distinguishable from the independently bounded runtime worker.
         'profile (.cc (.get demand execution profile) 'emit? #t)
         'runtime-options (list vm)
         'progress make-native-harness-progress-reader
         'command
         (watched (append
           (list "gxi" vm (absolute "t/qualification/testing/native-harness.ss") "-v" "5") files))
         ;; Includes every real timer interleaving. Use the agreed complete
         ;; Context runtime envelope; the five-second output gate stays active.
         'timeout 150 'idle-timeout #f 'case-count 99)))
    (else (error "unknown specialized qualification" name))))

(def (main name vm . arguments)
  (def compile? (and (pair? arguments) (equal? (car arguments) "--compile")))
  (def script (selected-script name vm (if compile? (cdr arguments) arguments)))
  (if compile?
    (begin
      ;; Prepare the exact same source demand, inputs and compiler association
      ;; that execution will admit; a parallel file-only demand has another key.
      (.call script .compile)
      (displayln "TEST-COMPILE-OK " name))
    (display (.get (.call script .run) output))))
;; gxi invokes main after loading the script; never invoke it again here.
