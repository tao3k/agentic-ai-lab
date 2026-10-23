;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product module routing is an input to Core selection admission.
(import (only-in :clan/poo/object .o)
        (only-in :yuanxu/module-system/selection/objects current-module-selection-policy)
        (rename-in (only-in :yuanxu/module-system/selection/contract
                            yuanxu-use-module-contract-validation
                            yuanxu-require-use-module-contract!
                            yuanxu-modules-system-use-module/contract)
                   (yuanxu-use-module-contract-validation core-validation)
                   (yuanxu-require-use-module-contract! core-admit!)
                   (yuanxu-modules-system-use-module/contract core-use-module)))
(export AgenticAILabSelectionPolicy agentic-ai-lab-product-selection-validation
        agentic-ai-lab-product-selection-admit! agentic-ai-lab-product-use-module)
(def AgenticAILabSelectionPolicy
  (.o groups:
      (.o funflow: 'flow loop-engine: 'flow workflow: 'flow custom-task: 'flow text: 'flow
          session: 'session tool-core: 'session ai-agentic-context: 'agentic model-core: 'session
          governor: 'loop sandbox-core: 'sandbox agent-sandbox: 'sandbox nono-sandbox: 'sandbox
          docker: 'sandbox cubeSandbox: 'sandbox docker-sandbox: 'sandbox)))
(def (agentic-ai-lab-product-selection-validation module selections)
  (parameterize ((current-module-selection-policy AgenticAILabSelectionPolicy))
    (core-validation module selections)))
(def (agentic-ai-lab-product-selection-admit! module selections)
  (parameterize ((current-module-selection-policy AgenticAILabSelectionPolicy))
    (core-admit! module selections)))
(def (agentic-ai-lab-product-use-module module flags)
  (parameterize ((current-module-selection-policy AgenticAILabSelectionPolicy))
    (core-use-module module flags)))
