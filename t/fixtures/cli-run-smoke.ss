;;; -*- Gerbil -*-
;;; Smoke file executed by `poo-flow run` for functional flow validation.

(import :poo-flow/modules/workflow/control-plane/api)

;;; CLI smoke arguments are parsed locally so `poo-flow run` can validate the
;;; compiled command path without depending on test harness state.
;; : [String]
(def args (cddr (command-line)))
;;; Default input keeps the fixture runnable with or without user arguments.
;; : Integer
(def input (if (null? args) 3 (string->number (car args))))
;;; The runner uses request-only runtime behavior so the smoke path stays pure.
;; : Runner
(def runner (make-runner (make-local-eager-strategy)
                         (make-request-only-adapter)))
;;; The flow exercises composition and arithmetic result projection in one
;;; minimal command-line fixture.
;; : Flow
(def flow
  (flow-then 'cli-smoke
             (flow-arr 'inc (lambda (x) (+ x 1)) 'number 'number)
             (flow-arr 'double (lambda (x) (* x 2)) 'number 'number)))
;;; Result is emitted below as the observable contract for CLI smoke tests.
;; : RunResult
(def result (runner-run runner flow input))

;; : (-> RunResult Unit)
(def (emit-cli-smoke-result! result)
  (display "poo-flow-run:")
  (write (run-result-value result))
  (newline))

(emit-cli-smoke-result! result)
