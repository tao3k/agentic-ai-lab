;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; CLI policy only; init.exports owns discovery, preparation and execution.
(import :clan/poo/object
        (only-in "../init.ss" agentic-ai-lab.init.exports))
(def tests (.get agentic-ai-lab.init.exports tests))
;; These retain the previous ordinary-suite exclusions. Their dedicated
;; qualifications own provider, parser, native-artifact and performance inputs.
(def excluded
  '("qualification/ascent-integration" "qualification/temporal-mrr-native"
    "performance" "qualification/healthcare-fhir-reference-validator"
    "qualification/healthcare-fhirpath-syntax" "qualification/healthcare-hl7v2-migration"
    "qualification/standards-multi-industry" "module-system-poo-performance-test-support"))
(def (execution file vm-options seconds observation)
  (unless (member observation '("false" "true" "trace"))
    (error "observe must be false, true, or trace" observation))
  (def budget (string->number seconds))
  (unless (and (exact-integer? budget) (> budget 0))
    (error "test budget must be a positive number of seconds" seconds))
  (def demand (.call tests .for-files (list file)))
  (.def (Test @ (.get demand execution))
    runtime-options: (list vm-options)
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
    ((run) (display (.get (.call (apply execution arguments) .run) output)))
    (else (error "unknown test operation" operation))))
