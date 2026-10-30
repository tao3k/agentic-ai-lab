;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A/B witness for the former list-indexed module closure versus the shared
;;; native hash admission index. The baseline is evidence only; it is not an
;;; alternate runtime or a public compatibility path.

(import (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :agentic-ai-lab/modules/module-authoring/module-descriptor
                 make-empty-agentic-ai-lab-module-descriptor
                 agentic-ai-lab-module-name
                 yuanxu-module-imports
                 agentic-ai-lab-module-import-configs
                 agentic-ai-lab-module-closure
                 agentic-ai-lab-module-names))

(def +module-count+ 1000)
(def fixture
  (call-with-input-file
   "t/scenarios/performance/module-closure-indexed/benchmark.ss"
   read))

(def modules
  (let loop ((index 0) (values-rev '()))
    (if (= index +module-count+)
      (reverse values-rev)
      (loop (+ index 1)
            (cons
             (make-empty-agentic-ai-lab-module-descriptor
              (string->symbol (string-append "module-" (number->string index)))
              '()
              '())
             values-rev)))))

(def (baseline-member-name? value names)
  (cond
   ((null? names) #f)
   ((equal? value (car names)) #t)
   (else (baseline-member-name? value (cdr names)))))

;;; This intentionally reproduces the former list-indexed reconstruction.
(def (baseline-closure/add pending seen-names)
  (cond
   ((null? pending) '())
   ((baseline-member-name? (agentic-ai-lab-module-name (car pending)) seen-names)
    (baseline-closure/add (cdr pending) seen-names))
   (else
    (let* ((module (car pending))
           (next-seen (cons (agentic-ai-lab-module-name module) seen-names))
           (inline-modules
            (agentic-ai-lab-module-import-configs (yuanxu-module-imports module))))
      (cons module
            (append (baseline-closure/add inline-modules next-seen)
                    (baseline-closure/add (cdr pending) next-seen)))))))

(def (baseline-closure values)
  (baseline-closure/add values '()))

(unless (benchmark-fixture-contract-pass? fixture)
  (error "invalid ASP benchmark fixture" fixture))

(let-values (((baseline-receipt baseline-value)
              (benchmark-run/result
               fixture
               (lambda () (baseline-closure modules)))))
  (let-values (((candidate-receipt candidate-value)
                (benchmark-run/result
                 fixture
                 (lambda () (agentic-ai-lab-module-closure modules)))))
    (unless (equal? (agentic-ai-lab-module-names baseline-value)
                    (agentic-ai-lab-module-names candidate-value))
      (error "indexed module closure changed distinct-module order"))
    (unless (benchmark-receipt-pass? candidate-receipt)
      (error "indexed module closure exceeded ASP benchmark budget"
             candidate-receipt))
    (unless (< (benchmark-fixture-ref candidate-receipt 'elapsedNs)
               (benchmark-fixture-ref baseline-receipt 'elapsedNs))
      (error "shared module closure index did not improve broad traversal"
             baseline-receipt candidate-receipt))
    (display "[agentic-ai-lab-benchmark] module-closure-indexed baseline=")
    (write baseline-receipt)
    (display " candidate=")
    (write candidate-receipt)
    (displayln " semanticEquivalent=#t")
    (force-output)))
