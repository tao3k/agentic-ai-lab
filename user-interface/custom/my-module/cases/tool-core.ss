;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: standalone downstream tool-core case module.
;;; Invariant: this declares tool specs and policy validation receipts only;
;;; no shell, filesystem, or MCP runtime is started.

(import :agentic-ai-lab/modules/session/syntax
        :agentic-ai-lab/modules/tool-core/config
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-flag-entry
                 yuanxu-user-module-selection->alist))

(export agentic-ai-lab-custom-my-module-tool-core-case)

(def agentic-ai-lab-custom-my-module-tool-core-case
  (let* ((selection
        (car
         (agentic-ai-lab-tool-configs
           (.def (calculator-tool @ tool-spec
                                  tool-ref tool-kind actions
                                  input-schema output-schema
                                  runtime-owner handoff-operation
                                  sandbox-required? sandbox-profile-ref
                                  runtime-backend metadata)
             tool-ref: 'calculator
             tool-kind: 'custom
             actions: '(calculate)
             input-schema: '((expression . string))
             output-schema: '((result . number))
             runtime-owner: "marlin-agent-core"
             handoff-operation: 'tool/calculator
             |sandbox-required?|: #f
             sandbox-profile-ref: #f
             runtime-backend: 'marlin-tool-adapter
             metadata: '((source . user-interface)
                         (case . tool-core)))
           (.def (custom-tool-catalog @ tool-catalog catalog-ref metadata)
             catalog-ref: 'tool-core/custom
             metadata: '((source . user-interface)
                         (case . tool-core))))))
       (catalog
        (cdr
         (yuanxu-user-module-selection-flag-entry
          selection
          ':tool-catalog)))
       (calculator-grant
        (session-tool-grant grant/calculator
          calculator
          (calculate)
          (session/input)
          (agent-turn)
          ()))
       (calculator-bad-action-grant
        (session-tool-grant grant/calculator-delete
          calculator
          (delete)
          (session/input)
          (agent-turn)
          ()))
       (agent-policy
        (session-tool-policy policy/tool-core-custom-agent
          custom/session-tool-core
          (calculator-grant calculator-bad-action-grant)
          (write-workspace-file)
          deny
          ()))
       (hook-policy
        (session-hook-tool-policy policy/tool-core-custom-hook
          custom/session-tool-core
          (hook/pre-check)
          (calculator-grant)
          human-approval-on-escalation
          deny
          ()))
       (validation
        (tool-catalog-validation 'validation/custom-tool-core
          catalog
          agent-policy
          hook-policy
          '((source . user-interface)
            (case . tool-core)))))
  (list
   (yuanxu-user-module-selection->alist selection)
   (agentic-ai-lab-tool-catalog->alist catalog)
   (tool-catalog-validation-row validation))))
