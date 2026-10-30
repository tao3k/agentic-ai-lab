;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: lightweight composition benchmark gates.
;;; Invariant: composition macro scenarios should not import the whole
;;; performance support family just to load a few benchmark fixtures.

(import (only-in :clan/poo/object .o .ref)
        (only-in :asp-gerbil-scheme/benchmark-api benchmark-run))

(export poo-performance-composition-profile-declaration-fixture
        poo-performance-composition-profiles-bulk-fixture
        poo-performance-composition-local-override-fixture
        poo-performance-composition-hook-override-fixture
        poo-performance-composition-native-object-reuse-fixture
        poo-performance-composition-native-object-reuse-large-library-fixture
        poo-performance-native-object-list-indexed-family-fixture
        poo-performance-composition-macro-style-matrix-fixture
        poo-performance-family-run-gate
        +poo-performance-benchmark-receipt-family+)

;; : PooObject
(def +poo-performance-benchmark-receipt-family+
  (.o (kind 'poo-performance-family)
      (name 'poo-performance-benchmark-receipt-family)
      (source 'agentic-ai-lab.performance.benchmark)))

;; : (-> String Alist)
(def (poo-performance-load-fixture path)
  (call-with-input-file path read))

;; : (-> Alist)
(def (poo-performance-composition-profile-declaration-fixture)
  (poo-performance-load-fixture
   "t/scenarios/performance/poo-composition-profile-declaration/benchmark.ss"))

;; : (-> Alist)
(def (poo-performance-composition-profiles-bulk-fixture)
  (poo-performance-load-fixture
   "t/scenarios/performance/poo-composition-profiles-bulk/benchmark.ss"))

;; : (-> Alist)
(def (poo-performance-composition-local-override-fixture)
  (poo-performance-load-fixture
   "t/scenarios/performance/poo-composition-local-override/benchmark.ss"))

;; : (-> Alist)
(def (poo-performance-composition-hook-override-fixture)
  (poo-performance-load-fixture
   "t/scenarios/performance/poo-composition-hook-override/benchmark.ss"))

;; : (-> Alist)
(def (poo-performance-composition-native-object-reuse-fixture)
  (poo-performance-load-fixture
   "t/scenarios/performance/poo-composition-native-object-reuse/benchmark.ss"))

;; : (-> Alist)
(def (poo-performance-composition-native-object-reuse-large-library-fixture)
  (poo-performance-load-fixture
   "t/scenarios/performance/poo-composition-native-object-reuse-large-library/benchmark.ss"))

;; : (-> Alist)
(def (poo-performance-native-object-list-indexed-family-fixture)
  (poo-performance-load-fixture
   "t/scenarios/performance/poo-native-object-list-indexed-family/benchmark.ss"))

;; : (-> Alist)
(def (poo-performance-composition-macro-style-matrix-fixture)
  (poo-performance-load-fixture
   "t/scenarios/performance/poo-composition-macro-style-matrix/benchmark.ss"))

;; : (-> PooObject Alist Alist)
(def (poo-performance-family-alist family alist)
  (let* ((family-name (.ref family 'name))
         (source-tag (.ref family 'source))
         (with-family
          (if (assoc 'family alist)
            alist
            (cons (cons 'family family-name) alist))))
    (if (or (not source-tag) (assoc 'source with-family))
      with-family
      (cons (cons 'source source-tag) with-family))))

;; : (-> PooObject Alist (-> Value) Alist)
(def (poo-performance-family-run-gate family fixture thunk)
  (poo-performance-family-alist family (benchmark-run fixture thunk)))
