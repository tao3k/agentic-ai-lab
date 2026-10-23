;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: AgentParam contract performance gate.
;;; Invariant: batch AgentParam projection stays bounded and report-only.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        :poo-flow/modules/session/config
        :poo-flow/modules/ai-agentic-context/features/memory/config)

(export session-agent-param-contract-performance-test)

;; : String
(def session-agent-param-contract-fixture-path
  "t/scenarios/performance/session-agent-param-contract/benchmark.ss")

;; : Alist
(def session-agent-param-contract-fixture
  (call-with-input-file session-agent-param-contract-fixture-path read))

;; : (-> Alist Symbol MaybeValue)
(def (agent-param-performance-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (agent-param-performance-display-receipt receipt)
  (display "[poo-flow-benchmark] session-agent-param-contract ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> PooSessionAgentNode)
(def (agent-param-performance-node)
  (poo-flow-session-agent-node
   'agent/perf
   'project/agent-param
   'session/root
   'session/root
   'session/perf-system
   'session/root
   'session/perf
   '(session/audit)
   '(channel/perf-audit)
   'policy/perf-model
   'policy/perf-prompt
   'policy/perf-tools
   'policy/perf-hooks
   'policy/perf-resources
   'durable/perf
   '(read-workspace-file run-build-command)
   '(memory/perf)
   'agent/nono
   'builder
   'poo-flow.session.agent.perf-result.v1))

;; : (-> PooSessionPolicyValidationReceipt)
(def (agent-param-performance-validation)
  (let* ((read-grant
          (poo-flow-session-tool-grant
           'grant/read
           'read-workspace-file
           '(read)
           '(project-workspace)
           '(agent-turn hook/pre-check)))
         (model-policy
          (poo-flow-session-model-policy
           'policy/perf-model
           'session/perf
           'marlin/provider
           'marlin/model/perf
           '(tool-calling)
           'budget/perf))
         (prompt-policy
          (poo-flow-session-prompt-policy
           'policy/perf-prompt
           'session/perf
           'session/perf-system
           '(system)
           'parent-summary-only))
         (isolation-policy
          (poo-flow-session-isolation-policy
           'policy/perf-isolation
           'session/perf
           'child-isolated
           'denied
           'denied
           'declared-channel-only))
         (sandbox-policy
          (poo-flow-session-sandbox-policy
           'policy/perf-sandbox
           'session/perf
           'agent/nono
           'parent-profile
           'isolated-filesystem))
         (context-policy
          (poo-flow-session-context-policy
           'policy/perf-context
           'session/perf
           'parent-summary
           '(session/root)))
         (history-policy
          (poo-flow-session-history-policy
           'policy/perf-history
           'session/perf
           'bounded
           '(record/last-failure)))
         (communication-policy
          (poo-flow-session-communication-policy
           'policy/perf-communication
           'session/perf
           '(channel/perf-root)
           '(session/root)))
         (root-communication
          (poo-flow-session-communication-receipt
           'project/agent-param
           'child-parent
           'session/root
           'session/root
           'session/perf
           'session/root
           'agent/perf
           'agent/root
           'channel/perf-root
           'result
           '((summary . "perf result ready"))
           'receipt-only))
         (sharing-policy
          (poo-flow-session-resource-sharing-policy
           'policy/perf-sharing
           'session/perf
           '((project-workspace
              (access . read)
              (accounting . session/root)))
           'deny))
         (resource-policy
          (poo-flow-session-resource-policy
           'policy/perf-resource
           'session/perf
           '(budget/perf)
           '(project-workspace)
           'session/perf))
         (agent-tool-policy
          (poo-flow-session-tool-permission-policy
           'policy/perf-tools
           'session/perf
           (list read-grant)
           '(write-workspace-file)
           'deny))
         (hook-tool-policy
          (poo-flow-session-hook-tool-permission-policy
           'policy/perf-hooks
           'session/perf
           '(hook/pre-check)
           (list read-grant)
           'human-approval-on-escalation
           'deny))
         (memory-store
          (poo-flow-memory-store-spec
           'memory/perf
           'durable-project
           'project
           '(current-session project)
           '(semantic-search)
           '(append review-only)
           "marlin-agent-core"
           'memory/perf
           #t
           'marlin-memory-adapter))
         (memory-catalog
          (poo-flow-memory-catalog
           'memory-core/perf-agent-param
           (list memory-store)))
         (memory-intent
          (poo-flow-session-memory-intent
           'intent/perf-agent-param-memory
           'memory/perf
           'project
           '(current-ticket)
           'append))
         (memory-catalog-validation-row
          (poo-flow-memory-policy-catalog-validation-receipt->alist
           (poo-flow-memory-policy-catalog-validation-receipt
            'validation/perf-agent-param-memory-catalog
            memory-catalog
            (list memory-intent)))))
    (poo-flow-session-policy-validation-receipt
     'validation/perf-agent-param
     'session/perf
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
     '(channel/perf-root)
     '(project-workspace)
     (list
      (poo-flow-session-policy-tool-attempt
       'attempt/perf-read
       'agent-turn
       'read-workspace-file
       'read
       'project-workspace
       'agent/perf))
     (list
      (poo-flow-session-policy-tool-attempt
       'attempt/perf-hook-read
       'hook/pre-check
       'read-workspace-file
       'read
       'project-workspace
       'hook/pre-check))
     (list
      (cons 'memory-catalog-validation
            memory-catalog-validation-row)
      (cons 'communication-receipts
            (list root-communication))))))

;; : (-> Integer Symbol)
(def (agent-param-performance-contract-id index)
  (string->symbol
   (string-append "agent-param/perf-" (number->string index))))

;; : (-> PooSessionAgentNode PooSessionPolicyValidationReceipt Integer PooSessionAgentParamContract)
(def (agent-param-performance-contract node validation index)
  (poo-flow-session-agent-param-contract
   (agent-param-performance-contract-id index)
   node
   validation
   'marlin/provider
   'streaming-disabled
   'events-receipt-only))

;; : (-> PooSessionAgentNode PooSessionPolicyValidationReceipt Integer Alist)
(def (agent-param-performance-summary node validation count)
  (let* ((contracts
          (poo-flow-performance-build-list
           count
           (lambda (index)
             (agent-param-performance-contract node validation index))))
         (rows
          (poo-flow-session-agent-param-contracts->alists contracts)))
    (map (lambda (entry)
           (cons (car entry) ((cdr entry))))
         (list
          (cons 'contract-count
                (lambda () (length rows)))
          (cons 'first-agent
                (lambda ()
                  (agent-param-performance-ref (car rows) 'agent-id)))
          (cons 'last-contract
                (lambda ()
                  (agent-param-performance-ref
                   (list-ref rows (- count 1))
                   'contract-id)))
          (cons 'runtime-executed
                (lambda ()
                  (agent-param-performance-ref
                   (car rows)
                   'runtime-executed)))
          (cons 'memory-catalog-valid?
                (lambda ()
                  (agent-param-performance-ref
                   (car rows)
                   'memory-catalog-valid?)))
          (cons 'effective-isolation-mode
                (lambda ()
                  (agent-param-performance-ref
                   (car rows)
                   'effective-isolation-mode)))
          (cons 'effective-sandbox-profile-ref
                (lambda ()
                  (agent-param-performance-ref
                   (car rows)
                   'effective-sandbox-profile-ref)))
          (cons 'allowed-communication-receipt-count
                (lambda ()
                  (length
                   (agent-param-performance-ref
                    (car rows)
                    'allowed-communication-receipts))))
          (cons 'denied-communication-receipt-count
                (lambda ()
                  (length
                   (agent-param-performance-ref
                    (car rows)
                    'denied-communication-receipts))))
          (cons 'memory-catalog-resolved-store-count
                (lambda ()
                  (length
                   (agent-param-performance-ref
                    (car rows)
                    'memory-catalog-resolved-store-refs))))))))

;; : TestSuite
(def session-agent-param-contract-performance-test
  (test-suite "session AgentParam contract performance"
    (yuanxu-test-case "keeps AgentParam contract batch projection inside benchmark contract"
      (let* ((contract-count 200)
             (node (agent-param-performance-node))
             (validation (agent-param-performance-validation))
             (summary
              (agent-param-performance-summary node validation contract-count))
             (receipt
              (benchmark-run
               session-agent-param-contract-fixture
               (lambda ()
                 (agent-param-performance-summary
                  node
                  validation
                  contract-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass? session-agent-param-contract-fixture)
         #t)
        (check-equal? (agent-param-performance-ref summary 'contract-count)
                      contract-count)
        (check-equal? (agent-param-performance-ref summary 'first-agent)
                      'agent/perf)
        (check-equal? (agent-param-performance-ref summary 'last-contract)
                      'agent-param/perf-199)
        (check-equal? (agent-param-performance-ref summary 'runtime-executed)
                      #f)
        (check-equal? (agent-param-performance-ref summary
                                                   'memory-catalog-valid?)
                      #t)
        (check-equal? (agent-param-performance-ref
                       summary
                       'effective-isolation-mode)
                      'child-isolated)
        (check-equal? (agent-param-performance-ref
                       summary
                       'effective-sandbox-profile-ref)
                      'agent/nono)
        (check-equal? (agent-param-performance-ref
                       summary
                       'allowed-communication-receipt-count)
                      1)
        (check-equal? (agent-param-performance-ref
                       summary
                       'denied-communication-receipt-count)
                      0)
        (check-equal? (agent-param-performance-ref
                       summary
                       'memory-catalog-resolved-store-count)
                      1)
        (agent-param-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
