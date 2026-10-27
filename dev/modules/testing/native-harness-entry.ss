;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Adapt the existing SDK argv and relay completed native imports to Core.
(import (only-in :yuanxu/ops/progress make-test-progress-reader execution-progress!))
(export native-harness-command make-native-harness-progress-reader)

(def (native-harness-command inherited vm harness)
  ;; Keep every SDK feature and selected file supplied by TestingScript.
  ;; Refuse a different command shape rather than dropping unknown arguments.
  (unless (and (list? inherited) (>= (length inherited) 3)
               (equal? (car inherited) "gerbil")
               (equal? (cadr inherited) vm)
               (equal? (caddr inherited) "test"))
    (error "native Harness adapter requires the declared SDK test command" inherited))
  (append (list "gxi" vm harness) (cdddr inherited)))

(def (make-native-harness-progress-reader)
  (def completed 0)
  (def invocation (gensym 'native-harness))
  (make-test-progress-reader
    (lambda (line)
      ;; The SDK-only entry deduplicates exact contexts and phases. Repeated
      ;; cached imports produce no event; ordinary Core Case frames still pass
      ;; through the original reader unchanged.
      (when (string-prefix? "NATIVE-MODULE-OK " line)
        (set! completed (+ completed 1))
        (execution-progress! invocation completed)))))
