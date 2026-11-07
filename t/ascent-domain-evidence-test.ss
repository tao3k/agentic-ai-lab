;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :std/test check-equal? test-suite test-case)
        (only-in :agentic-ai-lab/modules/evidence-assessment/domain-checks ascent-domain-check))
(export ascent-domain-evidence-test)
(def ascent-domain-evidence-test
  (test-suite "exact observed domain constraints"
    (test-case "graph update conservation and stale reads"
      (check-equal?
       (hash-ref (car (ascent-domain-check "graph-update" '(("a" 2 1 5 2 3)))) "claims")
       '(("update-read-version" #f) ("path-count-conservation" #t) ("path-count-nonnegative" #t))))
    (test-case "inconsistent traversal rejected"
      (check-equal?
       (hash-ref (car (ascent-domain-check "graph-schedule" '(("a" (1 3 7 9) (1 3) (3 1))))) "claims")
       '(("update-traversal-coherence" #f))))
    (test-case "negative root requires more internal precision"
      (let (result (car (ascent-domain-check "series-precision" '(("a" (1 1) -1 (3 1) (2 1) (0 1) #t)))))
        (check-equal? (hash-ref result "requiredInternalPrecision") '(4 1))
        (check-equal? (hash-ref result "claims") '(("precision-budget" #f) ("precision-boundary" #t)))))
    (test-case "fractional restoration excludes equality boundary"
      (let (result (car (ascent-domain-check "series-precision" '(("a" (1 1) 3 (1 1) (2 3) (2 3) #f)))))
        (check-equal? (hash-ref result "shouldInclude") #f)
        (check-equal? (hash-ref result "claims") '(("precision-budget" #t) ("precision-boundary" #t)))))))
