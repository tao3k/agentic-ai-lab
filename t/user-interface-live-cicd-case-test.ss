;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: test entrypoint for root user-interface CI/CD live cases.
;;; Invariant: live execution cases are test fixtures, not user module syntax.

(import (only-in :agentic-ai-lab/dev/modules/testing/module-system-live-case
                 agentic-ai-lab-module-system-live-case-test-suite
                 agenticAiLabModuleSystemLiveCaseFromModuleSelection)
        (only-in "../user-interface/custom/my-module/profiles/cicd"
                 agentic-ai-lab-custom-my-module-cicd-module)
        (only-in "../user-interface/custom/my-module/cases/cicd"
                 agentic-ai-lab-custom-my-module-cicd-case))

(export user-interface-live-cicd-case-test)

;;; The live CI/CD case is inert fixture data: it wires module selection,
;;; profile inheritance, and sandbox config without running gxpkg here.
;; : AgenticAILabModuleSystemLiveCase
(def agentic-ai-lab-user-interface-live-cicd-case
  (agenticAiLabModuleSystemLiveCaseFromModuleSelection
   'current-system-build
   agentic-ai-lab-custom-my-module-cicd-module
   agentic-ai-lab-custom-my-module-cicd-case))

;; : TestSuite
(def user-interface-live-cicd-case-test
  (agentic-ai-lab-module-system-live-case-test-suite
   agentic-ai-lab-user-interface-live-cicd-case))
