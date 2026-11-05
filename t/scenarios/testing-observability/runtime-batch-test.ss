;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Minimal runtime gxtest fixture for the Agentic AI Lab operation-observation lane.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test)

(export runtime-batch-test)

(def runtime-batch-test
  (test-suite "Agentic AI Lab observed runtime batch fixture"
    (yuanxu-test-case "runs through the upstream Gerbil test executor"
      (check #t => #t))))
