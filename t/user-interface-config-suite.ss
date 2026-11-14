;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: optional umbrella suite for explicitly requested config checks.
;;; Atomic CI discovery runs each imported owner directly; this file therefore
;;; deliberately does not use the `-test.ss` suffix.

(import (only-in :std/test test-suite)
        "user-interface-config-modules-test.ss"
        "user-interface-cicd-profile-case-test.ss"
        "user-interface-config-core-case-test.ss"
        "user-interface-config-sandbox-case-test.ss"
        "user-interface-profile-set-case-test.ss")

(export user-interface-config-suite)

;; : (-> Unit TestSuite)
(def user-interface-config-suite
  (test-suite "agentic-ai-lab user interface config"
    user-interface-config-modules-test
    user-interface-cicd-profile-case-test
    user-interface-config-core-case-test
    user-interface-config-sandbox-case-test
    user-interface-profile-set-case-test))
