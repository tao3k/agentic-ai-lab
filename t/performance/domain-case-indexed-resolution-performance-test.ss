;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: exclusive complexity gate for DomainCase winner resolution.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        :yuanxu/feature-system/domain-case/interface)

(export domain-case-indexed-resolution-performance-test)

(def +domain-case-indexed-resolution-fixture+
  (call-with-input-file
   "t/scenarios/performance/domain-case-indexed-resolution/benchmark.ss"
   read))

(def (domain-case-resolution-id prefix index)
  (string->symbol (string-append prefix (number->string index))))

(def (domain-case-resolution-slot index)
  (yuanxu-case-slot-contract
   (domain-case-resolution-id "slot/" index)
   (domain-case-resolution-id "owner/" index)
   'value 'required 'replace '() #f (lambda (_value) #t)))

(def (domain-case-resolution-method index)
  (yuanxu-case-method-contract
   (domain-case-resolution-id "contract/" index)
   (domain-case-resolution-id "owner/" index)
   (domain-case-resolution-id "subject/" index)
   'method 'Resolution 'any 'receipt
   (lambda (_context) #t)))

(def (domain-case-indexed-resolution-summary slots contracts)
  (let-values (((effective-slots slot-diagnostics)
                (domain-case-resolve-slots slots))
               ((effective-contracts contract-diagnostics)
                (domain-case-resolve-method-contracts contracts)))
    (list (cons 'slot-count (length effective-slots))
          (cons 'contract-count (length effective-contracts))
          (cons 'diagnostic-count
                (+ (length slot-diagnostics)
                   (length contract-diagnostics))))))

(def (domain-case-indexed-resolution-ref summary key)
  (cdr (assoc key summary)))

(def domain-case-indexed-resolution-performance-test
  (test-suite "DomainCase indexed resolution performance"
    (yuanxu-test-case "resolves 2000 slot and method identities"
      (let* ((count 2000)
             (slots (map domain-case-resolution-slot (iota count)))
             (contracts (map domain-case-resolution-method (iota count)))
             (summary
              (domain-case-indexed-resolution-summary slots contracts))
             (receipt
              (benchmark-run
               +domain-case-indexed-resolution-fixture+
               (lambda ()
                 (domain-case-indexed-resolution-summary slots contracts)))))
        (check-equal?
         (benchmark-fixture-contract-pass?
          +domain-case-indexed-resolution-fixture+)
         #t)
        (check-equal?
         (domain-case-indexed-resolution-ref summary 'slot-count) count)
        (check-equal?
         (domain-case-indexed-resolution-ref summary 'contract-count) count)
        (check-equal?
         (domain-case-indexed-resolution-ref summary 'diagnostic-count) 0)
        (display "[agentic-ai-lab-benchmark] domain-case-indexed-resolution ")
        (write receipt)
        (newline)
        (force-output)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
