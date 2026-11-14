;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(begin-syntax
  (displayln "LAB-DEPLOYMENT-IMPORT runtime-test enter")
  (force-output))
(import :std/test
        (only-in "../../../../../use.ss" verify-deployment-runtime))
(begin-syntax
  (displayln "LAB-DEPLOYMENT-IMPORT runtime-test expanded")
  (force-output))
(displayln "LAB-DEPLOYMENT-IMPORT runtime-test initialized")
(force-output)
(export deployment-runtime-test)
(def deployment-runtime-test
  (test-suite "Downstream deployment runtime"
    (test-case "first native .get uses the selected B products"
      (verify-deployment-runtime))))
