;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in "../../../../use.ss" verify-deployment-runtime))
(export deployment-runtime-test)
(def deployment-runtime-test
  (test-suite "Downstream deployment runtime"
    (test-case "first native .get uses the selected B products"
      (verify-deployment-runtime))))
