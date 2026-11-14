;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: benchmark fixture catalog for POO performance scenarios.

(export poo-performance-load-fixture
        poo-performance-construction-fixture-path
        poo-performance-construction-fixture
        poo-performance-materialization-fixture-path
        poo-performance-materialization-fixture
        poo-performance-validation-fixture-path
        poo-performance-validation-fixture
        poo-performance-catalog-validation-fixture-path
        poo-performance-catalog-validation-fixture
        poo-performance-object-iteration-fixture-path
        poo-performance-object-iteration-fixture
        poo-performance-clone-override-fixture-path
        poo-performance-clone-override-fixture
        poo-performance-field-lookup-fixture-path
        poo-performance-field-lookup-fixture
        poo-performance-composition-fixture-path
        poo-performance-composition-fixture
        poo-performance-extension-children-merge-fixture-path
        poo-performance-extension-children-merge-fixture
        poo-performance-cross-contribution-targeting-fixture-path
        poo-performance-cross-contribution-targeting-fixture
        poo-performance-local-contribution-coalescing-fixture-path
        poo-performance-local-contribution-coalescing-fixture
        poo-performance-tool-calling-object-list-control-fixture-path
        poo-performance-tool-calling-object-list-control-fixture
        poo-performance-fixed-slot-projection-fixture-path
        poo-performance-fixed-slot-projection-fixture
        poo-performance-large-profile-projection-fixture-path
        poo-performance-large-profile-projection-fixture
        poo-performance-generated-receipt-boundary-fixture-path
        poo-performance-generated-receipt-boundary-fixture
        poo-performance-runtime-request-family-fixture-path
        poo-performance-runtime-request-family-fixture
        poo-performance-policy-proof-fact-family-fixture-path
        poo-performance-policy-proof-fact-family-fixture
        poo-performance-strategy-profile-family-fixture-path
        poo-performance-strategy-profile-family-fixture
        poo-performance-durable-receipt-family-fixture-path
        poo-performance-durable-receipt-family-fixture
        poo-performance-benchmark-fixture-family-fixture-path
        poo-performance-benchmark-fixture-family-fixture
        poo-performance-marlin-runtime-handoff-profile-fixture-path
        poo-performance-marlin-runtime-handoff-profile-fixture
        poo-performance-prototype-composition-cache-fixture-path
        poo-performance-prototype-composition-cache-fixture
        poo-performance-observability-slot-guard-fixture-path
        poo-performance-observability-slot-guard-fixture
        poo-performance-composition-profile-declaration-fixture-path
        poo-performance-composition-profile-declaration-fixture
        poo-performance-composition-profiles-bulk-fixture-path
        poo-performance-composition-profiles-bulk-fixture
        poo-performance-composition-local-override-fixture-path
        poo-performance-composition-local-override-fixture
        poo-performance-composition-hook-override-fixture-path
        poo-performance-composition-hook-override-fixture
        poo-performance-composition-poo-object-reuse-fixture-path
        poo-performance-composition-poo-object-reuse-fixture
        poo-performance-composition-poo-object-reuse-large-library-fixture-path
        poo-performance-composition-poo-object-reuse-large-library-fixture
        poo-performance-composition-lazy-demand-fixture-path
        poo-performance-composition-lazy-demand-fixture
        poo-performance-composition-macro-style-matrix-fixture-path
        poo-performance-composition-macro-style-matrix-fixture
        poo-performance-fixture-paths
        poo-performance-fixtures)

;; : (-> String Alist)
(def (poo-performance-load-fixture path)
  (call-with-input-file path read))

;; : String
(def poo-performance-construction-fixture-path
  "t/scenarios/performance/poo-construction/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-construction-fixture)
  (poo-performance-load-fixture poo-performance-construction-fixture-path))

;; : String
(def poo-performance-materialization-fixture-path
  "t/scenarios/performance/poo-loop-materialization/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-materialization-fixture)
  (poo-performance-load-fixture poo-performance-materialization-fixture-path))

;; : String
(def poo-performance-validation-fixture-path
  "t/scenarios/performance/poo-loop-validation/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-validation-fixture)
  (poo-performance-load-fixture poo-performance-validation-fixture-path))

;; : String
(def poo-performance-catalog-validation-fixture-path
  "t/scenarios/performance/poo-catalog-validation/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-catalog-validation-fixture)
  (poo-performance-load-fixture poo-performance-catalog-validation-fixture-path))

;; : String
(def poo-performance-object-iteration-fixture-path
  "t/scenarios/performance/poo-object-iteration/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-object-iteration-fixture)
  (poo-performance-load-fixture poo-performance-object-iteration-fixture-path))

