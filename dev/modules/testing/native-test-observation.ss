;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Observe the Gerbil test command without replacing its dispatcher.
(import (only-in :yuanxu/ops/progress make-test-progress-reader))
(export native-test-command make-native-test-progress-reader)

(def (native-test-command inherited vm)
  ;; Keep every Gerbil feature and selected file supplied by TestingScript.
  ;; Refuse a different command shape rather than dropping unknown arguments.
  (unless (and (list? inherited) (>= (length inherited) 3)
               (equal? (car inherited) "gerbil")
               (equal? (cadr inherited) vm)
               (equal? (caddr inherited) "test"))
    (error "native Harness adapter requires the declared Gerbil test command" inherited))
  ;; The official dispatcher owns package setup, discovery and execution.
  ;; Verbosity exposes its real Case boundaries; it must never be rewritten
  ;; into an interpreter invocation of a private replacement Harness.
  (append (take inherited 3) '("-v" "5") (cdddr inherited)))

(def (make-native-phase-reader)
  (def started (real-time))
  (def prepared #f)
  (def harness #f)
  (def harness-complete? #f)
  (def active '())
  (def cases 0)
  (def case-seconds 0)
  (def consistent? #t)
  (def emitted? #f)
  (lambda (raw)
    ;; Ops preserves line terminators in the captured Gerbil transcript.
    (def line
      (let trim ((end (string-length raw)))
        (if (and (> end 0) (memv (string-ref raw (- end 1)) '(#\newline #\return)))
          (trim (- end 1)) (substring raw 0 end))))
    (def now (real-time))
    (cond
      ((and (not prepared) (string-prefix? "HARNESS " line))
       (set! harness (substring line 8 (string-length line)))
       (set! prepared (- now started))
       (parameterize ((current-output-port (current-error-port)))
         (displayln "test-native-phases before-harness-seconds=" prepared)
         (force-output)))
      ;; Nested Gerbil Harnesses can finish while an outer Case is active.
      ;; Only the original Harness's own receipt identifies this diagnostic
      ;; span; a nested OK must not truncate its Case count or elapsed time.
      ((and harness (equal? line (string-append "HARNESS-OK " harness)))
       (set! harness-complete? #t))
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
      ((and (not emitted?) harness-complete? (null? active)
            (equal? line "OK"))
       (set! emitted? #t)
       ;; This is diagnostic data, never a progress event or pass receipt.
       ;; The parent still admits the original Gerbil output and natural exit.
       (parameterize ((current-output-port (current-error-port)))
         (displayln
           "test-native-phases before-harness-seconds=" prepared
           " case-seconds=" case-seconds " case-spans=" cases
           " until-final-OK-seconds=" (- now started)
           " complete-spans?=" (and consistent? (null? active)))
         (force-output))))))

(def (make-native-test-progress-reader)
  ;; Observe the Gerbil's own Case boundaries and existing Core progress records.
  ;; The Gerbil callback observer reports completed cold imports separately;
  ;; this reader owns no dispatcher, import interception or synthetic events.
  (make-test-progress-reader (make-native-phase-reader)))
