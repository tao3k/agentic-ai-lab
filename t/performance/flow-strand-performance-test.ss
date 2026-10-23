;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: flow strand performance gates cover batch registry extension.
;;; Invariant: strand registries stay descriptor data, not runtime execution.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        (only-in :yuanxu/modules/funflow/control-plane/flow-strand
                 default-flow-strand-registry
                 flow-strand-for-kind-in
                 flow-strand-registry-descriptors
                 flow-strand-registry-merge
                 flow-strand-task-families
                 make-flow-strand-descriptor))

(export flow-strand-performance-test)

;; : String
(def flow-strand-registry-merge-fixture-path
  "t/scenarios/performance/flow-strand-registry-merge/benchmark.ss")

;; : Alist
(def flow-strand-registry-merge-fixture
  (call-with-input-file flow-strand-registry-merge-fixture-path read))

;; : (-> Alist Symbol Value)
(def (flow-strand-performance-ref alist key)
  (cdr (assoc key alist)))

;; : (-> Alist Void)
(def (flow-strand-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] flow-strand-registry-merge ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Integer Symbol)
(def (flow-strand-performance-name index)
  (string->symbol
   (string-append "generated-strand-" (number->string index))))

;; : (-> Integer FlowStrandDescriptor)
(def (flow-strand-performance-descriptor index)
  (make-flow-strand-descriptor
   (flow-strand-performance-name index)
   '(generated external)
   '(runtime-command extension-hook)
   'adapter
   'rust-or-external-runtime
   #f))

;; : (-> Integer [FlowStrandDescriptor])
(def (flow-strand-performance-descriptors count)
  (agentic-ai-lab-performance-build-list
   count
   flow-strand-performance-descriptor))

;; : (-> FlowStrandRegistry Alist)
(def (flow-strand-performance-summary registry)
  (let (descriptors (flow-strand-registry-descriptors registry))
    (list (cons 'strand-count
                (length descriptors))
          (cons 'descriptor-count
                (length descriptors))
          (cons 'runtime-executed #f))))

;; : (-> [FlowStrandDescriptor] Alist)
(def (flow-strand-performance-merge-summary/descriptors descriptors)
  (let* ((registry
          (flow-strand-registry-merge
           default-flow-strand-registry
           descriptors))
         (simple (flow-strand-for-kind-in registry 'simple))
         (summary (flow-strand-performance-summary registry)))
    (cons (cons 'simple-task-families (flow-strand-task-families simple))
          summary)))

;; : (-> Integer Alist)
(def (flow-strand-performance-merge-summary count)
  (flow-strand-performance-merge-summary/descriptors
   (append
    (flow-strand-performance-descriptors count)
    (list (make-flow-strand-descriptor
           'simple
           '(pure scheme generated-override)
           '(pure-function io-continuation local-kleisli extension-hook)
           'local
           'gerbil
           #t)))))

;; : TestSuite
(def flow-strand-performance-test
  (test-suite "flow strand performance"
    (yuanxu-test-case "keeps large strand registry merge inside benchmark contract"
      (let* ((extension-count 900)
             (descriptors
              (append
               (flow-strand-performance-descriptors extension-count)
               (list (make-flow-strand-descriptor
                      'simple
                      '(pure scheme generated-override)
                      '(pure-function
                        io-continuation
                        local-kleisli
                        extension-hook)
                      'local
                      'gerbil
                      #t))))
             (summary
              (flow-strand-performance-merge-summary/descriptors descriptors))
             (receipt
              (benchmark-run
               flow-strand-registry-merge-fixture
               (lambda ()
                 (flow-strand-performance-merge-summary/descriptors
                  descriptors)))))
        (check-equal?
         (benchmark-fixture-contract-pass? flow-strand-registry-merge-fixture)
         #t)
        (check-equal?
         (flow-strand-performance-ref summary 'strand-count)
         (+ extension-count 3))
        (check-equal?
         (flow-strand-performance-ref summary 'descriptor-count)
         (+ extension-count 3))
        (check-equal?
         (flow-strand-performance-ref summary 'simple-task-families)
         '(pure scheme generated-override))
        (check-equal?
         (flow-strand-performance-ref summary 'runtime-executed)
         #f)
        (flow-strand-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
