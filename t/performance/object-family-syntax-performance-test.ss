;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO object-family syntax performance gate.
;;; Invariant: repeated stable object-family accessors are generated once.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 testing-benchmark-run/result)
        (only-in :clan/poo/object .ref object<-alist)
        (only-in "../support/poo-performance-object-scenarios"
                 poo-performance-build-list)
        :yuanxu/object-family/syntax)

(export object-family-syntax-performance-test)

(def +poo-object-family-performance-kind+
  'poo-object-family-performance)

(defpoo-object-family +poo-object-family-performance-kind+
  poo-object-family-performance?
  (accessors
   (poo-object-family-performance-ref ref)
   (poo-object-family-performance-provider provider)
   (poo-object-family-performance-capabilities capabilities))
  (projections
   (poo-object-family-performance->alist
    (ref ref)
    (provider provider)
    (capabilities capabilities)
    (runtime-executed runtime-executed))))

;; : String
(def object-family-syntax-performance-fixture-path
  "t/scenarios/performance/poo-object-family-syntax/benchmark.ss")

;; : Alist
(def object-family-syntax-performance-fixture
  (call-with-input-file object-family-syntax-performance-fixture-path read))

;; : (-> Alist Symbol MaybeValue)
(def (object-family-syntax-performance-ref row key)
  (let (entry (assq key row))
    (if entry (cdr entry) #f)))

;; : (-> Integer PooObject)
(def (object-family-syntax-performance-model index)
  (object<-alist
   (list
    (cons 'kind +poo-object-family-performance-kind+)
    (cons 'ref index)
    (cons 'provider 'runtime-local)
    (cons 'capabilities '(chat text json tool-calling))
    (cons 'runtime-executed #f))))

;; : (-> Integer [Alist])
(def (object-family-syntax-performance-objects count)
  (poo-performance-build-list
   count
   object-family-syntax-performance-model))

;; : (-> [PooObject] [Alist])
(def (object-family-syntax-performance-rows objects)
  (map poo-object-family-performance->alist
       objects))

;; : (-> [Alist] (Cons Alist Alist))
(def (object-family-syntax-performance-selection rows)
  (cons (car rows)
        (list-ref rows (- (length rows) 1))))

;; : (-> [Alist] (Cons Alist Alist) Alist)
(def (object-family-syntax-performance-summary rows selection)
  (let* ((first-row (car selection))
         (last-row (cdr selection)))
    (list
     (cons 'object-count (length rows))
     (cons 'first-ref
           (object-family-syntax-performance-ref first-row 'ref))
     (cons 'last-ref
           (object-family-syntax-performance-ref last-row 'ref))
     (cons 'capability-count
           (length
            (object-family-syntax-performance-ref first-row 'capabilities)))
     (cons 'runtime-executed
           (object-family-syntax-performance-ref
            first-row
            'runtime-executed)))))

;; : (-> Alist Alist)
(def (object-family-syntax-performance-receipt-summary receipt)
  (list
   (cons 'feature
         (object-family-syntax-performance-ref receipt 'feature))
   (cons 'rule
         (object-family-syntax-performance-ref receipt 'rule))
   (cons 'elapsedMs
         (object-family-syntax-performance-ref receipt 'elapsedMs))
   (cons 'max-total
         (object-family-syntax-performance-ref receipt 'max_total))
   (cons 'status
         (object-family-syntax-performance-ref receipt 'status))))

;; : (-> Alist Void)
(def (object-family-syntax-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] poo-object-family-syntax ")
  (write (object-family-syntax-performance-receipt-summary receipt))
  (newline)
  (force-output))

;; : (-> Symbol TestingReceipt Void)
(def (object-family-syntax-performance-display-phase phase receipt)
  (display "[agentic-ai-lab-benchmark-phase] ")
  (write phase)
  (display " ")
  (write (.ref receipt 'details))
  (newline)
  (force-output))

;; : (-> TestingReceipt Symbol MaybeValue)
(def (object-family-syntax-performance-phase-detail receipt key)
  (object-family-syntax-performance-ref (.ref receipt 'details) key))

;; : TestSuite
(def object-family-syntax-performance-test
  (test-suite "object family syntax performance"
    (yuanxu-test-case "keeps generated POO object-family projections inside benchmark contract"
      (let-values (((construction-receipt objects construction-phase)
                    (testing-benchmark-run/result
                     'poo-object-family-syntax
                     object-family-syntax-performance-fixture
                     (lambda ()
                       (object-family-syntax-performance-objects 1000))
                     '((phase . object-construction)))))
        (let-values (((projection-receipt rows projection-phase)
                      (testing-benchmark-run/result
                       'poo-object-family-syntax
                       object-family-syntax-performance-fixture
                       (lambda ()
                         (object-family-syntax-performance-rows objects))
                       '((phase . boundary-projection)))))
          (let-values (((selection-receipt selection selection-phase)
                        (testing-benchmark-run/result
                         'poo-object-family-syntax
                         object-family-syntax-performance-fixture
                         (lambda ()
                           (object-family-syntax-performance-selection rows))
                         '((phase . object-selection)))))
            (let ((summary (object-family-syntax-performance-summary rows selection))
                  (first-row (car selection))
                  (last-row (cdr selection)))
              (check-equal?
               (benchmark-fixture-contract-pass?
                object-family-syntax-performance-fixture)
               #t)
              (check-equal?
               (object-family-syntax-performance-ref summary 'object-count)
               1000)
              (check-equal?
               (object-family-syntax-performance-ref summary 'first-ref)
               0)
              (check-equal?
               (object-family-syntax-performance-ref summary 'last-ref)
               999)
              (check-equal?
               (object-family-syntax-performance-ref summary 'capability-count)
               4)
              (check-equal?
               (object-family-syntax-performance-ref summary 'runtime-executed)
               #f)
              (check-equal?
               (object-family-syntax-performance-ref first-row 'ref)
               0)
              (check-equal?
               (object-family-syntax-performance-ref last-row 'ref)
               999)
              (object-family-syntax-performance-display-receipt construction-receipt)
              (object-family-syntax-performance-display-phase
               'object-construction construction-phase)
              (object-family-syntax-performance-display-phase
               'boundary-projection projection-phase)
              (object-family-syntax-performance-display-phase
               'object-selection selection-phase)
              (check-equal?
               (object-family-syntax-performance-phase-detail
                construction-phase
                'phase)
               'object-construction)
              (check-equal?
               (object-family-syntax-performance-phase-detail
                projection-phase
                'phase)
               'boundary-projection)
              (check-equal?
               (object-family-syntax-performance-phase-detail
                selection-phase
                'phase)
               'object-selection)
              (check-equal?
               (number?
                (object-family-syntax-performance-phase-detail
                 construction-phase
                 'elapsedMs))
               #t)
              (check-equal?
               (number?
                (object-family-syntax-performance-phase-detail
                 projection-phase
                 'elapsedMs))
               #t)
              (check-equal?
               (number?
                (object-family-syntax-performance-phase-detail
                 selection-phase
                 'elapsedMs))
               #t)
              (check-equal?
               (object-family-syntax-performance-ref
                (object-family-syntax-performance-receipt-summary
                 construction-receipt)
                'status)
               'pass)
              (check-equal? (benchmark-receipt-pass? construction-receipt) #t)
              (check-equal? (benchmark-receipt-pass? projection-receipt) #t)
              (check-equal? (benchmark-receipt-pass? selection-receipt) #t))))))))
