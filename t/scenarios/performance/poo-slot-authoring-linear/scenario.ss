;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A/B witness for the retired recursive-append POO slot source walker versus
;;; the production tail-passing implementation. The baseline is evidence only;
;;; it is not a second runtime or a public compatibility path.

(import (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :core/module-system/observability/presentation
                 poo-flow-poo-slot-authoring-datum-bindings))

(def +nesting-depth+ 300)
(def fixture
  (call-with-input-file
   "t/scenarios/performance/poo-slot-authoring-linear/benchmark.ss"
   read))

(def (nested-object depth)
  (if (zero? depth)
    '(.o leaf: leaf-value)
    (list '.o
          'depth: depth
          'child: (nested-object (- depth 1)))))

(def source-datum (nested-object +nesting-depth+))

(def (baseline-form-bindings elements)
  (cond
   ((null? elements) '())
   ((not (pair? elements)) '())
   ((and (keyword? (car elements))
         (pair? (cdr elements)))
    (cons (cons (string->symbol (keyword->string (car elements)))
                (cadr elements))
          (baseline-form-bindings (cddr elements))))
   ((and (pair? (car elements))
         (symbol? (caar elements))
         (pair? (cdar elements))
         (null? (cddar elements)))
    (cons (cons (caar elements) (cadar elements))
          (baseline-form-bindings (cdr elements))))
   (else
    (baseline-form-bindings (cdr elements)))))

;;; This intentionally reproduces the former result-list reconstruction.
(def (baseline-bindings datum)
  (cond
   ((not (pair? datum)) '())
   ((and (memq (car datum) '(quote quasiquote syntax quasisyntax))
         (pair? (cdr datum)))
    '())
   (else
    (let* ((head (car datum))
           (object-elements
            (cond
             ((eq? head '.o) (cdr datum))
             ((and (eq? head '.def) (pair? (cdr datum))) (cddr datum))
             (else '())))
           (local-bindings (baseline-form-bindings object-elements)))
      (append local-bindings
              (baseline-bindings (car datum))
              (baseline-bindings (cdr datum)))))))

(unless (benchmark-fixture-contract-pass? fixture)
  (error "invalid ASP benchmark fixture" fixture))

(let-values (((baseline-receipt baseline-value)
              (benchmark-run/result
               fixture
               (lambda () (baseline-bindings source-datum)))))
  (let-values (((candidate-receipt candidate-value)
                (benchmark-run/result
                 fixture
                 (lambda ()
                   (poo-flow-poo-slot-authoring-datum-bindings source-datum)))))
    (unless (equal? baseline-value candidate-value)
      (error "tail-passing POO slot walk changed source-order semantics"))
    (unless (benchmark-receipt-pass? candidate-receipt)
      (error "tail-passing POO slot walk exceeded ASP benchmark budget"
             candidate-receipt))
    (unless (< (benchmark-fixture-ref candidate-receipt 'elapsedNs)
               (benchmark-fixture-ref baseline-receipt 'elapsedNs))
      (error "tail-passing POO slot walk did not improve deep traversal"
             baseline-receipt candidate-receipt))
    (display "[poo-flow-benchmark] poo-slot-authoring-linear baseline=")
    (write baseline-receipt)
    (display " candidate=")
    (write candidate-receipt)
    (displayln " semanticEquivalent=#t")
    (force-output)))
