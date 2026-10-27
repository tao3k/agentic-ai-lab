;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; CLI policy only; init.exports owns discovery, preparation and execution.
(import :clan/poo/object
        (only-in "../build-spec.ss" agentic-ai-lab-native-build-spec agentic-ai-lab-test-exclusions)
        (only-in :std/source this-source-file)
        (only-in :yuanxu/module-system/building/test-projection module-test-execution)
        (only-in "./modules/testing/build-inspection.ss" write-native-test-build-inspection)
        (only-in "./modules/testing/native-test-observation.ss"
                 native-test-command make-native-test-progress-reader)
        (only-in "../init.ss" agentic-ai-lab.init.exports))
(def tests (.get agentic-ai-lab.init.exports tests))
;; These retain the previous ordinary-suite exclusions. Their dedicated
;; qualifications own provider, parser, native-artifact and performance inputs.
(def excluded agentic-ai-lab-test-exclusions)
(def (test-demand file)
  (def root (path-expand ".." (path-directory (this-source-file))))
  ;; Selection owns the same input snapshot for execution and explicit build
  ;; inspection. Only the inspection operation asks for its compiler projection.
  (.call tests .for-files (list file)
    (map (cut path-expand <> root)
      '("build-spec.ss" "bindings/nono-c/nono.h"
        "dev/modules/testing/native-test-observation.ss"))
    (agentic-ai-lab-native-build-spec)))
(def (execution file vm-options seconds observation)
  (unless (member observation '("false" "true" "trace"))
    (error "observe must be false, true, or trace" observation))
  (def budget (string->number seconds))
  (unless (and (exact-integer? budget) (> budget 0))
    (error "test budget must be a positive number of seconds" seconds))
  ;; Bind both the compiler declaration and its foreign header to the same
  ;; source epoch as the selected suite; changed bytes require a fresh demand.
  (def demand (test-demand file))
  ;; The package build already owns support compilation. Reuse the existing
  ;; resource/receipt policy with the guarded source, without a compiler
  ;; association or another import-graph reconstruction before gerbil test.
  (.def (Test @ (module-test-execution (.get demand source)))
    runtime-options: (list vm-options)
    command: => (cut native-test-command <> vm-options)
    progress: make-native-test-progress-reader
    profile: =>.+
    (.o max-duration-milliseconds: (* 1000 budget)
        emit?: (not (equal? observation "false"))
        trace-enabled?: (equal? observation "trace")))
  Test)
(def (main operation . arguments)
  (case (string->symbol operation)
    ((list)
     (unless (null? arguments) (error "test list takes no arguments"))
     (let (files (.get (.call tests .for-directory "t" excluded) spec))
       (unless (pair? files) (error "package test selection is empty"))
       (for-each displayln files)))
    ((compile)
     (unless (= (length arguments) 2) (error "compile requires a test module and VM options"))
     (.call (execution (car arguments) (cadr arguments) "120" "true") .compile)
     (displayln "TEST-COMPILE-OK " (car arguments)))
    ((inspect)
     (unless (= (length arguments) 2) (error "inspect requires a test module and VM options"))
     (write-native-test-build-inspection (.get (test-demand (car arguments)) build)))
    ((run) (display (.get (.call (apply execution arguments) .run) output)))
    (else (error "unknown test operation" operation))))
