;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :std/misc/process run-process)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-run/result benchmark-fixture-contract-pass? benchmark-receipt-pass?))
(export temporal-mrr-native-test)
(def fixture (call-with-input-file "t/scenarios/performance/temporal-mrr-native/benchmark.ss" read))
(def temporal-mrr-native-test
  (test-suite "ASP native Temporal MRR benchmark"
    (test-case "original typed MRR values reach native Scheme in every sample"
      (check-equal? (benchmark-fixture-contract-pass? fixture) #t)
      (let* ((binary (getenv "AGENTIC_AI_LAB_MRR_TEST_BINARY"))
             (output (getenv "AGENTIC_AI_LAB_MRR_BENCHMARK_RECEIPT"))
             (binary-digest (hex-encode (sha256 (call-with-input-file binary read-all-as-u8vector))))
             (completed 0))
        (let-values (((receipt result)
                      (benchmark-run/result fixture
                        (lambda ()
                          (let (transcript
                                (run-process
                                 (list "timeout" "--signal=TERM" "--kill-after=1s" "5s"
                                       binary "--exact" "original_mrr_values_project_to_real_native_poo" "--nocapture")))
                            (unless (and (string-contains transcript "MRR-ORIGINAL-RECEIPT -> HOST-CORRESPONDENCE -> NATIVE-POO verified")
                                         (string-contains transcript "test result: ok. 1 passed; 0 failed"))
                              (error "native scenario did not execute its semantic assertions" transcript)))
                          (set! completed (+ completed 1))
                          (displayln "MRR-NATIVE-SAMPLE completed=" completed)
                          (force-output)
                          'native-assertions-passed))))
          (call-with-output-file output
            (lambda (port)
              (write (append
                      `((schema . agentic-ai-lab.temporal-mrr-asp-benchmark.v2)
                        (measurement-owner . asp-gerbil-scheme/benchmark-api)
                        (test-binary-sha256 . ,binary-digest)
                        (native-artifact-sha256 . ,(getenv "AGENTIC_AI_LAB_SEMANTIC_SHA256"))
                        (source-digests . ,(map (lambda (path)
                           (cons path (hex-encode (sha256 (call-with-input-file path read-all-as-u8vector)))))
                           '("gerbil.pkg" ".ci/mrr-runtime/runtime/src/lib.rs" ".ci/mrr-runtime/runtime/src/mrr.rs"
                             ".ci/mrr-runtime/runtime/src/wire.rs" ".ci/mrr-runtime/runtime/tests/mrr.rs"
                             ".ci/mrr-runtime/runtime/Cargo.lock" "src/ffi/scheme-wire.ss"
                             "t/qualification/temporal-mrr-native-test.ss"
                             "t/scenarios/performance/temporal-mrr-native/benchmark.ss")))
                        (semantic-samples . ,completed)
                        (result . ,result)) receipt) port)
              (newline port)))
          (check-equal? completed 20)
          (check-equal? result 'native-assertions-passed)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))))
