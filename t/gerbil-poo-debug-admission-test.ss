;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: direct gerbil-poo debug consumption, never semantic evidence authority.
;;; All output uses in-memory ports and synthetic canaries, never real secrets.
(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite check-equal?)
        (only-in :clan/poo/support/debug traced-function)
        (only-in :clan/poo/debug DDT trace-poo)
        (only-in :clan/poo/object .o .ref .call .all-slots compute-precedence-list!)
        (only-in :clan/poo/mop define-type Type.)
        (only-in :yuanxu/module-system/schema/relations
                 SemanticImports. yuanxu-semantic-identity)
        :yuanxu/module-system/authoring/roles
        (only-in :agentic-ai-lab/modules/module-authoring/semantic-module UserConfigSourceRole. agentic-ai-lab-user-root-module-authoring-profile))
(export gerbil-poo-debug-admission-test)

(define-type (DebugSymbol @ Type.)
  .element?: symbol?
  .sexp<-: (lambda (value) (list 'debug-symbol value)))

;; Keep captures test-local. This is not a telemetry sink or an output sanitizer.
(def (contains? text fragment) (if (string-contains text fragment) #t #f))

(def gerbil-poo-debug-admission-test
  (test-suite "native POO debug admission"
    (yuanxu-test-case "DDT uses the explicit native Type projection and preserves result"
      (let ((port (open-output-string)) (evaluations 0))
        (parameterize ((current-error-port port))
          (check-equal? (DDT 'typed DebugSymbol
                         (begin (set! evaluations (1+ evaluations)) 'value)) 'value))
        (check-equal? evaluations 1)
        (check-equal? (contains? (get-output-string port) "(debug-symbol value)") #t)))

    (yuanxu-test-case "disabled DDT skips diagnostic expressions, not the final expression"
      (let ((port (open-output-string)) (diagnostics 0) (evaluations 0))
        (parameterize ((current-error-port port))
          (check-equal?
           (DDT #f #f (begin (set! diagnostics (1+ diagnostics)) 'unused)
                DebugSymbol (begin (set! evaluations (1+ evaluations)) 'value)) 'value))
        (check-equal? diagnostics 0)
        (check-equal? evaluations 1)
        (check-equal? (get-output-string port) "")))

    (yuanxu-test-case "trace variant is lazy but has a distinct receiver and cache"
      (let ((evaluations 0) (port (open-output-string)))
        (let* ((original (.o (:: self)
                            (payload (begin (set! evaluations (1+ evaluations)) 'value))
                            (receiver (lambda () self))))
               (wrapped (trace-poo original 'safe-debug-name)))
          (check-equal? evaluations 0)
          (check-equal? (eq? original wrapped) #f)
          (check-equal? (if (memq original (compute-precedence-list! wrapped)) #t #f) #t)
          (check-equal? (length (.all-slots wrapped)) 2)
          (check-equal? (.ref wrapped 'payload) 'value)
          (check-equal? (.ref wrapped 'payload) 'value)
          (check-equal? evaluations 1)
          (check-equal? (.ref original 'payload) 'value)
          (check-equal? evaluations 2)
          ;; Returning a POO receiver can trigger repr; use a non-outputting
          ;; port, and do not treat its representation as canonical evidence.
          (parameterize ((current-error-port port))
            (check-equal? (eq? (.call wrapped receiver) wrapped) #t)
            (check-equal? (eq? (.call original receiver) original) #t)))))

    (yuanxu-test-case "real Module debug view does not force its import relation"
      (let* ((imports (.o (:: @ SemanticImports.)
                         (contributions (error "debug forced lazy import contributions"))))
             (module (yuanxu-semantic-module
                      (yuanxu-semantic-identity 'debug 'module) imports: imports))
             (wrapped (trace-poo module 'safe-module-name)))
        (check-equal? (length (.all-slots wrapped)) 5)
        (check-equal? (eq? (.ref wrapped 'imports) imports) #t)
        (check-equal? (eq? (.ref wrapped 'identity) (.ref module 'identity)) #t)))

    (yuanxu-test-case "function trace preserves multiple values and reports calls"
      (let* ((port (open-output-string))
             (traced (traced-function 'pair (lambda (x) (values x (1+ x))) port)))
        (check-equal? (call-with-values (lambda () (traced 4)) list) '(4 5))
        (let (output (get-output-string port))
          (check-equal? (contains? output ">>> 0") #t)
          (check-equal? (contains? output "<<< 0") #t))))

    (yuanxu-test-case "function trace propagates the identical exception without a return event"
      (let* ((port (open-output-string)) (failure (list 'synthetic-failure))
             (traced (traced-function 'failing (lambda () (raise failure)) port))
             (caught (with-exception-catcher (lambda (value) value) traced)))
        (check-equal? (eq? caught failure) #t)
        (let (output (get-output-string port))
          (check-equal? (contains? output ">>> 0") #t)
          (check-equal? (contains? output "<<< 0") #f))))

    (yuanxu-test-case "raw debug output is not a redaction boundary"
      (let ((port (open-output-string)) (canary "SYNTHETIC-DEBUG-CANARY"))
        (parameterize ((current-error-port port))
          (check-equal? (DDT 'invalid DebugSymbol canary) canary))
        (let (output (get-output-string port))
          (check-equal? (contains? output "TYPE ERROR") #t)
          (check-equal? (contains? output canary) #t)))
      (let ((port (open-output-string)) (canary "SYNTHETIC-CONVERSION-CANARY"))
        (parameterize ((current-error-port port))
          (check-equal? (DDT 'conversion (lambda (_) (error "conversion failed")) canary) canary))
        (let (output (get-output-string port))
          (check-equal? (contains? output "CONVERSION ERROR") #t)
          (check-equal? (contains? output canary) #t))))))
