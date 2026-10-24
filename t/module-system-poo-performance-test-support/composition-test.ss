;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO composition macro and native extension performance gates.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-receipt-pass?)
        "./composition-scenarios")

(export composition-test)

;; : (-> (-> Integer Alist) Pair)
(def (poo-performance-composition-run-observed-gate gate)
  (poo-performance-composition-reset-construction-count!)
  (let (receipt (gate 1000))
    (list receipt
          (poo-performance-composition-construction-count))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-profile-declaration-case)
  (yuanxu-test-case "gates inline profile declarations as native POO objects"
    (let* ((observed
            (poo-performance-composition-run-observed-gate
             poo-performance-composition-profile-declaration-gate-receipt))
           (receipt (car observed))
           (construction-count (cadr observed)))
      (check-equal?
       (poo-performance-composition-profile-declaration-valid-count 1)
       1)
      (check-equal? construction-count 1)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-profiles-bulk-case)
  (yuanxu-test-case "gates grouped profiles import and compose syntax"
    (let* ((observed
            (poo-performance-composition-run-observed-gate
             poo-performance-composition-profiles-bulk-gate-receipt))
           (receipt (car observed))
           (construction-count (cadr observed)))
      (check-equal? (poo-performance-composition-profiles-bulk-valid-count 1)
                    1)
      (check-equal? construction-count 1)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-local-override-case)
  (yuanxu-test-case "gates local native POO override profiles"
    (let* ((observed
            (poo-performance-composition-run-observed-gate
             poo-performance-composition-local-override-gate-receipt))
           (receipt (car observed))
           (construction-count (cadr observed)))
      (check-equal? (poo-performance-composition-local-override-valid-count 1)
                    1)
      (check-equal? construction-count 1)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-hook-override-case)
  (yuanxu-test-case "gates reusable profile hook overrides"
    (let* ((observed
            (poo-performance-composition-run-observed-gate
             poo-performance-composition-hook-override-gate-receipt))
           (receipt (car observed))
           (construction-count (cadr observed)))
      (check-equal? (poo-performance-composition-hook-override-valid-count 1)
                    1)
      (check-equal? construction-count 1)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-native-object-reuse-case)
  (yuanxu-test-case "gates direct native POO object reuse"
    (let* ((observed
            (poo-performance-composition-run-observed-gate
             poo-performance-composition-native-object-reuse-gate-receipt))
           (receipt (car observed))
           (construction-count (cadr observed)))
      (check-equal?
       (poo-performance-composition-native-object-reuse-valid-count 1)
       1)
      (check-equal? construction-count 1)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-native-object-reuse-large-library-case)
  (yuanxu-test-case "gates 2048 native POO profiles plus hook variants"
    (let* ((observed
            (poo-performance-composition-run-observed-gate
             poo-performance-composition-native-object-reuse-large-library-gate-receipt))
           (receipt (car observed))
           (construction-count (cadr observed)))
      (check-equal?
       (poo-performance-composition-native-object-reuse-large-library-valid-count
        1)
       1)
      (check-equal? construction-count 1)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

(def (module-system-poo-performance-composition-lazy-demand-case)
  (yuanxu-test-case "gates POO composition lazy demand object reuse"
    (let* ((observed
            (poo-performance-composition-run-observed-gate
             poo-performance-composition-lazy-demand-gate-receipt))
           (receipt (car observed))
           (construction-count (cadr observed)))
      (check-equal?
       (poo-performance-composition-lazy-demand-valid-count 1)
       1)
      (check-equal? construction-count 0)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-native-object-list-indexed-family-case)
  (yuanxu-test-case "gates Project Harness-style POO object-list indexed family"
    (let* ((observed
            (poo-performance-composition-run-observed-gate
             poo-performance-native-object-list-indexed-family-gate-receipt))
           (receipt (car observed))
           (construction-count (cadr observed)))
      (check-equal?
       (poo-performance-native-object-list-indexed-family-valid-count 1)
       1)
      (check-equal? construction-count 1)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-macro-style-matrix-case)
  (yuanxu-test-case "gates high-performance composition macro styles"
    (let* ((observed
            (poo-performance-composition-run-observed-gate
             poo-performance-composition-macro-style-matrix-gate-receipt))
           (receipt (car observed))
           (construction-count (cadr observed)))
      (check-equal?
       (poo-performance-composition-macro-style-matrix-valid-count 1)
       1)
      (check-equal? construction-count 1)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; : TestSuite
(def composition-test
  (test-suite "agentic-ai-lab composition macro POO performance"
    (module-system-poo-performance-profile-declaration-case)
    (module-system-poo-performance-profiles-bulk-case)
    (module-system-poo-performance-local-override-case)
    (module-system-poo-performance-hook-override-case)
    (module-system-poo-performance-native-object-reuse-case)
    (module-system-poo-performance-native-object-reuse-large-library-case)
    (module-system-poo-performance-composition-lazy-demand-case)
    (module-system-poo-performance-native-object-list-indexed-family-case)
    (module-system-poo-performance-macro-style-matrix-case)))
