;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module object performance gates cover sparse List slot merging.
;;; Invariant: object merges stay descriptor data and never execute runtime work.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        (only-in :core/graph/interface
                 poo-flow-graph-root-payload)
        (only-in :core/module-system/schema/interface
                 PooFlowModuleListType
                 poo-flow-module-field-resolution-result-root
                 poo-flow-module-field-contract
                 poo-flow-module-field-contribution
                 poo-flow-module-object
                 poo-flow-module-objects-resolve-contributions/node
                 poo-flow-module-objects-node
                 poo-flow-module-objects-ref))

(export module-object-list-merge-performance-test)

;; : String
(def module-object-list-merge-fixture-path
  "t/scenarios/performance/module-object-list-merge/benchmark.ss")

;; : Alist
(def module-object-list-merge-fixture
  (call-with-input-file module-object-list-merge-fixture-path read))

;; : PooModuleFieldContract
(def module-object-list-merge-field
  (poo-flow-module-field-contract 'capabilities PooFlowModuleListType 'append '() '()))

;; : PooModuleObject
(def module-object-list-merge-object
  (poo-flow-module-object
   'large.module.object
   '()
   (list module-object-list-merge-field)
   '()))

;; : PooFlowGraph
(def module-object-list-merge-objects-node
  (poo-flow-module-objects-node (list module-object-list-merge-object)))

;; : (-> Alist Symbol Value)
(def (module-object-list-merge-ref alist key)
  (cdr (assoc key alist)))

;; : (-> Alist Void)
(def (module-object-list-merge-display-receipt receipt)
  (display "[poo-flow-benchmark] module-object-list-merge ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Integer Integer)
(def (module-object-list-merge-capability index)
  index)

;; : (-> Integer Integer Integer [Integer])
(def (module-object-list-merge-batch start size step)
  (poo-flow-performance-build-list
   size
   (lambda (index)
     (module-object-list-merge-capability
      (+ start (* index step))))))

;; : (-> Integer Integer Integer [PooModuleFieldContribution])
(def (module-object-list-merge-contributions batch-count batch-size overlap-step)
  (poo-flow-performance-build-list
   batch-count
   (lambda (batch-index)
     (poo-flow-module-field-contribution
      'large.module.object
      module-object-list-merge-field
      (module-object-list-merge-batch
       (* batch-index overlap-step)
       batch-size
       1)))))

;; : (-> [Object] Object)
(def (module-object-list-merge-last values)
  (if (null? (cdr values))
    (car values)
    (module-object-list-merge-last (cdr values))))

;; : (-> [PooModuleFieldContribution] Alist)
(def (module-object-list-merge-summary/from-contributions contributions)
  (let* ((result
          (poo-flow-module-objects-resolve-contributions/node
           module-object-list-merge-objects-node
           contributions))
         (root (poo-flow-module-field-resolution-result-root result))
         (node (poo-flow-module-objects-ref root 'large.module.object))
         (slots (poo-flow-graph-root-payload node))
         (capabilities
          (module-object-list-merge-ref slots 'capabilities)))
    (list (cons 'capability-count (length capabilities))
          (cons 'first-capability (car capabilities))
          (cons 'last-capability
                (module-object-list-merge-last capabilities)))))

;; : (-> Integer Integer Integer Alist)
(def (module-object-list-merge-summary batch-count batch-size overlap-step)
  (module-object-list-merge-summary/from-contributions
   (module-object-list-merge-contributions
    batch-count
    batch-size
    overlap-step)))

;; : TestSuite
(def module-object-list-merge-performance-test
  (test-suite "module object list merge performance"
    (poo-flow-test-case "keeps repeated sparse list appends inside benchmark contract"
      (let* ((batch-count 240)
             (batch-size 48)
             (overlap-step 24)
             (expected-count
              (+ (* (- batch-count 1) overlap-step) batch-size))
             (contributions
              (module-object-list-merge-contributions
               batch-count
               batch-size
               overlap-step))
             (receipt
              (benchmark-run
               module-object-list-merge-fixture
               (lambda ()
                 (module-object-list-merge-summary/from-contributions
                  contributions))))
             (summary
              (module-object-list-merge-summary/from-contributions
               contributions)))
        (check-equal?
         (benchmark-fixture-contract-pass? module-object-list-merge-fixture)
         #t)
        (check-equal?
         (module-object-list-merge-ref summary 'capability-count)
         expected-count)
        (check-equal?
         (module-object-list-merge-ref summary 'first-capability)
         (module-object-list-merge-capability 0))
        (check-equal?
         (module-object-list-merge-ref summary 'last-capability)
         (module-object-list-merge-capability (- expected-count 1)))
        (module-object-list-merge-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