;; : String
(def poo-performance-clone-override-fixture-path
  "t/scenarios/performance/poo-clone-override/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-clone-override-fixture)
  (poo-performance-load-fixture poo-performance-clone-override-fixture-path))

;; : String
(def poo-performance-field-lookup-fixture-path
  "t/scenarios/performance/poo-field-lookup-loop/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-field-lookup-fixture)
  (poo-performance-load-fixture poo-performance-field-lookup-fixture-path))

;; : String
(def poo-performance-composition-fixture-path
  "t/scenarios/performance/poo-loop-composition/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-composition-fixture)
  (poo-performance-load-fixture poo-performance-composition-fixture-path))

;; : String
(def poo-performance-extension-children-merge-fixture-path
  "t/scenarios/performance/poo-extension-children-merge/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-extension-children-merge-fixture)
  (poo-performance-load-fixture
   poo-performance-extension-children-merge-fixture-path))

;; : String
(def poo-performance-cross-contribution-targeting-fixture-path
  "t/scenarios/performance/poo-cross-contribution-targeting/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-cross-contribution-targeting-fixture)
  (poo-performance-load-fixture
   poo-performance-cross-contribution-targeting-fixture-path))

;; : String
(def poo-performance-local-contribution-coalescing-fixture-path
  "t/scenarios/performance/poo-local-contribution-coalescing/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-local-contribution-coalescing-fixture)
  (poo-performance-load-fixture
   poo-performance-local-contribution-coalescing-fixture-path))

;; : String
(def poo-performance-tool-calling-object-list-control-fixture-path
  "t/scenarios/performance/tool-calling-object-list-control/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-tool-calling-object-list-control-fixture)
  (poo-performance-load-fixture
   poo-performance-tool-calling-object-list-control-fixture-path))

;; : String
(def poo-performance-fixed-slot-projection-fixture-path
  "t/scenarios/performance/poo-fixed-slot-projection/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-fixed-slot-projection-fixture)
  (poo-performance-load-fixture
   poo-performance-fixed-slot-projection-fixture-path))

;; : String
(def poo-performance-large-profile-projection-fixture-path
  "t/scenarios/performance/poo-large-profile-projection/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-large-profile-projection-fixture)
  (poo-performance-load-fixture
   poo-performance-large-profile-projection-fixture-path))

;; : String
(def poo-performance-generated-receipt-boundary-fixture-path
  "t/scenarios/performance/poo-generated-receipt-boundary/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-generated-receipt-boundary-fixture)
  (poo-performance-load-fixture
   poo-performance-generated-receipt-boundary-fixture-path))

;; : String
(def poo-performance-runtime-request-family-fixture-path
  "t/scenarios/performance/poo-runtime-request-family/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-runtime-request-family-fixture)
  (poo-performance-load-fixture
   poo-performance-runtime-request-family-fixture-path))

;; : String
(def poo-performance-policy-proof-fact-family-fixture-path
  "t/scenarios/performance/poo-policy-proof-fact-family/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-policy-proof-fact-family-fixture)
  (poo-performance-load-fixture
   poo-performance-policy-proof-fact-family-fixture-path))

;; : String
(def poo-performance-strategy-profile-family-fixture-path
  "t/scenarios/performance/poo-strategy-profile-family/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-strategy-profile-family-fixture)
  (poo-performance-load-fixture
   poo-performance-strategy-profile-family-fixture-path))

;; : String
(def poo-performance-durable-receipt-family-fixture-path
  "t/scenarios/performance/poo-durable-receipt-family/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-durable-receipt-family-fixture)
  (poo-performance-load-fixture
   poo-performance-durable-receipt-family-fixture-path))

;; : String
(def poo-performance-benchmark-fixture-family-fixture-path
  "t/scenarios/performance/poo-benchmark-fixture-family/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-benchmark-fixture-family-fixture)
  (poo-performance-load-fixture
   poo-performance-benchmark-fixture-family-fixture-path))

;; : String
(def poo-performance-marlin-runtime-handoff-profile-fixture-path
  "t/scenarios/performance/poo-marlin-runtime-handoff-profile/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-marlin-runtime-handoff-profile-fixture)
  (poo-performance-load-fixture
   poo-performance-marlin-runtime-handoff-profile-fixture-path))

;; : String
(def poo-performance-prototype-composition-cache-fixture-path
  "t/scenarios/performance/poo-prototype-composition-cache/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-prototype-composition-cache-fixture)
  (poo-performance-load-fixture
   poo-performance-prototype-composition-cache-fixture-path))

