;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Exercise the real Core idle gate, not just the subprocess output watcher.
(import :clan/poo/object
        (only-in :std/error Error? Error-message)
        (only-in :std/source this-source-file)
        (only-in "../../../init.ss" agentic-ai-lab.init.exports)
        (only-in "../../../dev/modules/testing/native-harness-entry.ss"
                 native-harness-command make-native-harness-progress-reader))

(def root (path-expand "../../.." (path-directory (this-source-file))))
(def harness (path-expand "dev/native-harness.ss" root))
(def (execution fixture vm)
  (def demand
    (.call (.get agentic-ai-lab.init.exports tests) .for-files
      (list (path-expand fixture root))
      (list harness (path-expand "t/qualification/testing/native-harness.ss" root)
            (this-source-file))))
  (.def (Script @ (.get demand execution))
    runtime-options: (list vm)
    command: => (cut native-harness-command <> vm harness)
    progress: make-native-harness-progress-reader
    profile: =>.+
    (.o max-idle-milliseconds: 5000 max-duration-milliseconds: 20000))
  Script)

(def (main vm)
  (def positive
    (.call (execution "t/qualification/testing/native-progress-positive.ss" vm) .run))
  (unless (zero? (.get positive status)) (error "native positive Harness failed"))
  (display (.get positive output))
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
