;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: kernel profile and user-interface fixture integration checks.
;;; Invariant: descriptor activation unit tests do not load kernel profile rows.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 test-suite
                 check-equal?)
        (only-in :core/profile-composition/user-profile
                 poo-flow-user-profile-name
                 poo-flow-user-profile-set-name
                 poo-flow-user-profile-set-default-profile-name
                 poo-flow-user-profile-module-bundles
                 poo-flow-user-profile-modules)
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
    (poo-flow-test-case "exports kernel profile runtime values from public facade"
      (check-equal? (poo-flow-user-profile-name poo-flow-kernel-profile)
                    'kernel)
      (check-equal? (poo-flow-user-profile-set-name poo-flow-kernel-profile-set)
                    'kernel-profiles)
      (check-equal? (poo-flow-user-profile-set-default-profile-name
                     poo-flow-kernel-profile-set)
                    'kernel)
      (check-equal? (poo-flow-user-profile-modules poo-flow-kernel-profile)
                    poo-flow-kernel-profile-modules)
      (check-equal? (> (length poo-flow-kernel-profile-module-bundles) 0)
                    #t)
      (check-equal? (> (length poo-flow-kernel-profile-modules) 0)
                    #t)
      (check-equal? (length poo-flow-kernel-module-bundles) 6)
      (check-equal? (length poo-flow-kernel-profile-module-bundles) 6))
    (poo-flow-test-case "user interface fixtures compile against explicit kernel imports"
      (check-equal? (poo-flow-user-profile-name test-poo-flow-user-profile)
                    'developer)
      (check-equal? (poo-flow-user-profile-set-name
                     test-poo-flow-user-profile-set)
                    'workspace)
      (check-equal? (poo-flow-user-profile-set-default-profile-name
                     test-poo-flow-user-profile-set)
                    'developer)
      (check-equal? (> (length test-poo-flow-user-module-bundles) 0)
                    #t)
      (check-equal? (poo-flow-user-profile-module-bundles
                     test-poo-flow-user-profile)
                    test-poo-flow-user-module-bundles))))
