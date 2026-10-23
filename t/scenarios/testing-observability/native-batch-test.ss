;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Minimal native gxtest fixture for the Agentic AI Lab operation-observation lane.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test)

(export native-batch-test)

(def native-batch-test
  (test-suite "Agentic AI Lab observed native batch fixture"
    (yuanxu-test-case "runs through the upstream Gerbil test executor"
      (check #t => #t))))
