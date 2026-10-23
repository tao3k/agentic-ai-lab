;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check test-suite)
        (only-in "qualification/orgize-runtime-reuse.ss"
                 run-orgize-runtime-reuse-test))
(export orgize-runtime-reuse-test)

(def orgize-runtime-reuse-test
  (test-suite "Orgize POO runtime and C ABI dependency"
    (yuanxu-test-case "installed Orgize semantics are reused through Agentic AI Lab"
      (check (run-orgize-runtime-reuse-test) => #t))))
