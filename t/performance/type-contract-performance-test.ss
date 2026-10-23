;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: utilities/type-contract benchmark gates cover hot Scheme paths.
;;; Invariant: benchmark thunks exclude gxi startup, package install, Lean
;;; execution, Marlin runtime work, and external IO.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-p95-elapsed-ms)
        "../support/type-contract-performance.ss")

(export type-contract-performance-test)

;; : (-> Alist Symbol Value)
(def (type-contract-performance-ref receipt key)
  (cdr (assoc key receipt)))

;; : (-> Alist Void)
(def (type-contract-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] type-contract-performance ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Rational Rational Boolean)
(def (type-contract-performance-within-budget? observed-ms max-ms)
  (and observed-ms
       (<= observed-ms max-ms)))

;; : (-> Symbol Rational Rational Void)
(def (type-contract-performance-check-budget! name observed-ms max-ms)
  (check-equal?
   (type-contract-performance-within-budget? observed-ms max-ms)
   #t))

;; : (-> Alist Boolean)
(def (type-contract-performance-receipt-pass? receipt)
  (and (type-contract-performance-within-budget?
        (type-contract-performance-ref receipt 'slot-check-ms)
        (type-contract-performance-ref receipt 'slot-check-ms-max-ms))
       (type-contract-performance-within-budget?
        (type-contract-performance-ref receipt 'alist-projection-ms)
        (type-contract-performance-ref receipt 'alist-projection-ms-max-ms))
       (type-contract-performance-within-budget?
        (type-contract-performance-ref receipt 'type-facts-ms)
        (type-contract-performance-ref receipt 'type-facts-ms-max-ms))
       (type-contract-performance-within-budget?
        (type-contract-performance-ref receipt 'lean-facts-ms)
        (type-contract-performance-ref receipt 'lean-facts-ms-max-ms))
       (type-contract-performance-within-budget?
        (type-contract-performance-ref receipt 'session-policy-ms)
        (type-contract-performance-ref receipt 'session-policy-ms-max-ms))
       (type-contract-performance-within-budget?
        (type-contract-performance-ref receipt 'scale-10000-ms)
        (type-contract-performance-ref receipt 'scale-10000-ms-max-ms))
       (type-contract-performance-within-budget?
        (type-contract-performance-ref receipt 'cached-type-facts-ms)
        (type-contract-performance-ref receipt 'cached-type-facts-ms-max-ms))))

;; : (-> Integer (-> Integer) Rational)
(def (type-contract-performance-p95-ms attempts workload)
  (benchmark-p95-elapsed-ms
   attempts
   (lambda ()
     (workload))))

;; : (-> Alist)
(def (type-contract-performance-receipt)
  (let* ((attempts 3)
         (micro-slots 10)
         (micro-rounds 2000)
         (projection-slots 10)
         (projection-rounds 1500)
         (session-rounds 1000)
         (cached-slots 50)
         (cached-rounds 10000)
         (slot-check-ms
          (type-contract-performance-p95-ms
           attempts
           (lambda ()
             (type-contract-performance-check-slots-rounds
              micro-slots
              micro-rounds))))
         (alist-projection-ms
          (type-contract-performance-p95-ms
           attempts
           (lambda ()
             (type-contract-performance-object-contract-alist-rounds
              projection-slots
              projection-rounds))))
         (type-facts-ms
          (type-contract-performance-p95-ms
           attempts
           (lambda ()
             (type-contract-performance-type-facts-rounds
              projection-slots
              projection-rounds))))
         (lean-facts-ms
          (type-contract-performance-p95-ms
           attempts
           (lambda ()
             (type-contract-performance-lean-facts-rounds
              projection-slots
              projection-rounds))))
         (session-policy-ms
          (type-contract-performance-p95-ms
           attempts
           (lambda ()
             (+ (type-contract-performance-session-policy-projection-rounds
                 session-rounds)
                (type-contract-performance-session-tool-grant-projection-rounds
                 session-rounds)
                (type-contract-performance-session-policy-require-rounds
                 session-rounds)
                (type-contract-performance-session-tool-grant-require-rounds
                 session-rounds)))))
         (scale-100-ms
          (type-contract-performance-p95-ms
           attempts
           (lambda ()
             (type-contract-performance-object-family-check-count 100 10))))
         (scale-1000-ms
          (type-contract-performance-p95-ms
           attempts
           (lambda ()
             (type-contract-performance-object-family-check-count 1000 10))))
         (scale-10000-ms
          (type-contract-performance-p95-ms
           attempts
           (lambda ()
             (type-contract-performance-object-family-check-count 10000 2))))
         (cached-type-facts-ms
          (type-contract-performance-p95-ms
           attempts
           (lambda ()
             (type-contract-performance-cached-type-facts-rounds
              cached-slots
              cached-rounds)))))
    (list
     (cons 'attempts attempts)
     (cons 'admissionStatistic 'p95)
     (cons 'micro-slots micro-slots)
     (cons 'micro-rounds micro-rounds)
     (cons 'projection-slots projection-slots)
     (cons 'projection-rounds projection-rounds)
     (cons 'session-rounds session-rounds)
     (cons 'cached-slots cached-slots)
     (cons 'cached-rounds cached-rounds)
     (cons 'slot-check-ms slot-check-ms)
     (cons 'slot-check-ms-max-ms 250)
     (cons 'alist-projection-ms alist-projection-ms)
     (cons 'alist-projection-ms-max-ms 350)
     (cons 'type-facts-ms type-facts-ms)
     (cons 'type-facts-ms-max-ms 500)
     (cons 'lean-facts-ms lean-facts-ms)
     (cons 'lean-facts-ms-max-ms 500)
     (cons 'session-policy-ms session-policy-ms)
     (cons 'session-policy-ms-max-ms 750)
     (cons 'scale-100-ms scale-100-ms)
     (cons 'scale-1000-ms scale-1000-ms)
     (cons 'scale-10000-ms scale-10000-ms)
     (cons 'scale-10000-ms-max-ms 600)
     (cons 'cached-type-facts-ms cached-type-facts-ms)
     (cons 'cached-type-facts-ms-max-ms 200))))

;;; One test module owns one calibrated measurement. Individual semantic cases
;;; inspect that immutable receipt instead of rerunning every workload four
;;; times and turning the gate itself into the dominant allocation source.
(def +type-contract-performance-receipt-cache+ #f)

;; : (-> Alist)
(def (type-contract-performance-shared-receipt)
  (or +type-contract-performance-receipt-cache+
      (let (receipt (type-contract-performance-receipt))
        (set! +type-contract-performance-receipt-cache+ receipt)
        receipt)))

;; : TestSuite
(def type-contract-performance-test
  (test-suite "type contract performance"
    (yuanxu-test-case "keeps contract micro operations inside regression budgets"
      (let (receipt (type-contract-performance-shared-receipt))
        (type-contract-performance-display-receipt receipt)
        (type-contract-performance-check-budget!
         'slot-check-ms
         (type-contract-performance-ref receipt 'slot-check-ms)
         (type-contract-performance-ref receipt 'slot-check-ms-max-ms))
        (type-contract-performance-check-budget!
         'alist-projection-ms
         (type-contract-performance-ref receipt 'alist-projection-ms)
         (type-contract-performance-ref receipt 'alist-projection-ms-max-ms))
        (type-contract-performance-check-budget!
         'type-facts-ms
         (type-contract-performance-ref receipt 'type-facts-ms)
         (type-contract-performance-ref receipt 'type-facts-ms-max-ms))
        (type-contract-performance-check-budget!
         'lean-facts-ms
         (type-contract-performance-ref receipt 'lean-facts-ms)
         (type-contract-performance-ref receipt 'lean-facts-ms-max-ms))))
    (yuanxu-test-case "keeps real session contract scenario inside regression budgets"
      (let (receipt (type-contract-performance-shared-receipt))
        (type-contract-performance-check-budget!
         'session-policy-ms
         (type-contract-performance-ref receipt 'session-policy-ms)
         (type-contract-performance-ref receipt 'session-policy-ms-max-ms))))
    (yuanxu-test-case "keeps scaled contract-backed objects bounded"
      (let (receipt (type-contract-performance-shared-receipt))
        (check-equal?
         (<= (type-contract-performance-ref receipt 'scale-100-ms)
             (type-contract-performance-ref receipt 'scale-1000-ms))
         #t)
        (type-contract-performance-check-budget!
         'scale-10000-ms
         (type-contract-performance-ref receipt 'scale-10000-ms)
         (type-contract-performance-ref receipt 'scale-10000-ms-max-ms))))
    (yuanxu-test-case "keeps cached projection reads out of the hot validation path"
      (let (receipt (type-contract-performance-shared-receipt))
        (type-contract-performance-check-budget!
         'cached-type-facts-ms
         (type-contract-performance-ref receipt 'cached-type-facts-ms)
         (type-contract-performance-ref receipt 'cached-type-facts-ms-max-ms))
        (check-equal?
         (type-contract-performance-receipt-pass? receipt)
         #t)))))
