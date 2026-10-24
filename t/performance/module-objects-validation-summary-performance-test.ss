;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module object validation gates cover catalog summary aggregation.
;;; Invariant: summary aggregation stays report-only and never realizes runtime descriptors.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :gerbil/runtime/gambit
        (only-in :clan/poo/object .o .ref object?)
        (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        (only-in :yuanxu/module-system/schema/validation
                 yuanxu-module-objects-validation-summary))

(export module-objects-validation-summary-performance-test)

;; : String
(def module-objects-validation-summary-fixture-path
  "t/scenarios/performance/module-objects-validation-summary/benchmark.ss")

;; : Alist
(def module-objects-validation-summary-fixture
  (call-with-input-file module-objects-validation-summary-fixture-path read))

;; : (-> Integer Symbol)
(def (module-objects-validation-summary-name index)
  (string->symbol
   (string-append "validation-object-" (number->string index))))

;; : (-> Integer POOObject)
(def (module-objects-validation-summary-validation index)
  (let* ((object-name (module-objects-validation-summary-name index))
         (valid? (not (= (modulo index 10) 0))))
    (.o object: object-name
        inheritance-chain: (list object-name 'validation-root)
        direct-field-count: 3
        direct-field-identities: '(alpha beta gamma)
        resolved-field-count: 5
        resolved-field-identities: '(alpha beta gamma delta epsilon)
        field-origins: '((alpha . direct) (delta . inherited))
        inherit-count: 2
        validationPhases: '(source-ref harness-validation diagnostics)
        valid: valid?)))

;; : (-> Integer [POOObject])
(def (module-objects-validation-summary-validations count)
  (agentic-ai-lab-performance-build-list
   count
   module-objects-validation-summary-validation))

;; : (-> POOObject [Symbol])
(def (module-objects-validation-summary-object-identities summary)
  (.ref summary 'object-identities))

;; : (-> POOObject [Symbol])
(def (module-objects-validation-summary-invalid-objects summary)
  (.ref summary 'invalid-objects))

;; : (-> POOObject Symbol Pair)
(def (module-objects-validation-summary-field summary key)
  (cons key (.ref summary key)))

;; : (-> HashTable [Pair])
(def (module-objects-validation-summary-core-fields summary)
  (map (lambda (key)
         (module-objects-validation-summary-field summary key))
       '(object-count invalid-count valid runtime-executed)))

;; : (-> HashTable Pair)
(def (module-objects-validation-summary-first-object-field summary)
  (cons 'first-object
        (first
         (module-objects-validation-summary-object-identities summary))))

;; : (-> HashTable Pair)
(def (module-objects-validation-summary-last-invalid-field summary)
  (cons 'last-invalid
        (last
         (module-objects-validation-summary-invalid-objects summary))))

;; : (-> HashTable Alist)
(def (module-objects-validation-summary-snapshot summary)
  (append (module-objects-validation-summary-core-fields summary)
          (list
           (module-objects-validation-summary-first-object-field summary)
           (module-objects-validation-summary-last-invalid-field summary))))

;; : (-> Alist Symbol Value)
(def (module-objects-validation-summary-ref alist key)
  (cdr (assoc key alist)))

;; : (-> Alist Unit)
(def (module-objects-validation-summary-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] module-objects-validation-summary ")
  (write receipt)
  (newline)
  (force-output))

;; : TestSuite
(def module-objects-validation-summary-performance-test
  (test-suite "module objects validation summary performance"
    (yuanxu-test-case "keeps large catalog validation summary inside benchmark contract"
      (let* ((validation-count 5000)
             (validations
              (module-objects-validation-summary-validations validation-count))
             ;; Materialize the production projection once before the timed
             ;; series so the gate measures stable summary throughput rather
             ;; than first-use POO instantiation and heap growth.
             (summary
              (module-objects-validation-summary-snapshot
               (yuanxu-module-objects-validation-summary validations)))
             (receipt
              (benchmark-run
               module-objects-validation-summary-fixture
               (lambda ()
                  (module-objects-validation-summary-snapshot
                   (yuanxu-module-objects-validation-summary validations))))))
        (check-equal? (andmap object? validations) #t)
        (check-equal?
         (benchmark-fixture-contract-pass? module-objects-validation-summary-fixture)
         #t)
        (check-equal?
         (module-objects-validation-summary-ref summary 'object-count)
         validation-count)
        (check-equal?
         (module-objects-validation-summary-ref summary 'invalid-count)
         500)
        (check-equal?
         (module-objects-validation-summary-ref summary 'valid)
         #f)
        (check-equal?
         (module-objects-validation-summary-ref summary 'runtime-executed)
         #f)
        (check-equal?
         (module-objects-validation-summary-ref summary 'first-object)
         (module-objects-validation-summary-name 0))
        (check-equal?
         (module-objects-validation-summary-ref summary 'last-invalid)
         (module-objects-validation-summary-name 4990))
        (module-objects-validation-summary-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
