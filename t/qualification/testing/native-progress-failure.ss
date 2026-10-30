;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; A real Gerbil failure control, outside ordinary *-test.ss discovery.
(import :std/test)
(export failed-test)
(def failed-test
  (test-suite "Native Gerbil failure control"
    (test-case "failed assertion cannot become successful process status"
      (check-equal? 42 0))))