;; : String
(def poo-performance-observability-slot-guard-fixture-path
  "t/scenarios/performance/poo-observability-slot-guard/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-observability-slot-guard-fixture)
  (poo-performance-load-fixture
   poo-performance-observability-slot-guard-fixture-path))

;; : String
(def poo-performance-composition-profile-declaration-fixture-path
  "t/scenarios/performance/poo-composition-profile-declaration/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-composition-profile-declaration-fixture)
  (poo-performance-load-fixture
   poo-performance-composition-profile-declaration-fixture-path))

;; : String
(def poo-performance-composition-profiles-bulk-fixture-path
  "t/scenarios/performance/poo-composition-profiles-bulk/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-composition-profiles-bulk-fixture)
  (poo-performance-load-fixture
   poo-performance-composition-profiles-bulk-fixture-path))

;; : String
(def poo-performance-composition-local-override-fixture-path
  "t/scenarios/performance/poo-composition-local-override/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-composition-local-override-fixture)
  (poo-performance-load-fixture
   poo-performance-composition-local-override-fixture-path))

;; : String
(def poo-performance-composition-hook-override-fixture-path
  "t/scenarios/performance/poo-composition-hook-override/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-composition-hook-override-fixture)
  (poo-performance-load-fixture
   poo-performance-composition-hook-override-fixture-path))

;; : String
(def poo-performance-composition-poo-object-reuse-fixture-path
  "t/scenarios/performance/poo-composition-poo-object-reuse/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-composition-poo-object-reuse-fixture)
  (poo-performance-load-fixture
   poo-performance-composition-poo-object-reuse-fixture-path))

;; : String
(def poo-performance-composition-poo-object-reuse-large-library-fixture-path
  "t/scenarios/performance/poo-composition-poo-object-reuse-large-library/benchmark.ss")

(def poo-performance-composition-lazy-demand-fixture-path
  "t/scenarios/performance/poo-composition-lazy-demand/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-composition-poo-object-reuse-large-library-fixture)
  (poo-performance-load-fixture
   poo-performance-composition-poo-object-reuse-large-library-fixture-path))

;; : (-> Alist)
(def (poo-performance-composition-lazy-demand-fixture)
  (poo-performance-load-fixture
   poo-performance-composition-lazy-demand-fixture-path))

;; : String
(def poo-performance-composition-macro-style-matrix-fixture-path
  "t/scenarios/performance/poo-composition-macro-style-matrix/benchmark.ss")

;; : (-> Alist)
(def (poo-performance-composition-macro-style-matrix-fixture)
  (poo-performance-load-fixture
   poo-performance-composition-macro-style-matrix-fixture-path))

;; : [String]
(def poo-performance-fixture-paths
  (list poo-performance-construction-fixture-path
        poo-performance-materialization-fixture-path
        poo-performance-validation-fixture-path
        poo-performance-catalog-validation-fixture-path
        poo-performance-object-iteration-fixture-path
        poo-performance-clone-override-fixture-path
        poo-performance-field-lookup-fixture-path
        poo-performance-extension-children-merge-fixture-path
        poo-performance-cross-contribution-targeting-fixture-path
        poo-performance-local-contribution-coalescing-fixture-path
        poo-performance-tool-calling-object-list-control-fixture-path
        poo-performance-fixed-slot-projection-fixture-path
        poo-performance-large-profile-projection-fixture-path
        poo-performance-generated-receipt-boundary-fixture-path
        poo-performance-runtime-request-family-fixture-path
        poo-performance-policy-proof-fact-family-fixture-path
        poo-performance-strategy-profile-family-fixture-path
        poo-performance-durable-receipt-family-fixture-path
        poo-performance-benchmark-fixture-family-fixture-path
        poo-performance-marlin-runtime-handoff-profile-fixture-path
        poo-performance-prototype-composition-cache-fixture-path
        poo-performance-observability-slot-guard-fixture-path
        poo-performance-composition-profile-declaration-fixture-path
        poo-performance-composition-profiles-bulk-fixture-path
        poo-performance-composition-local-override-fixture-path
        poo-performance-composition-hook-override-fixture-path
        poo-performance-composition-poo-object-reuse-fixture-path
        poo-performance-composition-poo-object-reuse-large-library-fixture-path
        poo-performance-composition-lazy-demand-fixture-path
        poo-performance-composition-macro-style-matrix-fixture-path
        poo-performance-composition-fixture-path))

;; : (-> [Alist])
(def (poo-performance-fixtures)
  (map poo-performance-load-fixture poo-performance-fixture-paths))
