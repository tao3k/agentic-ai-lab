;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Entry projection only: installed native harnesses still own the suites.
(import :clan/poo/object
        (only-in "./qualification.ss" qualification-script)
        (only-in "./package-result.ss" admit-package-batches)
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
    ((package)
     (.cc (qualification-script '("dev/unit-tests.ss")
            (list "gerbil" vm "env" "gxi" vm "./dev/unit-tests.ss") 1200
            inputs: (list (this-source-file) "t/qualification/testing/package-result.ss"))
       '.admit-result admit-package-batches))
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
     (runner "t/harness/temporal-evaluator-runner.ss" "t/temporal-evaluator-test.ss" 28))
    ((ascent-temporal)
     (runner "t/harness/ascent-temporal-runner.ss" "t/ascent-temporal-lens-test.ss" #f
       '("CASE-OK POO values keep native evidence separate from cut authority"
         "CASE-OK explicit cut bridge preserves uncertainty and original identity binding")
       (list "gerbil" vm "env" "gerbil" vm "t/harness/ascent-temporal-runner.ss")))
    ((context-temporal)
     (let* ((runner "t/harness/context-temporal-runner.ss")
            (progress "t/harness/scheme-progress.ss")
            (files (map (lambda (name)
                          (absolute (string-append ".gerbil/lib/agentic-ai-lab/t/" name "-test.ssi")))
                     '("temporal-evaluator" "ai-agentic-context-session-host"
                       "ai-agentic-context-delta" "session-attempt"
                       "ai-agentic-context-org-anchors" "query-orgize-source"))))
       (native files (watched (append (interpreted runner) files))
         45 69 (list runner progress watch))))
    (else (error "unknown specialized qualification" name))))

(def (main name vm . arguments)
  (display (.get (.call (selected-script name vm arguments) .run) output)))
;; gxi invokes main after loading the script; never invoke it again here.
