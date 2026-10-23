;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Minimal native std/make cold/warm Scenario.

(import :gerbil/runtime/gambit "./benchmark-support")

(def (main . _)
  (let* ((scenario-root (current-directory))
         (run-root (benchmark-temporary-root "std-make-one-target"))
         (image (path-expand "image" run-root))
         (receipt-path
          (path-expand "darwin-native-std-make-one-target-receipt.ss"
                       (getenv "RUNNER_TEMP" run-root))))
    (create-directory* image)
    (let* ((command [(benchmark-gerbil) "interactive" "./build.ss"])
           (cold
            (benchmark-measure 'cold image scenario-root command
                               timeout: "60s"))
           (warm
            (map (lambda (index)
                   (benchmark-measure
                    (string->symbol
                     (string-append "warm" (number->string index)))
                    image scenario-root command))
                 (iota 3 1)))
           (warm-p50 (benchmark-warm-p50 warm))
           (warm-compile-count (benchmark-series-compile-count warm))
           (classification (benchmark-classification warm-p50))
           (receipt
            `((schema . agentic-ai-lab.darwin.native-std-make-one-target.v1)
              (upstreamRef . ,(getenv "GERBIL_SOURCE_REF" "v0.19-staging"))
              (upstreamSha . ,(getenv "UPSTREAM_SHA" "local"))
              (runner . ,(string-append (getenv "RUNNER_OS" "local") "-"
                                        (getenv "RUNNER_ARCH" "local")))
              (targetCount . 1)
              (buildCores . ,(string->number
                              (getenv "GERBIL_BUILD_CORES" "1")))
              (cold . ,cold)
              (warm . ,warm)
              (warmP50Ns . ,warm-p50)
              (warmCompileCount . ,warm-compile-count)
              (classification . ,classification))))
      (benchmark-write-receipt receipt-path receipt)
      (displayln "[std-make-benchmark] warm-p50-ns=" warm-p50
                 " warm-compile-count=" warm-compile-count
                 " classification=" classification
                 " receipt=" receipt-path)
      (unless (= warm-compile-count 0)
        (error "warm native leaf unexpectedly recompiled" warm))
      (when (eq? classification 'warm-budget-exceeded)
        (error "warm p50 exceeded Scenario budget" warm-p50)))))
