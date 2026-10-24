;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: kernel profile and user-interface fixture integration checks.
;;; Invariant: descriptor activation unit tests do not load kernel profile rows.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 test-suite
                 check-equal?)
        (only-in :yuanxu/profile-composition/user-profile
                 yuanxu-user-profile-name
                 yuanxu-user-profile-set-name
                 yuanxu-user-profile-set-default-profile-name
                 yuanxu-user-profile-module-bundles
                 yuanxu-user-profile-modules)
        (only-in :agentic-ai-lab/modules/workflow/profiles/kernel/interface
                 agentic-ai-lab-kernel-module-bundles
                 agentic-ai-lab-kernel-profile-module-bundles
                 agentic-ai-lab-kernel-profile
                 agentic-ai-lab-kernel-profile-set
                 agentic-ai-lab-kernel-profile-modules)
        "user-interface-fixtures.ss")

(export module-system-kernel-profile-test)

;; : TestSuite
(def module-system-kernel-profile-test
  (test-suite "agentic-ai-lab module-system kernel profile"
    (yuanxu-test-case "exports kernel profile runtime values from public facade"
      (check-equal? (yuanxu-user-profile-name agentic-ai-lab-kernel-profile)
                    'kernel)
      (check-equal? (yuanxu-user-profile-set-name agentic-ai-lab-kernel-profile-set)
                    'kernel-profiles)
      (check-equal? (yuanxu-user-profile-set-default-profile-name
                     agentic-ai-lab-kernel-profile-set)
                    'kernel)
      (check-equal? (yuanxu-user-profile-modules agentic-ai-lab-kernel-profile)
                    agentic-ai-lab-kernel-profile-modules)
      (check-equal? (> (length agentic-ai-lab-kernel-profile-module-bundles) 0)
                    #t)
      (check-equal? (> (length agentic-ai-lab-kernel-profile-modules) 0)
                    #t)
      (check-equal? (length agentic-ai-lab-kernel-module-bundles) 6)
      (check-equal? (length agentic-ai-lab-kernel-profile-module-bundles) 6))
    (yuanxu-test-case "user interface fixtures compile against explicit kernel imports"
      (check-equal? (yuanxu-user-profile-name test-agentic-ai-lab-user-profile)
                    'developer)
      (check-equal? (yuanxu-user-profile-set-name
                     test-agentic-ai-lab-user-profile-set)
                    'workspace)
      (check-equal? (yuanxu-user-profile-set-default-profile-name
                     test-agentic-ai-lab-user-profile-set)
                    'developer)
      (check-equal? (> (length test-yuanxu-user-module-bundles) 0)
                    #t)
      (check-equal? (yuanxu-user-profile-module-bundles
                     test-agentic-ai-lab-user-profile)
                    test-yuanxu-user-module-bundles))))
