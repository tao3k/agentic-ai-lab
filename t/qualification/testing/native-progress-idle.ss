;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (for-syntax (only-in :yuanxu/observability/testing-source install-test-source-observation!)))
(begin-syntax (install-test-source-observation!))
(import :std/test (only-in :gerbil/expander import-module))
(export idle-test)
(def idle-test
  (test-suite "Cached module demands cannot renew liveness"
    (test-case "repeated import is still an idle Case"
      ;; All demands resolve to the same Gerbil instance. No completed new work
      ;; can hide this intentional delay from the 30-second watchdog.
      (let loop ((remaining 1800))
        (unless (zero? remaining)
          (import-module ':std/list/list)
          (thread-sleep! 0.05)
          (loop (- remaining 1)))))))
