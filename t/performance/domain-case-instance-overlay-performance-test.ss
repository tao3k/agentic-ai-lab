;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        "../support/performance")

(export domain-case-instance-overlay-performance-test)

(def domain-case-instance-overlay-performance-test
  (test-suite "DomainCase instance overlay hot path"
    (yuanxu-test-case "constant-slot overlay removes per-Agent C4 mix"
      (let (receipts (run-domain-case-instance-overlay-benchmark))
        (check (map (lambda (receipt) (.ref receipt 'shared-slot-count))
                    receipts)
               => '(8 32 64))
        (for-each
         (lambda (receipt)
           (check (.ref receipt 'agent-count) => 5000)
           (check (.ref receipt 'sample-count) => 20)
           (check (.ref receipt 'max-overlay-p95-us) => 1000000)
           (check (.ref receipt 'materialized-slot-count)
                  => (+ (.ref receipt 'shared-slot-count) 4))
           (check (.ref receipt 'legacy-reference-count) => 1)
           (check (.ref receipt 'overlay-mix-count) => 0)
           (check (.ref receipt 'resolver-depth) => 1)
           (check (.ref receipt 'construction-complexity)
                  => 'native-base-override)
           (check (.ref receipt 'lookup-source-depth)
                  => 'constant-source-depth)
           (check (.ref receipt 'correct?) => #t)
           (check (.ref receipt 'shared-prototype-retained?) => #t)
           (check (.ref receipt 'local-precedence-valid?) => #t)
           (check (.ref receipt 'timing-pass?) => #t)
           (check (.ref receipt 'pass?) => #t))
         receipts)))))
