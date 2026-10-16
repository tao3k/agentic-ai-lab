;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream AgentParam contract case.
;;; Invariant: this binds session topology to effective policy validation;
;;; provider, tool, memory, stream, and sandbox runtime stay behind Marlin.

(import :poo-flow/modules/session/syntax
        :poo-flow/modules/ai-agentic-context/features/memory/config
        (only-in :core/module-system/selection/objects
                 poo-flow-user-module-selection-flag-entry))

(export poo-flow-custom-my-module-session-agent-param-case)

(def poo-flow-custom-my-module-session-agent-param-case
  (poo-flow-session-cases
  (session-case custom-session-agent-param-case
    (metadata (source . user-interface)
              (case . session-agent-param))
    (objects
     (read-grant
            (session-tool-grant grant/agent-param-read
              read-workspace-file
              (read)
              (project-workspace)
              (agent-turn hook/pre-check)
              ()))
           (build-grant
            (session-tool-grant grant/agent-param-build
              run-build-command
              (run)
              (project-workspace build-cache)
              (agent-turn)
              ()))
           (build-node
            (session-agent-node agent/build
              (project custom/project)
              (root custom/root-session)
              (parent custom/root-session)
              (system custom/build-system)
              (input custom/root-session)
              (output custom/build-session)
              (peers custom/audit-session)
              (channels channel/build-audit)
              (model policy/build-agent-model)
              (prompt policy/build-agent-prompt)
              (tools policy/build-agent-tools)
              (hook-tools policy/pre-check-hook-tools)
              (resources policy/build-agent-resources)
              (durable durable/custom-project)
              (tool-refs read-workspace-file run-build-command)
              (memory session/memory)
              (sandbox agent/nono)
              (role builder)
              (result poo-flow.session.agent.build-result.v1)
              (metadata (source . user-interface)
                        (case . session-agent-param))))
           (model-policy
            (session-model-policy policy/build-agent-model
              custom/build-session
              marlin/provider
              marlin/model/build-review
              (tool-calling structured-output)
              budget/build-agent
              ()))
           (prompt-policy
            (session-prompt-policy policy/build-agent-prompt
              custom/build-session
              custom/build-system
              (system-instruction build-contract)
              parent-summary-only
              ()))
           (isolation-policy
            (session-isolation-policy policy/build-agent-isolation
              custom/build-session
              child-isolated
              denied
              denied
              declared-channel-only
              ()))
           (sandbox-policy
            (session-sandbox-policy policy/build-agent-sandbox
              custom/build-session
              agent/nono
              parent-profile
              isolated-filesystem
              ()))
           (context-policy
            (session-context-policy policy/build-agent-context
              custom/build-session
              parent-summary
              (custom/root-session)
              ()))
           (history-policy
            (session-history-policy policy/build-agent-history
              custom/build-session
              bounded
              (record/last-failure)
              ()))
           (communication-policy
            (session-communication-policy policy/build-agent-communication
              custom/build-session
              (channel/build-root)
              (custom/root-session)
              ()))
           (build-root-communication
            (session-communication custom/project
              (relation child-parent)
              (roots custom/root-session custom/root-session)
              (sessions custom/build-session custom/root-session)
              (agents agent/build agent/root)
              (channel channel/build-root)
              (message result
                       ((summary . "build AgentParam result ready")
                        (receipt-ref . receipt/custom-agent-param-build)))
              (delivery receipt-only)
              (metadata (source . user-interface)
                        (case . session-agent-param)
                        (communication-ledger-ref
                         . runtime/custom-communication-ledger)
                        (durable-policy-ref . durable/custom-project))))
           (sharing-policy
            (session-resource-sharing-policy policy/build-agent-resources
              custom/build-session
              ((project-workspace
                (access . read)
                (accounting . custom/root-session))
               (build-cache
                (access . read-write)
                (accounting . custom/build-session)))
              deny
              ()))
           (resource-policy
            (session-resource-policy policy/build-agent-capabilities
              custom/build-session
              (budget/build-agent)
              (project-workspace build-cache)
              custom/build-session
              ()))
           (agent-tool-policy
            (session-tool-policy policy/build-agent-tools
              custom/build-session
              (read-grant build-grant)
              (write-workspace-file)
              deny
              ()))
           (hook-tool-policy
            (session-hook-tool-policy policy/pre-check-hook-tools
              custom/build-session
              (hook/pre-check)
              (read-grant)
              human-approval-on-escalation
              deny
              ()))
           (memory-selection
            (car
             (poo-flow-memory-configs
               (.def (agent-param-memory-store @ memory-store-spec
                                                store-ref store-kind namespace
                                                scopes recall-policies
                                                commit-policies
                                                runtime-owner
                                                handoff-operation durable?
                                                runtime-backend metadata)
                 store-ref: 'session/memory
                 store-kind: 'durable-project
                 namespace: 'project
                 scopes: '(current-session parent-summary project)
                 recall-policies: '(semantic-search exact-key read-summary)
                 commit-policies: '(append review-only)
                 runtime-owner: "marlin-agent-core"
                 handoff-operation: 'memory/session-agent-param
                 |durable?|: #t
                 runtime-backend: 'marlin-memory-adapter
                 metadata: '((source . user-interface)
                             (case . session-agent-param)))
               (.def (agent-param-memory-catalog @ memory-catalog
                                                  catalog-ref metadata)
                 catalog-ref: 'memory-core/custom-agent-param
                 metadata: '((source . user-interface)
                             (case . session-agent-param))))))
           (memory-catalog
            (cdr
             (poo-flow-user-module-selection-flag-entry
              memory-selection
              ':memory-catalog)))
           (memory-intent
            (session-memory-intent intent/custom-agent-param-memory
              (store session/memory)
              (scope project)
              (recall current-ticket build-summary)
              (commit append)
              (metadata (source . user-interface)
                        (case . session-agent-param))))
           (memory-catalog-validation-row
            (memory-catalog-validation-row
             (memory-catalog-validation
              validation/custom-agent-param-memory-catalog
              memory-catalog
              (memory-intent)
              (metadata (source . user-interface)
                        (case . session-agent-param)))))
           (validation
            (session-policy-validation
             validation/custom-agent-param
             custom/build-session
             model-policy
             prompt-policy
             isolation-policy
             sandbox-policy
             context-policy
             history-policy
             communication-policy
             sharing-policy
             resource-policy
             agent-tool-policy
             hook-tool-policy
             (custom/root-session)
             (record/last-failure)
             (channel/build-root)
             (project-workspace build-cache)
             ((session-policy-tool-attempt attempt/custom-agent-param-build
                agent-turn
                run-build-command
                run
                build-cache
                agent/build))
             ((session-policy-tool-attempt attempt/custom-agent-param-hook-read
                hook/pre-check
                read-workspace-file
                read
                project-workspace
                hook/pre-check))
             (list
              (cons 'source 'user-interface)
              (cons 'case 'session-agent-param)
              (cons 'memory-catalog-validation
                    memory-catalog-validation-row)
              (cons 'communication-receipts
                    (list build-root-communication)))))
           (contract
            (session-agent-param-contract agent-param/custom-build
                                          build-node
                                          validation
                                          marlin/provider
                                          streaming-disabled
                                          events-receipt-only
                                          '((source . user-interface)
                                            (case . session-agent-param)))))
    (rows (session-agent-param-row contract)))))
