;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Entry projection only: installed native harnesses still own the suites.
(import :clan/poo/object
        (only-in "./qualification.ss" qualification-script)
        (only-in :yuanxu/module-system/building/test-projection
                 module-test-execution module-test-source-binding)
        (only-in "../../../dev/modules/testing/native-test-observation.ss"
                 make-native-test-progress-reader)
        (only-in :std/source this-source-file))
(def root (path-expand "../../.." (path-directory (this-source-file))))
(def watch "packages/python-runtime/tools/watch.py")
(def (watched command) (append (list "python3" watch) command))
(def (absolute file) (path-expand file root))

;; Only the Context demand needs the product init. Other qualifications consume
;; published libraries and must not eagerly lower the complete module selection.
;; Resolve the same init-owned tests value through the native expander once.
(def context-demand
  (delay
    (let ((exports (module-test-source-binding (absolute "init.ss")
                                             'agentic-ai-lab.init.exports))
          (project (module-test-source-binding (absolute "build-spec.ss")
                                              'agentic-ai-lab-context-test-demand)))
      (project exports))))

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
     (let (file (absolute "t/ascent-temporal-lens-test.ss"))
       ;; The native Harness owns imports, Suite discovery and exit status.
       ;; Preserve both original Cases and the existing worker deadlines.
       (native (list file)
         (watched (list "gerbil" vm "test" "-v" "5" "-D"
                        "yuanxu-module-test-observation" file))
         45 2 (list (absolute watch))
         '("CASE-OK POO values keep native evidence separate from cut authority"
           "CASE-OK explicit cut bridge preserves uncertainty and original identity binding"))))
    ((context-temporal)
     (let* ((demand (force context-demand))
            (files (.get demand spec)))
       (.o (:: script [(module-test-execution (.get demand source)
                         (lambda () (.get demand build)))])
         ;; Preparation remains separate from the bounded native worker.
         profile: (.cc (.get (module-test-execution (.get demand source)) profile) 'emit? #t)
         runtime-options: (list vm)
         progress: make-native-test-progress-reader
         command:
         (watched (append
           (list (.call (.get demand build) .program
                   'agentic-ai-lab/t/qualification/context-temporal/interface)
                 vm "-v" "5" "-D" "yuanxu-module-test-observation") files))
         ;; Keep every real timer interleaving and the existing byte watchdog.
         timeout: 150 idle-timeout: #f case-count: 99)))
    (else (error "unknown specialized qualification" name))))

(def (main name vm . arguments)
  (def compile? (and (pair? arguments) (equal? (car arguments) "--compile")))
  (def script (selected-script name vm (if compile? (cdr arguments) arguments)))
  (if compile?
    (begin
      ;; Preparation and execution consume the same init-owned demand.
      (.call script .compile)
      (displayln "TEST-COMPILE-OK " name))
    (display (.get (.call script .run) output))))
;; gxi invokes main after loading the script; never invoke it again here.
