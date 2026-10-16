;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: test entrypoint for root user-interface CI/CD live cases.
;;; Invariant: live execution cases are test fixtures, not user module syntax.

(import (only-in :poo-flow/modules/testing/module-system-live-case
                 poo-flow-module-system-live-case-test-suite
                 pooFlowModuleSystemLiveCaseFromModuleSelection)
        (only-in "../user-interface/custom/my-module/profiles/cicd"
                 poo-flow-custom-my-module-cicd-module)
        (only-in "../user-interface/custom/my-module/cases/cicd"
                 poo-flow-custom-my-module-cicd-case))

(export user-interface-live-cicd-case-test)

;;; The live CI/CD case is inert fixture data: it wires module selection,
;;; profile inheritance, and sandbox config without running gxpkg here.
;; : PooFlowModuleSystemLiveCase
(def poo-flow-user-interface-live-cicd-case
  (pooFlowModuleSystemLiveCaseFromModuleSelection
   'current-system-build
   poo-flow-custom-my-module-cicd-module
   poo-flow-custom-my-module-cicd-case))

;; : TestSuite
(def user-interface-live-cicd-case-test
  (poo-flow-module-system-live-case-test-suite
   poo-flow-user-interface-live-cicd-case))
