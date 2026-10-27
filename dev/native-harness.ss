;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Give existing source-import completion events an invocation-local scope.
(import (only-in :yuanxu/ops/progress call-with-execution-progress)
        (rename-in (only-in "../t/qualification/testing/native-harness.ss" main)
                   (main sdk-harness-main)))
(export main)

(def (main . arguments)
  ;; Core's parent Script and native Cases own deadlines. This scope has no
  ;; sampler: only completed source imports and native Case work emit progress.
  (def owner (current-thread))
  (def diagnostic
    (and (getenv "AGENTIC_AI_LAB_HARNESS_DIAGNOSTICS" #f)
      (spawn
        (lambda ()
          (thread-sleep! 30)
          (thread-interrupt! owner
            (lambda ()
              (displayln "NATIVE-HARNESS-DIAGNOSTIC-BACKTRACE")
              (continuation-capture
                (lambda (continuation)
                  (display-continuation-backtrace continuation
                    (current-output-port) 0 1 0 80)))
              (force-output)))))))
  (try
    (call-with-execution-progress #f #f
      (lambda (_scope) (apply sdk-harness-main arguments)))
    (finally
      (when diagnostic
        (thread-terminate! diagnostic)
        (with-catch void (lambda () (thread-join! diagnostic)))))))
