;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/workflow/qualification/performance-matrix)

(export performance-matrix-test)

(def performance-matrix-test
  (test-suite "AC-10 S5 performance matrix"
    (poo-flow-test-case "existing owners cover the supported Cartesian matrix"
      (let (receipt
            (poo-flow-performance-matrix-verify
             "bindings/runtime-c/benchmarks/receipts/runtime_v0_batch_macos_arm64.receipt"
             "bindings/runtime-c/benchmarks/receipts/proof_case_v1_macos_arm64.receipt"
             "packages/proofs/python/benchmarks/receipts/proof_case_cffi_wheel_macos_arm64.receipt"))
        (check (.ref receipt 'accepted?) => #t)
        (check (.ref receipt 'runtime-block-count) => 140)
        (check (.ref receipt 'batch-sizes) => '(1 8 32 128 1024))
        (check (.ref receipt 'payload-bytes) => '(0 1024 65536 1048576))
        (check (.ref receipt 'proof-profiles) => '(strict batched))
        (check (.ref receipt 'threshold-status) => 'baseline-only)
        (check (.ref receipt 'unsupported-dimensions)
               => '((restore . no-runtime-benchmark-owner)
                    (absolute-latency-budget . insufficient-host-series)))))))
