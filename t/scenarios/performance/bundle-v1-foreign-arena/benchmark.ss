;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :gerbil/runtime/gambit
        :clan/poo/object
        :yuanxu/utilities/functional
        :yuanxu/feature-system/bundle-v1-lowering
        :yuanxu/feature-system/bundle-v1-foreign-arena)

(def +benchmark-schema+
  'agentic-ai-lab.bundle-v1-foreign-arena.benchmark.v1)

(def (environment-positive-integer name default-value)
  (let* ((raw (getenv name))
         (value (and raw (string->number raw))))
    (if (and (exact-integer? value) (> value 0))
      value
      default-value)))

(def (indexed-symbol prefix index)
  (string->symbol (string-append prefix (number->string index))))

(def (benchmark-component index)
  (feature-bundle-v1-component
   'benchmark-case
   (indexed-symbol "component-" index)
   (indexed-symbol "object-" index)
   'benchmark-type
   'benchmark-contract
   (indexed-symbol "role-" (modulo index 64))
   (indexed-symbol "capability-" (modulo index 128))
   (indexed-symbol "policy-" (modulo index 32))
   (indexed-symbol "strategy-" (modulo index 16))
   'benchmark-adapter
   'benchmark-projection
   index))

(def (now-seconds)
  (time->seconds (current-time)))

(def (elapsed-milliseconds started)
  (inexact->exact (round (* 1000 (- (now-seconds) started)))))

(def (emit-receipt-field name value)
  (display name)
  (display "=")
  (display value)
  (newline))

(def (run-benchmark)
  (let* ((component-count
          (environment-positive-integer
           "AGENTIC_AI_LAB_BUNDLE_V1_BENCH_COMPONENTS" 4096))
         (generation-started (now-seconds))
         (components
          (yuanxu-map benchmark-component (iota component-count)))
         (generation-ms (elapsed-milliseconds generation-started))
         (lowering-started (now-seconds))
         (plan
          (feature-bundle-v1-lowering
           'bundle-v1-foreign-arena-benchmark 1 components '() '()))
         (lowering-ms (elapsed-milliseconds lowering-started))
         (packing-started (now-seconds))
         (image
          (require-feature-bundle-v1-foreign-arena-image
           (feature-bundle-v1-write-foreign-arena plan)))
         (packing-ms (elapsed-milliseconds packing-started)))
    (unless (= (length (.ref (.ref image 'descriptor) 'component-rows))
               component-count)
      (error "Bundle v1 benchmark lost component rows" component-count))
    (emit-receipt-field "schema" +benchmark-schema+)
    (emit-receipt-field "components" component-count)
    (emit-receipt-field "generation-ms" generation-ms)
    (emit-receipt-field "lowering-ms" lowering-ms)
    (emit-receipt-field "packing-ms" packing-ms)
    (emit-receipt-field "descriptor-bytes"
                        (u8vector-length (.ref image 'descriptor-image)))
    (emit-receipt-field "arena-bytes" (.ref image 'arena-length))
    (emit-receipt-field "writer-complexity" "O(n)")
    (emit-receipt-field "runtime-component-lookup" "O(log n)")
    (emit-receipt-field "json-in-hot-path" "false")))

(run-benchmark)
