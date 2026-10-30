;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native AgentParam contracts derived from session topology.
;;; Invariant: AgentParam contracts are report-only policy/topology bindings;
;;; Scheme never opens providers, tools, memory stores, streams, or sandboxes.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/session/config)

(export session-agent-param-contract-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> PooSessionAgentNode)
(def (make-agent-param-test-node)
  (agentic-ai-lab-session-agent-node
   'agent/build
   'project/agent-param
   'session/root
   'session/root
   'session/build-system
   'session/root
   'session/build
   '(session/audit)
   '(channel/build-audit)
   'policy/build-model
   'policy/build-prompt
   'policy/build-tools
   'policy/build-hook-tools
   'policy/build-resources
   'durable/build
   '(read-workspace-file run-build-command)
   '(memory/build)
   'agent/nono
   'builder
   'agentic-ai-lab.session.agent.build-result.v1))

;; : (-> PooSessionPolicyValidationReceipt)
(def (make-agent-param-test-validation)
  (let* ((read-grant
          (agentic-ai-lab-session-tool-grant
           'grant/read
           'read-workspace-file
           '(read)
           '(project-workspace)
           '(agent-turn hook/pre-check)))
         (build-grant
          (agentic-ai-lab-session-tool-grant
           'grant/build
           'run-build-command
           '(run)
           '(project-workspace build-cache)
           '(agent-turn)))
         (model-policy
          (agentic-ai-lab-session-model-policy
           'policy/build-model
           'session/build
           'marlin/provider
           'marlin/model/build-review
           '(tool-calling structured-output)
           'budget/build))
         (prompt-policy
          (agentic-ai-lab-session-prompt-policy
           'policy/build-prompt
           'session/build
           'session/build-system
           '(system build-contract)
           'parent-summary-only))
         (isolation-policy
          (agentic-ai-lab-session-isolation-policy
           'policy/build-isolation
           'session/build
           'child-isolated
           'denied
           'denied
           'declared-channel-only))
         (sandbox-policy
          (agentic-ai-lab-session-sandbox-policy
           'policy/build-sandbox
           'session/build
           'agent/nono
           'parent-profile
           'isolated-filesystem))
         (context-policy
          (agentic-ai-lab-session-context-policy
           'policy/build-context
           'session/build
           'parent-summary
           '(session/root)))
         (history-policy
          (agentic-ai-lab-session-history-policy
           'policy/build-history
           'session/build
           'bounded
           '(record/last-failure)))
         (communication-policy
          (agentic-ai-lab-session-communication-policy
           'policy/build-communication
           'session/build
           '(channel/build-root)
           '(session/root)))
         (build-root-communication
          (agentic-ai-lab-session-communication-receipt
           'project/agent-param
           'child-parent
           'session/root
           'session/root
           'session/build
           'session/root
           'agent/build
           'agent/root
           'channel/build-root
           'result
           '((summary . "build result ready"))
           'receipt-only))
         (sharing-policy
          (agentic-ai-lab-session-resource-sharing-policy
           'policy/build-sharing
           'session/build
           '((project-workspace
              (access . read)
              (accounting . session/root))
             (build-cache
              (access . read-write)
              (accounting . session/build)))
           'deny))
         (resource-policy
          (agentic-ai-lab-session-resource-policy
           'policy/build-resource
           'session/build
           '(budget/build)
           '(project-workspace build-cache)
           'session/build))
         (agent-tool-policy
          (agentic-ai-lab-session-tool-permission-policy
           'policy/build-tools
           'session/build
           (list read-grant build-grant)
           '(write-workspace-file)
           'deny))
         (hook-tool-policy
          (agentic-ai-lab-session-hook-tool-permission-policy
           'policy/build-hook-tools
           'session/build
           '(hook/pre-check)
           (list read-grant)
           'human-approval-on-escalation
           'deny)))
    (agentic-ai-lab-session-policy-validation-receipt
     'validation/build-agent-param
     'session/build
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
     '(session/root)
     '(record/last-failure)
     '(channel/build-root)
     '(project-workspace build-cache)
     (list
      (agentic-ai-lab-session-policy-tool-attempt
       'attempt/build
       'agent-turn
       'run-build-command
       'run
       'build-cache
       'agent/build))
     (list
      (agentic-ai-lab-session-policy-tool-attempt
       'attempt/hook-read
       'hook/pre-check
       'read-workspace-file
       'read
       'project-workspace
       'hook/pre-check))
     (list
      (cons 'communication-receipts
            (list build-root-communication))))))

;; : TestSuite
(def session-agent-param-contract-test
  (test-suite "agentic-ai-lab session AgentParam contract"
    (yuanxu-test-case "derives AgentParam contract from topology and policy validation"
      (let* ((node (make-agent-param-test-node))
             (validation (make-agent-param-test-validation))
             (contract
              (agentic-ai-lab-session-agent-param-contract
               'agent-param/build
               node
               validation
               'marlin/provider
               'streaming-disabled
               'events-receipt-only
               '((case . unit))))
             (row (agentic-ai-lab-session-agent-param-contract->alist contract))
             (rows
              (agentic-ai-lab-session-agent-param-contracts->alists
               (list contract))))
        (check-equal? (agentic-ai-lab-session-agent-param-contract? contract)
                      #t)
        (check-equal? (agentic-ai-lab-session-agent-param-contract-id contract)
                      'agent-param/build)
        (check-equal? (agentic-ai-lab-session-agent-param-contract-agent-id
                       contract)
                      'agent/build)
        (check-equal? (agentic-ai-lab-session-agent-param-contract-provider-ref
                       contract)
                      'marlin/provider)
        (check-equal?
         (agentic-ai-lab-session-agent-param-contract-effective-model-ref
          contract)
         'marlin/model/build-review)
        (check-equal?
         (agentic-ai-lab-session-agent-param-contract-validation-valid? contract)
         #t)
        (check-equal? (.ref contract 'agent-system-session-ref)
                      'session/build-system)
        (check-equal? (test-ref row 'effective-isolation-mode)
                      'child-isolated)
        (check-equal? (test-ref row 'effective-sandbox-profile-ref)
                      'agent/nono)
        (check-equal? (.ref contract 'tool-refs)
                      '(read-workspace-file run-build-command))
        (check-equal? (.ref contract 'memory-refs)
                      '(memory/build))
        (check-equal? (.ref contract 'durable-policy-ref)
                      'durable/build)
        (check-equal?
         (length (test-ref row 'allowed-communication-receipts))
         1)
        (check-equal?
         (test-ref (car (test-ref row 'allowed-communication-receipts))
                   'target-session-id)
         'session/root)
        (check-equal? (test-ref row 'denied-communication-receipts)
                      '())
        (check-equal? (.ref contract 'runtime-executed) #f)
        (check-equal? (test-ref row 'validation-id)
                      'validation/build-agent-param)
        (check-equal? (test-ref row 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (length rows) 1)
        (check-equal? (test-ref (car rows) 'contract-id)
                      'agent-param/build)))))
