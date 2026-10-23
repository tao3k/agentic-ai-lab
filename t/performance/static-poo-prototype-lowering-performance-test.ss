;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        "../scenarios/performance/static-poo-prototype-lowering/benchmark.ss")

(export static-poo-prototype-lowering-performance-test)

(def (static-poo-prototype-benchmark-ref receipt key)
  (let (row (assq key receipt))
    (and row (cdr row))))

(def static-poo-prototype-lowering-performance-test
  (test-suite "static POO prototype lowering performance"
    (yuanxu-test-case "avoids full .o normalization for bounded constant rows"
      (let (receipt (static-poo-prototype-lowering-benchmark))
        (display "[agentic-ai-lab-benchmark] static-poo-prototype-lowering ")
        (write receipt)
        (newline)
        (force-output)
        (check-equal?
         (static-poo-prototype-benchmark-ref receipt 'same-source-shape)
         #t)
        (check-equal?
         (static-poo-prototype-benchmark-ref receipt 'writes-compiled-artifacts)
         #f)
        (check-equal?
         (static-poo-prototype-benchmark-ref receipt 'pass)
         #t)))))
