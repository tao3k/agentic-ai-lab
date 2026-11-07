;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later


(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .ref)
        "../scenarios/performance/composition-macro-expansion/benchmark.ss")

(export profile-composition-performance-test)

(def profile-composition-performance-test
  (test-suite
   "profile composition expansion performance"
   (yuanxu-test-case
    "1000 and 5000 profile expansion remain bounded"
    (let* ((receipt (run-composition-macro-expansion-benchmark))
           (case-1000 (.ref receipt 'case-1000))
           (case-5000 (.ref receipt 'case-5000-second)))
      (check-equal?
       (.ref case-1000 'profile-count)
       1000)
      (check-equal?
       (.ref case-1000 'generated-profile-expression-count)
       1000)
      (check-equal?
       (.ref case-5000 'profile-count)
       5000)
      (check-equal?
       (.ref case-5000 'generated-compose-reference-count)
       5000)
      (check-equal?
       (.ref case-1000 'gsc-executed)
       #f)
      (check-equal?
       (.ref case-1000 'timing-source)
       ":std/time/precise#current-time-precise")
      (check-equal?
       (.ref receipt 'pass)
       #t)))))
