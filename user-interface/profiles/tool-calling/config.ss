;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o))
(def Config
  (.o (tool-request
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
         (policy 'trace-covers-tool-request-call-result)))))
