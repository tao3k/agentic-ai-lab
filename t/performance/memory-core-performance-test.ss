;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: memory-core catalog policy validation performance gate.
;;; Invariant: validation resolves POO memory specs and intent refs without
;;; runtime recall, commit, or backend startup.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        :agentic-ai-lab/modules/session/config
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/config)

(export memory-core-performance-test)

(def memory-core-performance-fixture-path
  "t/scenarios/performance/memory-core-catalog-policy-validation/benchmark.ss")

(def memory-core-performance-fixture
  (call-with-input-file memory-core-performance-fixture-path read))

(def memory-core-performance-count 160)

;; : (-> Alist Symbol MaybeValue)
(def (memory-core-performance-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (memory-core-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] memory-core-catalog-policy-validation ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> String Integer Symbol)
(def (memory-core-performance-symbol prefix index)
  (string->symbol
   (string-append prefix "/" (number->string index))))

;; : (-> Integer PooMemoryStoreSpec)
(def (memory-core-performance-store index)
  (agentic-ai-lab-memory-store-spec
   (memory-core-performance-symbol "memory/store" index)
   'custom
   'session
   '(current-session project)
   '(semantic-search)
   '(append)
   "marlin-agent-core"
   'memory/custom
   #t
   'marlin-memory-adapter))

;; : (-> Integer PooSessionMemoryIntent)
(def (memory-core-performance-intent index)
  (agentic-ai-lab-session-memory-intent
   (memory-core-performance-symbol "memory/intent" index)
   (memory-core-performance-symbol "memory/store" index)
   'project
   '(current-task)
   'append))

;; : (-> Integer Alist)
(def (memory-core-performance-summary count)
  (let* ((stores
          (agentic-ai-lab-performance-build-list
           count
           memory-core-performance-store))
         (intents
          (agentic-ai-lab-performance-build-list
           count
           memory-core-performance-intent))
         (catalog (agentic-ai-lab-memory-catalog 'memory-core/performance stores))
         (receipt
          (agentic-ai-lab-memory-policy-catalog-validation-receipt
           'validation/memory-core-performance
           catalog
           intents)))
    (list
     (cons 'store-count (agentic-ai-lab-memory-catalog-store-count catalog))
     (cons 'intent-count (.ref receipt 'intent-count))
     (cons 'resolved-store-count (length (.ref receipt 'resolved-store-refs)))
     (cons 'unresolved-store-count
           (length (.ref receipt 'unresolved-store-refs)))
     (cons 'valid? (.ref receipt 'valid?))
     (cons 'runtime-executed (.ref receipt 'runtime-executed)))))

(def memory-core-performance-test
  (test-suite "memory-core performance"
    (yuanxu-test-case "keeps catalog policy validation inside benchmark contract"
      (let* ((summary
              (memory-core-performance-summary memory-core-performance-count))
             (receipt
              (benchmark-run
               memory-core-performance-fixture
               (lambda ()
                 (memory-core-performance-summary
                  memory-core-performance-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass? memory-core-performance-fixture)
         #t)
        (check-equal? (memory-core-performance-ref summary 'store-count)
                      memory-core-performance-count)
        (check-equal? (memory-core-performance-ref summary 'intent-count)
                      memory-core-performance-count)
        (check-equal? (memory-core-performance-ref summary
                                                   'resolved-store-count)
                      memory-core-performance-count)
        (check-equal? (memory-core-performance-ref summary
                                                   'unresolved-store-count)
                      0)
        (check-equal? (memory-core-performance-ref summary 'valid?) #t)
        (check-equal? (memory-core-performance-ref summary 'runtime-executed)
                      #f)
        (memory-core-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
