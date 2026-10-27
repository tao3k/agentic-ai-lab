;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Exercise the real Core idle gate, not just the subprocess output watcher.
(import :clan/poo/object
        (only-in :std/error Error? Error-message)
        (only-in :std/source this-source-file)
        (only-in "../../../init.ss" agentic-ai-lab.init.exports)
        (only-in "../../../dev/modules/testing/native-test-observation.ss"
                 native-test-command make-native-test-progress-reader))

(def root (path-expand "../../.." (path-directory (this-source-file))))
(def (execution fixture vm)
  (def demand
    (.call (.get agentic-ai-lab.init.exports tests) .for-files
      (list (path-expand fixture root))
      (list (path-expand "dev/modules/testing/native-test-observation.ss" root)
            (this-source-file))))
  (.def (Script @ (.get demand execution))
    runtime-options: (list vm)
    command: => (cut native-test-command <> vm)
    progress: make-native-test-progress-reader
    profile: =>.+
    (.o emit?: #t max-idle-milliseconds: 5000 max-duration-milliseconds: 20000))
  Script)

(def (main vm)
  ;; Assert the actual inherited command before execution. A passing private
  ;; interpreter wrapper is not evidence for the Gerbil's public test entry.
  (def command (.get (execution "t/qualification/testing/native-progress-positive.ss" vm) command))
  (unless (and (equal? (take command 3) (list "gerbil" vm "test"))
               (not (member "gxi" command)))
    (error "native tests must retain the official Gerbil dispatcher" command))
  (def positive
    (.call (execution "t/qualification/testing/native-progress-positive.ss" vm) .run))
  (unless (zero? (.get positive status)) (error "native positive Harness failed"))
  (display (.get positive output))
  ;; The stock Gerbil can exit zero with ERROR CASE/CHECK. Its real failed
  ;; assertion must still be refused by the common parent receipt admission.
  (def failed
    (with-catch values
      (lambda ()
        (.call (execution "t/qualification/testing/native-progress-failure.ss" vm) .run)
        #f)))
  (unless (and (Error? failed)
               (member (Error-message failed)
                 '("native test harness reported failure" "Ops script failed")))
    (error "native failed Case must not become a passing receipt" failed))
  (displayln "NATIVE-HARNESS-FAILURE-OK failed-case=refused")
  ;; The fixture runs for ten seconds while demanding the SAME cached import.
  ;; Only the five-second idle gate can reject before its 20-second total gate.
  (def refused
    (with-catch values
      (lambda ()
        (.call (execution "t/qualification/testing/native-progress-idle.ss" vm) .run)
        #f)))
  (unless (and (Error? refused)
               (equal? (Error-message refused) "Ops execution budget exceeded"))
    (error "cached imports must not renew Core liveness" refused))
  (displayln "NATIVE-HARNESS-ADMISSION-OK positive=passed cached-import-idle=refused"))
