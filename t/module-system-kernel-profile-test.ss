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
        (only-in :poo-flow/modules/workflow/profiles/kernel/interface
                 poo-flow-kernel-module-bundles
                 poo-flow-kernel-profile-module-bundles
                 poo-flow-kernel-profile
                 poo-flow-kernel-profile-set
                 poo-flow-kernel-profile-modules)
        "user-interface-fixtures.ss")

(export module-system-kernel-profile-test)

;; : TestSuite
(def module-system-kernel-profile-test
  (test-suite "poo-flow module-system kernel profile"
    (yuanxu-test-case "exports kernel profile runtime values from public facade"
      (check-equal? (yuanxu-user-profile-name poo-flow-kernel-profile)
                    'kernel)
      (check-equal? (yuanxu-user-profile-set-name poo-flow-kernel-profile-set)
                    'kernel-profiles)
      (check-equal? (yuanxu-user-profile-set-default-profile-name
                     poo-flow-kernel-profile-set)
                    'kernel)
      (check-equal? (yuanxu-user-profile-modules poo-flow-kernel-profile)
                    poo-flow-kernel-profile-modules)
      (check-equal? (> (length poo-flow-kernel-profile-module-bundles) 0)
                    #t)
      (check-equal? (> (length poo-flow-kernel-profile-modules) 0)
                    #t)
      (check-equal? (length poo-flow-kernel-module-bundles) 6)
      (check-equal? (length poo-flow-kernel-profile-module-bundles) 6))
    (yuanxu-test-case "user interface fixtures compile against explicit kernel imports"
      (check-equal? (yuanxu-user-profile-name test-poo-flow-user-profile)
                    'developer)
      (check-equal? (yuanxu-user-profile-set-name
                     test-poo-flow-user-profile-set)
                    'workspace)
      (check-equal? (yuanxu-user-profile-set-default-profile-name
                     test-poo-flow-user-profile-set)
                    'developer)
      (check-equal? (> (length test-yuanxu-user-module-bundles) 0)
                    #t)
      (check-equal? (yuanxu-user-profile-module-bundles
                     test-poo-flow-user-profile)
                    test-yuanxu-user-module-bundles))))
