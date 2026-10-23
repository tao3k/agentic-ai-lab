;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: scale gate for the domain-neutral Sources Lock Feature.
;;; Invariant: admitted entries are fixture data; the measurement owns
;;; canonical lock construction, digest construction, indexing and lookup.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .o .ref)
        (only-in :std/test check-equal? test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        :yuanxu/feature-system/source-lock-feature)

(export sources-lock-performance-test)

(def +sources-lock-performance-count+ 10000)
(def +sources-lock-performance-construction-target-ms+ 2000)
(def +sources-lock-performance-construction-maximum-ms+ 2999)

(def (sources-lock-performance-identity index)
  (string-append "performance/source/" (number->string index)))

(def +sources-lock-performance-entry-digest+
  (source-lock-payload-digest "locked source payload"))

(def (sources-lock-performance-entry index)
  ;; POO object initializers resolve a bare identifier matching the slot as a
  ;; self lookup.  Keep constructor captures distinctly named so this fixture
  ;; cannot become a lazy identity -> identity cycle.
  (let (identity-value (sources-lock-performance-identity index))
    (.o (:: @ SourceLockEntry.)
        identity: identity-value
        path: (string-append "sources/" identity-value ".txt")
        canonical-uri: (string-append "https://example.test/" identity-value)
        exact-version: "1"
        representation: 'text
        digest: +sources-lock-performance-entry-digest+
        size-bytes: 21)))

(def +sources-lock-performance-entries+
  (reverse
   (map sources-lock-performance-entry
        (iota +sources-lock-performance-count+))))

(def +sources-lock-performance-identities+
  (map sources-lock-performance-identity
       (iota +sources-lock-performance-count+)))

(def (sources-lock-performance-summary lock)
  (let* ((found-count
          (foldl
           (lambda (identity count)
             (if (sources-lock-ref lock identity)
               (+ count 1)
               count))
           0
           +sources-lock-performance-identities+)))
    (list
     (cons 'valid? (sources-lock? lock))
     (cons 'entry-count (.ref lock 'entry-count))
     (cons 'found-count found-count)
     (cons 'first-identity (.ref (car (.ref lock 'entries)) 'identity))
     (cons 'last-identity
           (.ref (last (.ref lock 'entries)) 'identity)))))

(def (sources-lock-performance-ref summary key)
  (cdr (assoc key summary)))

(def sources-lock-performance-benchmark-path
  "t/scenarios/performance/sources-lock/benchmark.ss")

(def sources-lock-performance-benchmark
  (call-with-input-file sources-lock-performance-benchmark-path read))

(def sources-lock-performance-test
  (test-suite
   "Sources Lock canonical freeze and lookup performance"
   (yuanxu-test-case
    "constructs and indexes 10,000 admitted source lock entries"
    (displayln
     "[agentic-ai-lab-benchmark] sources-lock phase=fixture-ready count="
     +sources-lock-performance-count+
     " constructorOwnedIndex="
     (eq? (.ref SourcesLock. 'index) #f))
    (force-output)
    (let* ((construction-started (current-jiffy))
           (lock
            (sources-lock-value
             "performance/sources" "1" #f
             +sources-lock-performance-entries+))
           (construction-elapsed-ms
            (quotient
             (* (- (current-jiffy) construction-started) 1000)
             (jiffies-per-second)))
           (_construction-receipt
            (begin
              (displayln
               "[agentic-ai-lab-benchmark] sources-lock phase=construction-complete elapsedMs="
               construction-elapsed-ms
               " targetMs=" +sources-lock-performance-construction-target-ms+
               " maxMs=" +sources-lock-performance-construction-maximum-ms+)
              (force-output)))
           (summary (sources-lock-performance-summary lock))
           (receipt
            (benchmark-run
             sources-lock-performance-benchmark
             (lambda () (sources-lock-performance-summary lock)))))
      (display "[agentic-ai-lab-benchmark] sources-lock ")
      (write receipt)
      (newline)
      (force-output)
      (check-equal?
       (benchmark-fixture-contract-pass? sources-lock-performance-benchmark)
       #t)
      (check-equal?
       (<= construction-elapsed-ms
           +sources-lock-performance-construction-maximum-ms+)
       #t)
      (check-equal? (sources-lock-performance-ref summary 'valid?) #t)
      (check-equal?
       (sources-lock-performance-ref summary 'entry-count)
       +sources-lock-performance-count+)
      (check-equal?
       (sources-lock-performance-ref summary 'found-count)
       +sources-lock-performance-count+)
      (check-equal?
       (sources-lock-performance-ref summary 'first-identity)
       "performance/source/0")
      (check-equal?
       (sources-lock-performance-ref summary 'last-identity)
       (sources-lock-performance-identity
        (- +sources-lock-performance-count+ 1)))
      (check-equal? (benchmark-receipt-pass? receipt) #t)))))
