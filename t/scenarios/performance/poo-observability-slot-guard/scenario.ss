;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; One semantic sample for ASP's native P95 benchmark runner.

(import (only-in :clan/poo/object .o .ref)
        (only-in :yuanxu/observability/debug
                 YuanxuDebugSlotPolicyContract
                 yuanxu-debug-poo
                 yuanxu-debug-poos
                 yuanxu-debug-slot-policy))

(export observability-slot-performance-scenario
        observability-slot-performance-receipt-sexp)

(def +cold-count+ 16)
(def +trace-count+ 2)
(def +prototype-iterations+ 20)
(def +warm-iterations+ 1000)
(def ObservabilitySlotPerformanceReceipt.
  (.o kind: 'agentic-ai-lab.observability-slot-performance.v1
      runtime-executed?: #t))

(def (source index) (.o payload: (+ index 1)))
(def (sources count) (map source (iota count)))
(def (guards policy inputs port emit?)
  (yuanxu-debug-poos
   policy 'performance-receiver inputs port: port emit?: emit?))
(def (sum-payload objects)
  (let loop ((rest objects) (sum 0))
    (if (null? rest) sum
        (loop (cdr rest) (+ sum (.ref (car rest) 'payload))))))
(def (repeat-payload object iterations)
  (let loop ((remaining iterations) (sum 0))
    (if (zero? remaining) sum
        (loop (- remaining 1) (+ sum (.ref object 'payload))))))

(def (construct-with-inline-prototype)
  (let loop ((remaining +prototype-iterations+) (count 0))
    (if (zero? remaining)
      count
      (begin
        (.o (:: @ (.ref YuanxuDebugSlotPolicyContract 'proto)))
        (loop (- remaining 1) (+ count 1))))))
(def (construct-with-hoisted-prototype prototype)
  (let loop ((remaining +prototype-iterations+) (count 0))
    (if (zero? remaining)
      count
      (begin
        (.o (:: @ prototype))
        (loop (- remaining 1) (+ count 1))))))

(def (observability-slot-performance-receipt-sexp receipt)
  (map (lambda (slot) (cons slot (.ref receipt slot)))
       '(prototype-iterations inline-prototype-count hoisted-prototype-count
         guard-count cold-checksum expected-cold-checksum warm-iterations
         direct-warm-checksum guarded-warm-checksum evaluation-count
         traced-guard-count trace-checksum expected-trace-checksum
         semantic-valid?)))

(def (observability-slot-performance-scenario)
  (let* ((policy (yuanxu-debug-slot-policy 'performance-slot 8))
         (prototype (.ref YuanxuDebugSlotPolicyContract 'proto))
         (inputs (sources +cold-count+))
         (cold-guards (guards policy inputs (current-error-port) #f))
         (cold-checksum-value (sum-payload cold-guards))
         (trace-port (open-output-string))
         (trace-guards
          (guards policy (sources +trace-count+) trace-port #t))
         (trace-checksum-value (sum-payload trace-guards))
         (evaluations 0)
         (warm-source
          (.o payload: (begin (set! evaluations (+ evaluations 1)) 17)))
         (warm-guard
          (yuanxu-debug-poo policy 'warm-receiver warm-source emit?: #f))
         (_warm-first (.ref warm-guard 'payload))
         (direct-source (source 16))
         (_direct-first (.ref direct-source 'payload))
         (direct-warm-checksum-value
          (repeat-payload direct-source +warm-iterations+))
         (guarded-warm-checksum-value
          (repeat-payload warm-guard +warm-iterations+))
         (inline-prototype-count-value (construct-with-inline-prototype))
         (hoisted-prototype-count-value
          (construct-with-hoisted-prototype prototype))
         (expected-cold-checksum-value
          (/ (* +cold-count+ (+ +cold-count+ 1)) 2))
         (expected-trace-checksum-value
          (/ (* +trace-count+ (+ +trace-count+ 1)) 2))
         (semantic-valid-value
          (and (= cold-checksum-value expected-cold-checksum-value)
               (= trace-checksum-value expected-trace-checksum-value)
               (= inline-prototype-count-value +prototype-iterations+)
               (= hoisted-prototype-count-value +prototype-iterations+)
               (= direct-warm-checksum-value (* 17 +warm-iterations+))
               (= guarded-warm-checksum-value (* 17 +warm-iterations+))
               (= evaluations 1))))
    (.o (:: @ ObservabilitySlotPerformanceReceipt.)
        recommended-installation-phase: 'before-first-demand
        prototype-lookup-placement: 'before-repeated-construction
        prototype-iterations: +prototype-iterations+
        inline-prototype-count: inline-prototype-count-value
        hoisted-prototype-count: hoisted-prototype-count-value
        guard-count: +cold-count+
        cold-checksum: cold-checksum-value
        expected-cold-checksum: expected-cold-checksum-value
        warm-iterations: +warm-iterations+
        direct-warm-checksum: direct-warm-checksum-value
        guarded-warm-checksum: guarded-warm-checksum-value
        evaluation-count: evaluations
        traced-guard-count: +trace-count+
        trace-checksum: trace-checksum-value
        expected-trace-checksum: expected-trace-checksum-value
        semantic-valid?: semantic-valid-value)))
