;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-ref
                 benchmark-run/result
                 benchmark-receipt-pass?
                 make-micro-kernel-fixture
                 micro-kernel-fixture-contract-pass?
                 micro-kernel-receipt-pass?
                 micro-kernel-run/result)
        (only-in :clan/poo/object .o .ref)
        (only-in :yuanxu/observability/debug
                 YuanxuDebugSlotPolicyContract)
        (only-in "../support/poo-performance"
                 poo-performance-fixture-policy-contract-pass?
                 poo-performance-display-receipt)
        (only-in "../support/poo-performance-fixtures"
                 poo-performance-observability-slot-guard-fixture)
        "../scenarios/performance/poo-observability-slot-guard/scenario.ss")
(export observability-slot-performance-test)

(def prototype-lookup-fixture
  (make-micro-kernel-fixture
   'poo-debug-policy-prototype-lookup
   100
   100
   "Live calibration measured 67 ns/op; 100 ns/op is the target and 200 ns/op is the hard ceiling for native prototype slot lookup."))

(def prototype-compose-fixture
  (let (fixture
        (make-micro-kernel-fixture
         'poo-debug-policy-prototype-compose
         1500
         500
         "Live calibration measured 1438 ns/op; 1500 ns/op is the target and 2000 ns/op is the hard ceiling for one native prototype composition."))
    (cons '(warmupOperations . 2000)
          (cons '(batchOperations . 10000)
                (filter (lambda (entry)
                          (not (memq (car entry)
                                     '(warmupOperations batchOperations))))
                        fixture)))))

(def (display-micro-kernel-receipt receipt)
  (display "[agentic-ai-lab-micro-kernel] ")
  (write
   (map (lambda (key)
          (cons key (benchmark-fixture-ref receipt key)))
        '(schemaVersion name timingSource admissionStatistic operations sampleCount
          p50Ns p95Ns maxNs nsPerOpCeiling targetNsPerOp maxNsPerOp
          targetStatus status)))
  (newline)
  (force-output))

(def observability-slot-performance-test
  (test-suite "observability slot phase performance"
    (yuanxu-test-case "keeps prototype lookup in a native nanosecond envelope"
      (let-values (((receipt result)
                    (micro-kernel-run/result
                     prototype-lookup-fixture
                     (lambda ()
                       (.ref YuanxuDebugSlotPolicyContract 'proto)))))
        (display-micro-kernel-receipt receipt)
        (check-equal?
         (micro-kernel-fixture-contract-pass? prototype-lookup-fixture)
         #t)
        (check-equal? (benchmark-fixture-ref receipt 'schemaVersion) "1")
        (check-equal? (micro-kernel-receipt-pass? receipt) #t)
        (check-equal? (not (not result)) #t)))

    (yuanxu-test-case "keeps one prototype composition below two microseconds"
      (let (prototype (.ref YuanxuDebugSlotPolicyContract 'proto))
        (let-values (((receipt result)
                      (micro-kernel-run/result
                       prototype-compose-fixture
                       (lambda () (.o (:: @ prototype))))))
          (display-micro-kernel-receipt receipt)
          (check-equal?
           (micro-kernel-fixture-contract-pass? prototype-compose-fixture)
           #t)
          (check-equal? (benchmark-fixture-ref receipt 'schemaVersion) "1")
          (check-equal? (micro-kernel-receipt-pass? receipt) #t)
          (check-equal? (not (not result)) #t))))

    (yuanxu-test-case "keeps authoring, cold demand, warm cache, and trace distinct"
      (let (fixture (poo-performance-observability-slot-guard-fixture))
        (let-values (((gate receipt)
                      (benchmark-run/result
                       fixture
                       observability-slot-performance-scenario)))
          (poo-performance-display-receipt gate)
          (display "[agentic-ai-lab-benchmark] observability-slot ")
          (write (observability-slot-performance-receipt-sexp receipt))
          (newline)
          (force-output)
          (check-equal? (poo-performance-fixture-policy-contract-pass? fixture) #t)
          (check-equal? (benchmark-receipt-pass? gate) #t)
          (check-equal? (.ref receipt 'recommended-installation-phase) 'before-first-demand)
          (check-equal? (.ref receipt 'prototype-lookup-placement)
                        'before-repeated-construction)
          (check-equal? (.ref receipt 'cold-checksum) (.ref receipt 'expected-cold-checksum))
          (check-equal? (.ref receipt 'trace-checksum) (.ref receipt 'expected-trace-checksum))
          (check-equal? (.ref receipt 'evaluation-count) 1)
          (check-equal? (.ref receipt 'semantic-valid?) #t))))))
