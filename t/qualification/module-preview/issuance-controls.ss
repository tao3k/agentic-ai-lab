;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Reuse the producer's actual controls; no duplicated test implementation.
(import :std/test
        (only-in :std/test/base test-suite! TestResult-result)
        (prefix-in :clan/poo/t/issued-read-test producer.))
(export issuance-controls-test)
(def issuance-controls-test
  (test-suite "Producer issuance controls on the measured runtime"
    (test-case "original identities, misses, callbacks and routes"
      (def result (test-suite! producer.issued-read-test))
      (check-equal? (TestResult-result result) 'OK)
      (producer.test-cleanup!))))
