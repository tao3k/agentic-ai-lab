;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; -*- Gerbil -*-

(import (only-in :clan/poo/object .def .o .ref)
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        (only-in :core/module-system/authoring/roles
                 poo-flow-semantic-module)
        (only-in :core/profile-composition/profile-bundle
                 poo-flow-profile-export
                 poo-flow-module-profiles))
(export tool-calling ToolCallingModule)

(.def tool-calling
    (tool-request
     (.o (identity 'tool-request)
         (name 'tool-calling-request)
         (contract 'agent-requests-declared-tool)
         (policy 'tool-request-has-owner-session)))
    (tool-schema
     (.o (identity 'tool-schema)
         (name 'tool-calling-schema)
         (contract 'typed-tool-arguments)
         (policy 'tool-arguments-match-schema)))
    (tool-permission
     (.o (identity 'tool-permission)
         (name 'tool-calling-permission)
         (contract 'capability-gated-tool)
         (policy 'tool-permission-before-call)))
    (sandbox-scope
     (.o (identity 'sandbox-scope)
         (name 'tool-calling-sandbox-scope)
         (contract 'tool-runs-inside-sandbox-scope)
         (policy 'tool-scope-contained)))
    (argument-validation
     (.o (identity 'argument-validation)
         (name 'tool-calling-argument-validation)
         (contract 'validated-tool-arguments)
         (policy 'validate-arguments-before-runtime)))
    (untrusted-observation
     (.o (identity 'untrusted-observation)
         (name 'tool-calling-untrusted-observation)
         (contract 'tool-output-is-observation)
         (policy 'tool-output-cannot-authorize-policy)))
    (tool-cooldown
     (.o (identity 'tool-cooldown)
         (name 'tool-calling-cooldown)
         (contract 'rate-limited-tool-use)
         (policy 'cooldown-before-retry)))
    (result-contract
     (.o (identity 'result-contract)
         (name 'tool-calling-result-contract)
         (contract 'typed-tool-result)
         (policy 'tool-result-before-downstream-step)))
    (runtime-binding
     (.o (identity 'runtime-binding)
         (name 'tool-calling-runtime-binding)
         (contract 'runtime-language-tool-binding)
         (policy 'runtime-binding-matches-tool-contract)))
    (receipt-gate
     (.o (identity 'receipt-gate)
         (name 'tool-calling-receipt-gate)
         (contract 'tool-call-runtime-receipt)
         (policy 'runtime-receipt-matches-tool-plan)))
    (observability
     (.o (identity 'observability)
         (name 'tool-calling-observability)
         (contract 'tool-call-trace)
         (policy 'trace-covers-tool-request-call-result))))

(def ToolCallingModule
  (poo-flow-semantic-module
   (poo-flow-semantic-identity 'user-interface 'tool-calling)
   profiles:
   (poo-flow-module-profiles
    (poo-flow-profile-export 'tool-request (.ref tool-calling 'tool-request))
    (poo-flow-profile-export 'tool-schema (.ref tool-calling 'tool-schema))
    (poo-flow-profile-export 'tool-permission (.ref tool-calling 'tool-permission))
    (poo-flow-profile-export 'sandbox-scope (.ref tool-calling 'sandbox-scope))
    (poo-flow-profile-export 'argument-validation (.ref tool-calling 'argument-validation))
    (poo-flow-profile-export 'untrusted-observation (.ref tool-calling 'untrusted-observation))
    (poo-flow-profile-export 'tool-cooldown (.ref tool-calling 'tool-cooldown))
    (poo-flow-profile-export 'result-contract (.ref tool-calling 'result-contract))
    (poo-flow-profile-export 'runtime-binding (.ref tool-calling 'runtime-binding))
    (poo-flow-profile-export 'receipt-gate (.ref tool-calling 'receipt-gate))
    (poo-flow-profile-export 'observability (.ref tool-calling 'observability)))))
