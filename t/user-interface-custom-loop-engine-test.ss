;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests verify custom user-interface loop-engine declarations.
;;; Invariant: custom loop cases project intent data and never execute loops.

(import (only-in :std/test test-suite)
        "./support/custom-loop-engine/case")

(export user-interface-custom-loop-engine-test)

;; : TestSuite
(def user-interface-custom-loop-engine-test
  (test-suite "agentic-ai-lab custom user-interface loop-engine cases"
    (user-interface-custom-loop-engine-concrete-case)))
