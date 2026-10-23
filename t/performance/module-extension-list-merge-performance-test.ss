;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module extension performance gates cover List slot operation merge.
;;; Invariant: extension operations stay graph data and never execute runtime work.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        (only-in :yuanxu/graph/interface
                 yuanxu-graph-contribution
                 yuanxu-graph-resolve
                 yuanxu-graph-rooted
                 yuanxu-graph-root-payload
                 yuanxu-graph-result-root
                 yuanxu-graph-slot-append))

(export module-extension-list-merge-performance-test)

;; : String
(def module-extension-list-merge-fixture-path
  "t/scenarios/performance/module-extension-list-merge/benchmark.ss")

;; : Alist
(def module-extension-list-merge-fixture
  (call-with-input-file module-extension-list-merge-fixture-path read))

;; : YuanxuGraph
(def module-extension-list-merge-root
  (yuanxu-graph-rooted
   'extension.root
   '((capabilities . ()))
   '()))

;; : (-> Alist Symbol Value)
(def (module-extension-list-merge-ref alist key)
  (cdr (assoc key alist)))

;; : (-> Alist Void)
(def (module-extension-list-merge-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] module-extension-list-merge ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Integer Integer Integer [Integer])
(def (module-extension-list-merge-batch start size step)
  (agentic-ai-lab-performance-build-list
   size
   (lambda (index)
     (+ start (* index step)))))

;; : (-> Integer Integer Integer [PooGraphOperation])
(def (module-extension-list-merge-operations batch-count batch-size overlap-step)
  (agentic-ai-lab-performance-build-list
   batch-count
   (lambda (batch-index)
     (yuanxu-graph-slot-append
      'capabilities
      (module-extension-list-merge-batch
       (* batch-index overlap-step)
       batch-size
       1)))))

;; : (-> [Object] Object)
(def (module-extension-list-merge-last values)
  (if (null? (cdr values))
    (car values)
    (module-extension-list-merge-last (cdr values))))

;; : (-> [PooGraphOperation] Alist)
(def (module-extension-list-merge-summary/from-operations operations)
  (let* ((result
          (yuanxu-graph-resolve
           module-extension-list-merge-root
           (list
            (yuanxu-graph-contribution
             'extension.root
             operations))))
         (node (yuanxu-graph-result-root result))
         (slots (yuanxu-graph-root-payload node))
         (capabilities
          (module-extension-list-merge-ref slots 'capabilities)))
    (list (cons 'capability-count (length capabilities))
          (cons 'first-capability (car capabilities))
          (cons 'last-capability
                (module-extension-list-merge-last capabilities)))))

;; : TestSuite
(def module-extension-list-merge-performance-test
  (test-suite "module extension list merge performance"
    (yuanxu-test-case "keeps repeated extension list appends inside benchmark contract"
      (let* ((batch-count 180)
             (batch-size 48)
             (overlap-step 24)
             (expected-count
              (+ (* (- batch-count 1) overlap-step) batch-size))
             (operations
              (module-extension-list-merge-operations
               batch-count
               batch-size
               overlap-step))
             (receipt
              (benchmark-run
               module-extension-list-merge-fixture
               (lambda ()
                 (module-extension-list-merge-summary/from-operations
                  operations))))
             (summary
              (module-extension-list-merge-summary/from-operations
               operations)))
        (check-equal?
         (benchmark-fixture-contract-pass? module-extension-list-merge-fixture)
         #t)
        (check-equal?
         (module-extension-list-merge-ref summary 'capability-count)
         expected-count)
        (check-equal?
         (module-extension-list-merge-ref summary 'first-capability)
         0)
        (check-equal?
         (module-extension-list-merge-ref summary 'last-capability)
         (- expected-count 1))
        (module-extension-list-merge-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
