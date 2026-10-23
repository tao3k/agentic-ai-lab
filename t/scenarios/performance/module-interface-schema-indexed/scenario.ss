;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A/B witness for repeated projected-schema scans versus the derived index
;;; owned by the public POO Module Interface. The baseline is evidence only;
;;; it is not an alternate runtime or public compatibility path.

(import (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :clan/poo/object .o .ref object<-alist)
        (only-in :agentic-ai-lab/modules/module-authoring/module-interface
                 yuanxu-module-interface
                 yuanxu-module-interface-schema-spec)
        (only-in :agentic-ai-lab/modules/module-authoring/module-descriptor
                 agentic-ai-lab-modules)
        (only-in :yuanxu/module-system/projection/option-objects
                 yuanxu-module-option-schema-id
                 yuanxu-module-option-schema-value)
        (only-in :agentic-ai-lab/modules/module-authoring/module-option-projection
                 agentic-ai-lab-module-option-schemas)
        (only-in :yuanxu/module-system/projection/option-validation
                 yuanxu-module-find-schema))

(def +schema-count+ 1000)
(def fixture
  (call-with-input-file
   "t/scenarios/performance/module-interface-schema-indexed/benchmark.ss"
   read))

(def schema-rows
  (let loop ((index 0) (rows-rev '()))
    (if (= index +schema-count+)
      (reverse rows-rev)
      (loop (+ index 1)
            (cons
             (cons
              (string->symbol
               (string-append "option-" (number->string index)))
              (.o type: 'Integer constant: index))
             rows-rev)))))

(def interface
  (yuanxu-module-interface
   "IndexedSchemaProfile"
   (object<-alist schema-rows)
   '((owner . "agentic-ai-lab"))))

(def module
  (agentic-ai-lab-modules interface (.o id: 'indexed-schema config: (.o))))

(def schemas (agentic-ai-lab-module-option-schemas module))
(def option-ids (map yuanxu-module-option-schema-id schemas))

(def (baseline-values)
  (map (lambda (option-id)
         (yuanxu-module-option-schema-value
          (yuanxu-module-find-schema schemas option-id)))
       option-ids))

(def (candidate-values)
  (map (lambda (option-id)
         (.ref (yuanxu-module-interface-schema-spec interface option-id)
               'constant))
       option-ids))

(unless (benchmark-fixture-contract-pass? fixture)
  (error "invalid ASP benchmark fixture" fixture))

(let-values (((baseline-receipt baseline-value)
              (benchmark-run/result fixture baseline-values)))
  (let-values (((candidate-receipt candidate-value)
                (benchmark-run/result fixture candidate-values)))
    (unless (equal? baseline-value candidate-value)
      (error "Interface schema index changed lookup semantics"))
    (unless (benchmark-receipt-pass? candidate-receipt)
      (error "Interface schema index exceeded ASP benchmark budget"
             candidate-receipt))
    (unless (< (benchmark-fixture-ref candidate-receipt 'elapsedNs)
               (benchmark-fixture-ref baseline-receipt 'elapsedNs))
      (error "Interface schema index did not improve repeated lookup"
             baseline-receipt candidate-receipt))
    (display "[agentic-ai-lab-benchmark] module-interface-schema-indexed baseline=")
    (write baseline-receipt)
    (display " candidate=")
    (write candidate-receipt)
    (displayln " semanticEquivalent=#t")
    (force-output)))
