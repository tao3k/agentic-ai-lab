;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream session policy case.
;;; Invariant: declarations describe permissions only and never execute tools,
;;; hooks, providers, or sandboxes.

(import :poo-flow/modules/session/syntax
        :poo-flow/modules/tool-core/config
        :poo-flow/modules/ai-agentic-context/features/memory/config
        (only-in :core/module-system/selection/objects
                 poo-flow-user-module-selection-flag-entry))

(export poo-flow-custom-my-module-session-policy-case)

(def poo-flow-custom-my-module-session-policy-case
  (poo-flow-session-cases
  (session-case custom-session-policy-case
    (metadata (source . user-interface)
              (case . session-policy))
    (objects
     (custom-durable-default
          (poo-flow-durable-policy
           'durable/custom-project
           'custom/session-root
           '((journal-owner . runtime/fact-log)
             (checkpoint-store . runtime/checkpoint-store)
             (resume-identity . session-id)
             (repair-mode . fail-closed)
             (action-classes . (replayable idempotent compensatable manual))
             (metadata . ((project . custom)
                          (owner . marlin-agent-core))))))
         (custom-session-read-grant
          (session-tool-grant grant/project-read
            read-workspace-file
            (read)
            (project-workspace)
            (agent-turn hook/pre-check)
            ((scope . session)
             (owner . root-agent))))
         (custom-session-build-grant
          (session-tool-grant grant/project-build
            run-build-command
            (run)
            (project-workspace build-cache)
            (agent-turn)
            ((scope . child-session)
             (owner . build-agent))))
         (custom-session-main-agent-tool-policy
          (session-tool-policy policy/main-agent-tools
            custom/session-root
            (custom-session-read-grant)
            (write-workspace-file run-build-command)
            deny
            ((principal . main-agent)
             (sharing . explicit-grants-only))))
         (custom-session-build-agent-tool-policy
          (session-tool-policy policy/build-agent-tools
            custom/session-build-child
            (custom-session-read-grant custom-session-build-grant)
            (write-workspace-file)
            deny
            ((principal . build-agent)
             (sharing . explicit-grants-only))))
         (custom-session-hook-tool-policy
          (session-hook-tool-policy policy/pre-check-hook-tools
            custom/session-root
            (hook/pre-check)
            (custom-session-read-grant)
            human-approval-on-escalation
            deny
            ((principal . hook/pre-check)
             (inherits-agent-tools? . #f))))
         (custom-session-tool-selection
          (car
           (poo-flow-tool-configs
             (.def (session-policy-read-tool @ tool-spec
                                              tool-ref tool-kind actions
                                              input-schema output-schema
                                              runtime-owner
                                              handoff-operation
                                              sandbox-required?
                                              sandbox-profile-ref
                                              runtime-backend metadata)
               tool-ref: 'read-workspace-file
               tool-kind: 'builtin-filesystem
               actions: '(read)
               input-schema: '((path . string) (mode . read-only))
               output-schema: '((content-ref . artifact)
                                (summary . string))
               runtime-owner: "marlin-agent-core"
               handoff-operation: 'tool/read-workspace-file
               |sandbox-required?|: #t
               sandbox-profile-ref: 'agent/nono
               runtime-backend: 'marlin-tool-adapter
               metadata: '((builtin . #t)
                           (source . user-interface)
                           (case . session-policy)))
             (.def (session-policy-build-tool @ tool-spec
                                               tool-ref tool-kind actions
                                               input-schema output-schema
                                               runtime-owner
                                               handoff-operation
                                               sandbox-required?
                                               sandbox-profile-ref
                                               runtime-backend metadata)
               tool-ref: 'run-build-command
               tool-kind: 'builtin-command
               actions: '(run)
               input-schema: '((argv . list) (cwd . string))
               output-schema: '((exit-status . integer)
                                (stdout-ref . artifact)
                                (stderr-ref . artifact))
               runtime-owner: "marlin-agent-core"
               handoff-operation: 'tool/run-build-command
               |sandbox-required?|: #t
               sandbox-profile-ref: 'agent/nono
               runtime-backend: 'marlin-tool-adapter
               metadata: '((source . user-interface)
                           (case . session-policy)))
             (.def (custom-session-tool-catalog @ tool-catalog
                                                 catalog-ref metadata)
               catalog-ref: 'tool-core/custom-session-policy
               metadata: '((source . user-interface)
                           (case . session-policy))))))
         (custom-session-tool-catalog
          (cdr
           (poo-flow-user-module-selection-flag-entry
            custom-session-tool-selection
            ':tool-catalog)))
         (custom-session-tool-catalog-validation-row
          (tool-catalog-validation-row
           (tool-catalog-validation 'validation/custom-session-tool-catalog
             custom-session-tool-catalog
             custom-session-build-agent-tool-policy
             custom-session-hook-tool-policy
             '((source . user-interface)
               (case . session-policy)))))
         (custom-session-memory-selection
          (car
           (poo-flow-memory-configs
             (.def (session-policy-memory-store @ memory-store-spec
                                                 store-ref store-kind
                                                 namespace scopes
                                                 recall-policies
                                                 commit-policies
                                                 runtime-owner
                                                 handoff-operation durable?
                                                 runtime-backend metadata)
               store-ref: 'memory/project
               store-kind: 'durable-project
               namespace: 'project
               scopes: '(current-session parent-summary project)
               recall-policies: '(semantic-search exact-key read-summary)
               commit-policies: '(append review-only)
               runtime-owner: "marlin-agent-core"
               handoff-operation: 'memory/project
               |durable?|: #t
               runtime-backend: 'marlin-memory-adapter
               metadata: '((source . user-interface)
                           (case . session-policy)))
             (.def (custom-session-memory-catalog @ memory-catalog
                                                   catalog-ref metadata)
               catalog-ref: 'memory-core/custom-session-policy
               metadata: '((source . user-interface)
                           (case . session-policy))))))
         (custom-session-memory-catalog
          (cdr
           (poo-flow-user-module-selection-flag-entry
            custom-session-memory-selection
            ':memory-catalog)))
         (custom-session-memory-intent
          (session-memory-intent intent/custom-project-memory
            (store memory/project)
            (scope project)
            (recall current-ticket design-notes)
            (commit append)
            (metadata (source . user-interface)
                      (case . session-policy))))
         (custom-session-memory-catalog-validation-row
          (memory-catalog-validation-row
           (memory-catalog-validation validation/custom-session-memory-catalog
             custom-session-memory-catalog
             (custom-session-memory-intent)
             (metadata (source . user-interface)
                       (case . session-policy)))))
         (custom-session-model-policy
          (session-model-policy policy/build-agent-model
            custom/session-build-child
            marlin/provider
            marlin/model/build-review
            (tool-calling structured-output)
            budget/build-agent
            ((principal . build-agent))))
         (custom-session-prompt-policy
          (session-prompt-policy policy/build-agent-prompt
            custom/session-build-child
            custom/session-build-system
            (system-instruction build-contract)
            parent-summary-only
            ((principal . build-agent)
             (sibling-context . denied))))
         (custom-session-isolation-policy
          (session-isolation-policy policy/build-agent-isolation
            custom/session-build-child
            child-isolated
            denied
            denied
            declared-channel-only
            ((principal . build-agent)
             (sibling-context . denied))))
         (custom-session-context-policy
          (session-context-policy policy/build-agent-context
            custom/session-build-child
            parent-summary
            (custom/session-root)
            ((sibling-context . denied))))
         (custom-session-history-policy
          (session-history-policy policy/build-agent-history
            custom/session-build-child
            bounded
            (record/last-failure)
            ((history . bounded))))
         (custom-session-communication-policy
          (session-communication-policy policy/build-agent-communication
            custom/session-build-child
            (channel/build-root)
            (custom/session-root)
            ((peer-communication . declared-channel-only))))
         (custom-session-build-root-channel
          (session-communication-channel custom/project
            channel/build-root
            (relation child-parent)
            (sessions custom/session-build-child custom/session-root)
            (agents agent/build agent/root)
            (messages result)
            (delivery receipt-only)
            (metadata (source . user-interface)
                      (case . session-policy)
                      (communication-ledger-ref
                       . runtime/custom-communication-ledger)
                      (durable-policy-ref . durable/custom-project))))
         (custom-session-build-audit-channel
          (session-communication-channel custom/project
            channel/build-audit
            (relation sibling)
            (sessions custom/session-build-child custom/audit-session)
            (agents agent/build agent/audit)
            (messages artifact)
            (delivery declared-channel-only)
            (metadata (source . user-interface)
                      (case . session-policy)
                      (communication-ledger-ref
                       . runtime/custom-communication-ledger)
                      (durable-policy-ref . durable/custom-project))))
         (custom-session-build-root-communication
          (session-communication custom/project
            (relation child-parent)
            (roots custom/session-root custom/session-root)
            (sessions custom/session-build-child custom/session-root)
            (agents agent/build agent/root)
            (channel channel/build-root)
            (message result
                     ((summary . "build result ready")
                      (receipt-ref . receipt/custom-build-result)))
            (delivery receipt-only)
            (metadata (source . user-interface)
                      (case . session-policy)
                      (communication-ledger-ref
                       . runtime/custom-communication-ledger)
                      (durable-policy-ref . durable/custom-project))))
         (custom-session-build-audit-communication
          (session-communication custom/project
            (relation sibling)
            (roots custom/session-root custom/session-root)
            (sessions custom/session-build-child custom/audit-session)
            (agents agent/build agent/audit)
            (channel channel/build-audit)
            (message artifact
                     ((artifact . custom-build-report)
                      (visibility . declared-channel)))
            (delivery declared-channel-only)
            (metadata (source . user-interface)
                      (case . session-policy)
                      (communication-ledger-ref
                       . runtime/custom-communication-ledger)
                      (durable-policy-ref . durable/custom-project))))
         (custom-session-sandbox-policy
          (session-sandbox-policy policy/build-agent-sandbox
            custom/session-build-child
            sandbox/nono-build
            parent-profile
            isolated-filesystem
            ((sandbox . nono)
             (filesystem . project-workspace))))
         (custom-session-sharing-policy
          (session-sharing-policy policy/build-agent-sharing
            custom/session-build-child
            (memory/project)
            (artifact/build-log)
            (tool-result/test-summary)
            ("build/" "reports/")
            ((sharing . explicit-refs-only))))
         (custom-session-resource-policy
          (session-resource-sharing-policy policy/build-agent-resources
            custom/session-build-child
            ((project-workspace
              (access . read)
              (accounting . root-session))
             (build-cache
              (access . read-write)
              (accounting . child-session)))
            deny
            ((sharing . session-id-scoped))))
         (custom-session-capability-policy
          (session-resource-policy policy/build-agent-capabilities
            custom/session-build-child
            (budget/build-agent)
            (project-workspace build-cache)
            custom/session-build-child
            ((resource . accounted))))
         (custom-session-agent-execution-policy
          (session-policy-with-durable
           (session-agent-execution-policy policy/build-agent-execution
             agent/build
             custom/session-build-child
             policy/build-agent-model
             policy/build-agent-prompt
             policy/build-agent-tools
             policy/pre-check-hook-tools
             policy/build-agent-context
             policy/build-agent-resources
             ((parent-session . custom/session-root)
              (communication . declared-channel-only)))
           custom-durable-default))
         (custom-session-validation
          (session-policy-validation validation/custom-build
            custom/session-build-child
            custom-session-model-policy
            custom-session-prompt-policy
            custom-session-isolation-policy
            custom-session-sandbox-policy
            custom-session-context-policy
            custom-session-history-policy
            custom-session-communication-policy
            custom-session-resource-policy
            custom-session-capability-policy
            custom-session-build-agent-tool-policy
            custom-session-hook-tool-policy
            (custom/session-root custom/audit-session)
            (record/last-failure record/full-transcript)
            (channel/build-root channel/build-audit)
            (project-workspace build-cache network-egress)
            ((session-policy-tool-attempt attempt/custom-build
               agent-turn
               run-build-command
               run
               build-cache
               agent/build))
            ((session-policy-tool-attempt attempt/custom-hook-build
               hook/pre-check
               run-build-command
               run
               build-cache
               hook/pre-check))
            (list
             (cons 'source 'user-interface)
             (cons 'case 'session-policy)
             (cons 'tool-catalog-validation
                   custom-session-tool-catalog-validation-row)
             (cons 'memory-catalog-validation
                   custom-session-memory-catalog-validation-row)
             (cons 'communication-channel-receipts
                   (list custom-session-build-root-channel
                         custom-session-build-audit-channel))
             (cons 'communication-receipts
                   (list custom-session-build-root-communication
                         custom-session-build-audit-communication))
             (cons 'sibling-session-refs '(custom/audit-session))))))
    (rows (poo-flow-durable-policy-receipt->alist
           (poo-flow-durable-policy->receipt
            custom-durable-default
            '((project-id . custom/project)
              (root-session-id . custom/session-root)
              (session-id . custom/session-build-child)
              (parent-session-id . custom/session-root)
              (loop-run-id . custom/loop-run))))
          (session-policy-row custom-session-main-agent-tool-policy)
          (session-policy-row custom-session-build-agent-tool-policy)
          (session-policy-row custom-session-hook-tool-policy)
          (poo-flow-tool-catalog->alist custom-session-tool-catalog)
          custom-session-tool-catalog-validation-row
          (poo-flow-memory-catalog->alist custom-session-memory-catalog)
          custom-session-memory-catalog-validation-row
          (session-policy-row custom-session-model-policy)
          (session-policy-row custom-session-prompt-policy)
          (session-policy-row custom-session-isolation-policy)
          (session-policy-row custom-session-context-policy)
          (session-policy-row custom-session-history-policy)
          (session-policy-row custom-session-communication-policy)
          (session-communication-channel-row custom-session-build-root-channel)
          (session-communication-channel-row custom-session-build-audit-channel)
          (session-communication-row custom-session-build-root-communication)
          (session-communication-row custom-session-build-audit-communication)
          (session-policy-row custom-session-sandbox-policy)
          (session-policy-row custom-session-sharing-policy)
          (session-policy-row custom-session-resource-policy)
          (session-policy-row custom-session-capability-policy)
          (session-policy-row custom-session-agent-execution-policy)
          (session-policy-validation-row custom-session-validation)))))
