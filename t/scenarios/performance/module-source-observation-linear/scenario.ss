;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A/B witness for the retired recursive-append source walker versus the
;;; production tail-passing implementation.  The baseline exists only here as
;;; evidence; it is not an alternate runtime or public compatibility path.

(import (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :yuanxu/module-system/authoring/observation
                 yuanxu-scheme-lexical-call-shadow-datum-observations))

(def +nesting-depth+ 300)
(def +scope+ 'module-source-observation-linear)
(def fixture
  (call-with-input-file
   "t/scenarios/performance/module-source-observation-linear/benchmark.ss"
   read))
(def +shadowing-definition+
  '(def (shadowed-values values)
     (values values)))

(def (nested-source depth)
  (if (zero? depth)
    +shadowing-definition+
    (list 'begin
          (nested-source (- depth 1))
          +shadowing-definition+)))

(def source-datum (nested-source +nesting-depth+))

(def (definition-form? datum)
  (and (pair? datum)
       (memq (car datum) '(def define))
       (pair? (cdr datum))
       (pair? (cadr datum))))

;;; This intentionally reproduces the former result-list reconstruction.
(def (baseline-observations datum)
  (cond
   ((not (pair? datum)) '())
   ((memq (car datum) '(quote quasiquote syntax quasisyntax)) '())
   ((definition-form? datum)
    (yuanxu-scheme-lexical-call-shadow-datum-observations +scope+ datum))
   (else
    (append (baseline-observations (car datum))
            (baseline-observations (cdr datum))))))

(def (candidate-observations datum)
  (yuanxu-scheme-lexical-call-shadow-datum-observations +scope+ datum))

(unless (benchmark-fixture-contract-pass? fixture)
  (error "invalid ASP benchmark fixture" fixture))

(let-values (((baseline-receipt baseline-value)
              (benchmark-run/result
               fixture
               (lambda () (baseline-observations source-datum)))))
  (let-values (((candidate-receipt candidate-value)
                (benchmark-run/result
                 fixture
                 (lambda () (candidate-observations source-datum)))))
    (unless (equal? baseline-value candidate-value)
      (error "tail-passing source observation changed source-order semantics"))
    (unless (benchmark-receipt-pass? candidate-receipt)
      (error "tail-passing source observation exceeded ASP benchmark budget"
             candidate-receipt))
    (unless (< (benchmark-fixture-ref candidate-receipt 'elapsedNs)
               (benchmark-fixture-ref baseline-receipt 'elapsedNs))
      (error "tail-passing source observation did not improve deep traversal"
             baseline-receipt candidate-receipt))
    (display "[agentic-ai-lab-benchmark] module-source-observation-linear baseline=")
    (write baseline-receipt)
    (display " candidate=")
    (write candidate-receipt)
    (displayln " semanticEquivalent=#t")
    (force-output)))
