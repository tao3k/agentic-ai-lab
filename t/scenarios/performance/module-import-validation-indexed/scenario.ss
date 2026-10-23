;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A/B witness for the retired per-import name-list scan versus the production
;;; shared native hash index. The baseline is evidence only; it is not an
;;; alternate runtime or public compatibility path.

(import (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :agentic-ai-lab/modules/module-authoring/module-descriptor
                 make-empty-agentic-ai-lab-module-descriptor
                 agentic-ai-lab-module-name
                 yuanxu-module-imports
                 agentic-ai-lab-module-import-profile
                 agentic-ai-lab-module-missing-imports))

(def +module-count+ 1000)
(def +shared-import+ 'module-999)
(def fixture
  (call-with-input-file
   "t/scenarios/performance/module-import-validation-indexed/benchmark.ss"
   read))

(def modules
  (let loop ((index 0) (values-rev '()))
    (if (= index +module-count+)
      (reverse values-rev)
      (loop (+ index 1)
            (cons
             (make-empty-agentic-ai-lab-module-descriptor
              (string->symbol (string-append "module-" (number->string index)))
              (if (= index (- +module-count+ 1))
                '()
                (list +shared-import+))
              '())
             values-rev)))))

(def available-names (map agentic-ai-lab-module-name modules))

(def (baseline-member-name? value names)
  (cond
   ((null? names) #f)
   ((equal? value (car names)) #t)
   (else (baseline-member-name? value (cdr names)))))

(def (baseline-named-import? import-value)
  (let (profile (agentic-ai-lab-module-import-profile import-value))
    (or (symbol? profile) (string? profile))))

(def (baseline-missing-for module-name imports)
  (cond
   ((null? imports) '())
   ((not (baseline-named-import? (car imports)))
    (baseline-missing-for module-name (cdr imports)))
   ((baseline-member-name?
     (agentic-ai-lab-module-import-profile (car imports))
     available-names)
    (baseline-missing-for module-name (cdr imports)))
   (else
    (cons (list (cons 'module module-name)
                (cons 'import
                      (agentic-ai-lab-module-import-profile (car imports))))
          (baseline-missing-for module-name (cdr imports))))))

(def (baseline-missing modules)
  (foldr append
         '()
         (map (lambda (module)
                (baseline-missing-for
                 (agentic-ai-lab-module-name module)
                 (yuanxu-module-imports module)))
              modules)))

(unless (benchmark-fixture-contract-pass? fixture)
  (error "invalid ASP benchmark fixture" fixture))

(let-values (((baseline-receipt baseline-value)
              (benchmark-run/result
               fixture
               (lambda () (baseline-missing modules)))))
  (let-values (((candidate-receipt candidate-value)
                (benchmark-run/result
                 fixture
                 (lambda () (agentic-ai-lab-module-missing-imports modules)))))
    (unless (equal? baseline-value candidate-value)
      (error "indexed import validation changed diagnostic semantics"))
    (unless (benchmark-receipt-pass? candidate-receipt)
      (error "indexed import validation exceeded ASP benchmark budget"
             candidate-receipt))
    (unless (< (benchmark-fixture-ref candidate-receipt 'elapsedNs)
               (benchmark-fixture-ref baseline-receipt 'elapsedNs))
      (error "shared import name index did not improve dense validation"
             baseline-receipt candidate-receipt))
    (display "[agentic-ai-lab-benchmark] module-import-validation-indexed baseline=")
    (write baseline-receipt)
    (display " candidate=")
    (write candidate-receipt)
    (displayln " semanticEquivalent=#t")
    (force-output)))
