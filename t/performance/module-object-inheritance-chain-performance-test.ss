;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module object validation gates cover inheritance chain projection.
;;; Invariant: validation metadata projection stays descriptor-only.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        (only-in :yuanxu/module-system/schema/interface
                 yuanxu-module-object)
        (only-in :yuanxu/module-system/schema/validation
                 yuanxu-module-object-inheritance-chain))

(export module-object-inheritance-chain-performance-test)

;; : String
(def module-object-inheritance-chain-fixture-path
  "t/scenarios/performance/module-object-inheritance-chain/benchmark.ss")

;; : Alist
(def module-object-inheritance-chain-fixture
  (call-with-input-file module-object-inheritance-chain-fixture-path read))

;; : (-> Alist Symbol Value)
(def (module-object-inheritance-chain-ref alist key)
  (cdr (assoc key alist)))

;; : (-> Alist Void)
(def (module-object-inheritance-chain-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] module-object-inheritance-chain ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Integer Symbol)
(def (module-object-inheritance-chain-name index)
  (string->symbol
   (string-append "inheritance-node-" (number->string index))))

;; : (-> Integer PooModuleObject)
(def (module-object-inheritance-chain-build count)
  (fold (lambda (index parent)
          (yuanxu-module-object
           (module-object-inheritance-chain-name index)
           (if parent (list parent) '())
           '()
           '()))
        #f
        (agentic-ai-lab-performance-build-list count (lambda (index) index))))

;; : (-> [Object] Object)
(def (module-object-inheritance-chain-last values)
  (if (null? (cdr values))
    (car values)
    (module-object-inheritance-chain-last (cdr values))))

;; : (-> PooModuleObject Alist)
(def (module-object-inheritance-chain-summary object)
  (let (chain (yuanxu-module-object-inheritance-chain object))
    (list (cons 'chain-count (length chain))
          (cons 'first-node (car chain))
          (cons 'last-node
                (module-object-inheritance-chain-last chain)))))

;; : TestSuite
(def module-object-inheritance-chain-performance-test
  (test-suite "module object inheritance chain performance"
    (yuanxu-test-case "keeps large inheritance chain projection inside benchmark contract"
      (let* ((object-count 1600)
             (object (module-object-inheritance-chain-build object-count))
             (receipt
              (benchmark-run
               module-object-inheritance-chain-fixture
               (lambda ()
                 (module-object-inheritance-chain-summary object))))
             (summary (module-object-inheritance-chain-summary object)))
        (check-equal?
         (benchmark-fixture-contract-pass? module-object-inheritance-chain-fixture)
         #t)
        (check-equal?
         (module-object-inheritance-chain-ref summary 'chain-count)
         object-count)
        (check-equal?
         (module-object-inheritance-chain-ref summary 'first-node)
         (module-object-inheritance-chain-name (- object-count 1)))
        (check-equal?
         (module-object-inheritance-chain-ref summary 'last-node)
         (module-object-inheritance-chain-name 0))
        (module-object-inheritance-chain-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
