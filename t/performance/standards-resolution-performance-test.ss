;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: scale gate for the domain-neutral Standards resolver.
;;; Invariant: fixture and index construction happen outside timing; samples
;;; measure exact-root resolution and receipt construction only.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .ref)
        (only-in :std/test check-equal? test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        :agentic-ai-lab/modules/standards/interface)

(export standards-resolution-performance-test)

(def +standards-performance-family+
  (agentic-ai-lab-standard-family
   "performance/standards" "agentic-ai-lab" 'performance '(scheme)
   "Apache-2.0 AND LGPL-2.1-or-later" '()))

(def +standards-performance-terminology-digest+
  (agentic-ai-lab-standard-digest 'performance-terminology-snapshot))

;;; Fixture construction is outside the resolver measurement.  A shared valid
;;; digest keeps setup linear without spending 10,000 unrelated SHA256 calls.
(def +standards-performance-edition-digest+
  (agentic-ai-lab-standard-digest 'performance-standard-edition))

(def (standards-performance-identity index)
  (string-append "performance/standard/" (number->string index)))

(def (standards-performance-edition index)
  (let (identity (standards-performance-identity index))
    (agentic-ai-lab-standard-edition-ref
     identity +standards-performance-family+ identity "1"
     "performance" 'global +standards-performance-edition-digest+
     identity '() '() '() 'active '() '())))

(def (standards-performance-fixture count)
  (let* ((editions
          (map standards-performance-edition (iota count)))
         (identities (map (lambda (edition) (.ref edition 'identity)) editions)))
    (list
     (agentic-ai-lab-standard-catalog
      (string-append "performance/catalog/" (number->string count))
      editions '())
     identities
     (agentic-ai-lab-standard-budget count 1 2 1 (* count 2)))))

(def (standards-performance-resolve fixture)
  (agentic-ai-lab-standard-resolve
   (car fixture) (cadr fixture) (caddr fixture)
   +standards-performance-terminology-digest+))

(def standards-performance-benchmark-path
  "t/scenarios/performance/standards-resolution/benchmark.ss")

(def standards-performance-benchmark
  (call-with-input-file standards-performance-benchmark-path read))

(def (standards-performance-summary fixture)
  (let* ((receipt (standards-performance-resolve fixture))
         (bundle (agentic-ai-lab-standard-resolution-receipt-bundle receipt)))
    (list
     (cons 'valid? (agentic-ai-lab-standard-resolution-receipt-valid? receipt))
     (cons 'catalog-count (.ref (car fixture) 'edition-count))
     (cons 'selected-edition-count (.ref bundle 'edition-count))
     (cons 'selected-artifact-count (.ref bundle 'artifact-count))
     (cons 'loaded-byte-count (.ref bundle 'byte-count))
     (cons 'materialization-count 0)
     (cons 'validation-closure-count 0)
     (cons 'operation-count (.ref bundle 'operation-count))
     (cons 'generation (.ref bundle 'generation))
     (cons 'runtime-executed? (.ref bundle 'runtime-executed?)))))

(def (standards-performance-ref receipt key)
  (cdr (assoc key receipt)))

(def standards-resolution-performance-test
  (test-suite
   "Standards indexed resolution performance"
   (yuanxu-test-case
    "resolves 10,000 exact roots through the ASP benchmark contract"
    (let* ((count 10000)
           (_fixture-start
            (begin
              (displayln
               "[agentic-ai-lab-benchmark] standards-resolution phase=fixture-start count="
               count)
              (force-output)))
           (fixture (standards-performance-fixture count))
           (_fixture-ready
            (begin
              (displayln
               "[agentic-ai-lab-benchmark] standards-resolution phase=fixture-ready count="
               count)
              (force-output)))
           (summary (standards-performance-summary fixture))
           (_measurement-start
            (begin
              (displayln
               "[agentic-ai-lab-benchmark] standards-resolution phase=measurement-start")
              (force-output)))
           (receipt
            (benchmark-run
             standards-performance-benchmark
             (lambda () (standards-performance-summary fixture)))))
      (display "[agentic-ai-lab-benchmark] standards-resolution ")
      (write receipt)
      (newline)
      (force-output)
      (check-equal?
       (benchmark-fixture-contract-pass? standards-performance-benchmark)
       #t)
      (check-equal? (standards-performance-ref summary 'valid?) #t)
      (check-equal? (standards-performance-ref summary 'catalog-count) count)
      (check-equal?
       (standards-performance-ref summary 'selected-edition-count)
       count)
      (check-equal?
       (standards-performance-ref summary 'selected-artifact-count)
       0)
      (check-equal? (standards-performance-ref summary 'loaded-byte-count) 0)
      (check-equal? (standards-performance-ref summary 'operation-count) count)
      (check-equal? (standards-performance-ref summary 'runtime-executed?) #f)
      (check-equal? (benchmark-receipt-pass? receipt) #t)))))
