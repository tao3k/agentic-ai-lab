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
  ;; SDK Case notices provide real begin/end boundaries, including Cases that
  ;; use std/test directly. They do not change discovery or assertion policy.
  (append (list "gxi" vm harness "-v" "5") (cdddr inherited)))

(def (make-native-phase-reader)
  (def started (real-time))
  (def prepared #f)
  (def active '())
  (def cases 0)
  (def case-seconds 0)
  (def consistent? #t)
  (def emitted? #f)
  (lambda (raw)
    ;; Ops preserves line terminators in the captured SDK transcript.
    (def line
      (let trim ((end (string-length raw)))
        (if (and (> end 0) (memv (string-ref raw (- end 1)) '(#\newline #\return)))
          (trim (- end 1)) (substring raw 0 end))))
    (def now (real-time))
    (cond
      ((and (not prepared) (string-prefix? "HARNESS " line))
       (set! prepared (- now started))
       (parameterize ((current-output-port (current-error-port)))
         (displayln "test-native-phases before-harness-seconds=" prepared)
         (force-output)))
      ((string-prefix? "CASE " line)
       (if (< (length active) 4096)
         (set! active (cons (cons (substring line 5 (string-length line)) now) active))
         (set! consistent? #f)))
      ((or (string-prefix? "CASE-OK " line) (string-prefix? "ERROR CASE " line))
       (let (name (substring line (if (string-prefix? "CASE-OK " line) 8 11)
                             (string-length line)))
         (if (and (pair? active) (equal? name (caar active)))
           (let (begin (cdar active))
             (set! active (cdr active))
             (set! cases (+ cases 1))
             ;; Nested native harnesses can run inside integration Cases.
             ;; Count the outer span once rather than double counting its work.
             (when (null? active)
               (set! case-seconds (+ case-seconds (- now begin)))
               (when (>= (- now begin) 1)
                 (parameterize ((current-output-port (current-error-port)))
                   (displayln "test-native-case seconds=" (- now begin) " name=" name)
                   (force-output)))))
           (set! consistent? #f))))
      ((and (not emitted?) (equal? line "OK"))
       (set! emitted? #t)
       ;; This is diagnostic data, never a progress event or pass receipt.
       ;; The parent still admits the original SDK output and natural exit.
       (parameterize ((current-output-port (current-error-port)))
         (displayln
           "test-native-phases before-harness-seconds=" prepared
           " case-seconds=" case-seconds " case-spans=" cases
           " until-final-OK-seconds=" (- now started)
           " complete-spans?=" (and consistent? (null? active)))
         (force-output))))))

(def (make-native-harness-progress-reader)
  (def completed 0)
  (def invocation (gensym 'native-harness))
  (def phases (make-native-phase-reader))
  (make-test-progress-reader
    phases
    (lambda (line)
      ;; The SDK-only entry deduplicates exact contexts and phases. Repeated
      ;; cached imports produce no event; ordinary Core Case frames still pass
      ;; through the original reader unchanged.
      (when (string-prefix? "NATIVE-MODULE-OK " line)
        (set! completed (+ completed 1))
        (execution-progress! invocation completed)))))
