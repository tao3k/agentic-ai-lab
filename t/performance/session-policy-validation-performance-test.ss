;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session policy validation performance gate for multi-agent rows.
;;; Invariant: POO policy authoring projects to bounded validation receipts
;;; without executing tools, hooks, providers, sandboxes, or communication.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        :agentic-ai-lab/modules/session/config
        :agentic-ai-lab/modules/tool-core/config
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/config)

(export session-policy-validation-performance-test)

;; : String
(def session-policy-validation-fixture-path
  "t/scenarios/performance/session-policy-validation/benchmark.ss")

;; : Alist
(def session-policy-validation-fixture
  (call-with-input-file session-policy-validation-fixture-path read))

;; : (-> Alist Symbol MaybeValue)
(def (session-policy-validation-performance-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (session-policy-validation-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] session-policy-validation ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Integer Symbol)
(def (session-policy-validation-performance-id prefix index)
  (string->symbol
   (string-append prefix "/" (number->string index))))

;; : (-> Integer PooSessionToolAttempt)
(def (session-policy-validation-performance-agent-attempt index)
  (let (tool-ref (if (= (modulo index 3) 0)
                   'write-workspace-file
                   'run-build-command))
    (agentic-ai-lab-session-policy-tool-attempt
     (session-policy-validation-performance-id "attempt/agent" index)
     'agent-turn
     tool-ref
     (if (eq? tool-ref 'write-workspace-file) 'write 'run)
     'project-workspace
     'agent/build)))

;; : (-> Integer PooSessionToolAttempt)
(def (session-policy-validation-performance-hook-attempt index)
  (let (tool-ref (if (= (modulo index 2) 0)
                   'read-workspace-file
                   'run-build-command))
    (agentic-ai-lab-session-policy-tool-attempt
     (session-policy-validation-performance-id "attempt/hook" index)
     'hook/pre-check
     tool-ref
     (if (eq? tool-ref 'read-workspace-file) 'read 'run)
     'project-workspace
     'hook/pre-check)))

;; : (-> Alist)
(def (session-policy-validation-performance-context)
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
           'policy/perf-model
           'session/perf-build
           'marlin/provider
           'marlin/model/build-review
           '(tool-calling structured-output)
           'budget/build))
         (prompt-policy
          (agentic-ai-lab-session-prompt-policy
           'policy/perf-prompt
           'session/perf-build
           'session/perf-system
           '(system build-contract)
           'parent-summary-only))
         (isolation-policy
          (agentic-ai-lab-session-isolation-policy
           'policy/perf-isolation
           'session/perf-build
           'child-isolated
           'denied
           'denied
           'declared-channel-only))
         (sandbox-policy
          (agentic-ai-lab-session-sandbox-policy
           'policy/perf-sandbox
           'session/perf-build
           'agent/nono
           'parent-profile
           'isolated-filesystem))
         (context-policy
          (agentic-ai-lab-session-context-policy
           'policy/perf-context
           'session/perf-build
           'parent-summary
           '(session/root)))
         (history-policy
          (agentic-ai-lab-session-history-policy
           'policy/perf-history
           'session/perf-build
           'bounded
           '(record/last-failure)))
         (communication-policy
          (agentic-ai-lab-session-communication-policy
           'policy/perf-communication
           'session/perf-build
           '(channel/build-root)
           '(session/root)))
         (root-communication
          (agentic-ai-lab-session-communication-receipt
           'project/perf
           'child-parent
           'session/root
           'session/root
           'session/perf-build
           'session/root
           'agent/build
           'agent/root
           'channel/build-root
           'result
           '((summary . "perf build completed"))
           'receipt-only))
         (audit-communication
          (agentic-ai-lab-session-communication-receipt
           'project/perf
           'sibling
           'session/root
           'session/root
           'session/perf-build
           'session/audit
           'agent/build
           'agent/audit
           'channel/build-audit
           'artifact
           '((artifact . perf-build-report))
           'declared-channel-only))
         (sharing-policy
          (agentic-ai-lab-session-resource-sharing-policy
           'policy/perf-sharing
           'session/perf-build
           '((project-workspace
              (access . read)
              (accounting . session/root))
             (build-cache
              (access . read-write)
              (accounting . session/perf-build)))
           'deny))
         (resource-policy
          (agentic-ai-lab-session-resource-policy
           'policy/perf-resource
           'session/perf-build
           '(budget/build)
           '(project-workspace build-cache)
           'session/perf-build))
         (agent-tool-policy
          (agentic-ai-lab-session-tool-permission-policy
           'policy/perf-agent-tools
           'session/perf-build
           (list read-grant build-grant)
           '(write-workspace-file)
           'deny))
         (hook-tool-policy
          (agentic-ai-lab-session-hook-tool-permission-policy
           'policy/perf-hook-tools
           'session/perf-build
           '(hook/pre-check)
           (list read-grant)
           'human-approval-on-escalation
           'deny))
         (build-tool
          (agentic-ai-lab-tool-spec
           'run-build-command
           'builtin-command
           '(run)
           '((argv . list) (cwd . string))
           '((exit-status . integer)
             (stdout-ref . artifact)
             (stderr-ref . artifact))
           "marlin-agent-core"
           'tool/run-build-command
           #t
           'agent/nono
           'marlin-tool-adapter))
         (tool-catalog
          (agentic-ai-lab-tool-catalog
           'tool-core/perf-session-policy
           (list agentic-ai-lab-tool-core-builtin-read-workspace-file
                 build-tool)))
         (tool-catalog-validation-row
          (agentic-ai-lab-tool-policy-catalog-validation-receipt->alist
           (agentic-ai-lab-tool-policy-catalog-validation-receipt
            'validation/perf-tool-catalog
            tool-catalog
            agent-tool-policy
            hook-tool-policy)))
         (memory-store
          (agentic-ai-lab-memory-store-spec
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
          (agentic-ai-lab-memory-catalog
           'memory-core/perf
           (list memory-store)))
         (memory-intent
          (agentic-ai-lab-session-memory-intent
           'intent/perf-memory
           'memory/perf
           'project
           '(current-ticket)
           'append))
         (memory-catalog-validation-row
          (agentic-ai-lab-memory-policy-catalog-validation-receipt->alist
           (agentic-ai-lab-memory-policy-catalog-validation-receipt
            'validation/perf-memory-catalog
            memory-catalog
            (list memory-intent)))))
    (list (cons 'model model-policy)
          (cons 'prompt prompt-policy)
          (cons 'isolation isolation-policy)
          (cons 'sandbox sandbox-policy)
          (cons 'context context-policy)
          (cons 'history history-policy)
          (cons 'communication communication-policy)
          (cons 'communication-receipts
                (list root-communication audit-communication))
          (cons 'sharing sharing-policy)
          (cons 'resource resource-policy)
          (cons 'agent-tool agent-tool-policy)
          (cons 'hook-tool hook-tool-policy)
          (cons 'tool-catalog-validation-row
                tool-catalog-validation-row)
          (cons 'memory-catalog-validation-row
                memory-catalog-validation-row))))

;; : (-> Alist Integer Alist)
(def (session-policy-validation-performance-summary context attempt-count)
  (let* ((agent-attempts
          (agentic-ai-lab-performance-build-list
           attempt-count
           session-policy-validation-performance-agent-attempt))
         (hook-attempts
          (agentic-ai-lab-performance-build-list
           attempt-count
           session-policy-validation-performance-hook-attempt))
         (receipt
          (agentic-ai-lab-session-policy-validation-receipt
           'validation/perf-build
           'session/perf-build
           (session-policy-validation-performance-ref context 'model)
           (session-policy-validation-performance-ref context 'prompt)
           (session-policy-validation-performance-ref context 'isolation)
           (session-policy-validation-performance-ref context 'sandbox)
           (session-policy-validation-performance-ref context 'context)
           (session-policy-validation-performance-ref context 'history)
           (session-policy-validation-performance-ref context 'communication)
           (session-policy-validation-performance-ref context 'sharing)
           (session-policy-validation-performance-ref context 'resource)
           (session-policy-validation-performance-ref context 'agent-tool)
           (session-policy-validation-performance-ref context 'hook-tool)
           '(session/root session/audit)
           '(record/last-failure record/full-transcript)
           '(channel/build-root channel/build-audit)
           '(project-workspace build-cache network-egress)
           agent-attempts
           hook-attempts
           (list
            (cons 'memory-catalog-validation
                  (session-policy-validation-performance-ref
                   context
                   'memory-catalog-validation-row))
            (cons 'tool-catalog-validation
                  (session-policy-validation-performance-ref
                   context
                   'tool-catalog-validation-row))
            (cons 'communication-receipts
                  (session-policy-validation-performance-ref
                   context
                   'communication-receipts))
            (cons 'sibling-session-refs '(session/audit)))))
         (receipt-row
          (agentic-ai-lab-session-policy-validation-receipt->alist receipt)))
    (list (cons 'valid?
                (session-policy-validation-performance-ref receipt-row
                                                           'valid?))
          (cons 'agent-attempt-count (length agent-attempts))
          (cons 'hook-attempt-count (length hook-attempts))
          (cons 'allowed-agent-count
                (length
                 (session-policy-validation-performance-ref
                  receipt-row
                  'allowed-agent-tool-attempts)))
          (cons 'denied-agent-count
                (length
                 (session-policy-validation-performance-ref
                  receipt-row
                  'denied-agent-tool-attempts)))
          (cons 'allowed-hook-count
                (length
                 (session-policy-validation-performance-ref
                  receipt-row
                  'allowed-hook-tool-attempts)))
          (cons 'denied-hook-count
                (length
                 (session-policy-validation-performance-ref
                  receipt-row
                  'denied-hook-tool-attempts)))
          (cons 'diagnostic-count
                (session-policy-validation-performance-ref
                 receipt-row
                 'diagnostic-count))
          (cons 'tool-catalog-valid?
                (session-policy-validation-performance-ref
                 receipt-row
                 'tool-catalog-valid?))
          (cons 'tool-catalog-allowed-attempt-tool-ref-count
                (length
                 (session-policy-validation-performance-ref
                  receipt-row
                  'tool-catalog-allowed-attempt-tool-refs)))
          (cons 'tool-catalog-unresolved-attempt-tool-ref-count
                (length
                 (session-policy-validation-performance-ref
                  receipt-row
                  'tool-catalog-unresolved-attempt-tool-refs)))
          (cons 'memory-catalog-valid?
                (session-policy-validation-performance-ref
                 receipt-row
                 'memory-catalog-valid?))
          (cons 'effective-isolation-mode
                (session-policy-validation-performance-ref
                 receipt-row
                 'effective-isolation-mode))
          (cons 'effective-sandbox-profile-ref
                (session-policy-validation-performance-ref
                 receipt-row
                 'effective-sandbox-profile-ref))
          (cons 'allowed-communication-receipt-count
                (length
                 (session-policy-validation-performance-ref
                  receipt-row
                  'allowed-communication-receipts)))
          (cons 'denied-communication-receipt-count
                (length
                 (session-policy-validation-performance-ref
                  receipt-row
                  'denied-communication-receipts)))
          (cons 'memory-catalog-resolved-store-count
                (length
                 (session-policy-validation-performance-ref
                  receipt-row
                  'memory-catalog-resolved-store-refs)))
          (cons 'runtime-executed
                (session-policy-validation-performance-ref
                 receipt-row
                 'runtime-executed)))))

;; : TestSuite
(def session-policy-validation-performance-test
  (test-suite "session policy validation performance"
    (yuanxu-test-case "keeps multi-agent policy validation inside benchmark contract"
      (let* ((attempt-count 240)
             (context (session-policy-validation-performance-context))
             (summary
              (session-policy-validation-performance-summary
               context
               attempt-count))
             (receipt
              (benchmark-run
               session-policy-validation-fixture
               (lambda ()
                 (session-policy-validation-performance-summary
                  context
                  attempt-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass? session-policy-validation-fixture)
         #t)
        (check-equal?
         (session-policy-validation-performance-ref summary 'valid?)
         #f)
        (check-equal?
         (session-policy-validation-performance-ref summary
                                                    'agent-attempt-count)
         attempt-count)
        (check-equal?
         (session-policy-validation-performance-ref summary
                                                    'hook-attempt-count)
         attempt-count)
        (check-equal?
         (session-policy-validation-performance-ref summary
                                                    'denied-agent-count)
         80)
        (check-equal?
         (session-policy-validation-performance-ref summary
                                                    'denied-hook-count)
         120)
        (check-equal?
         (session-policy-validation-performance-ref summary
                                                    'runtime-executed)
         #f)
        (check-equal?
         (session-policy-validation-performance-ref summary
                                                    'memory-catalog-valid?)
         #t)
        (check-equal?
         (session-policy-validation-performance-ref summary
                                                    'tool-catalog-valid?)
         #t)
        (check-equal?
         (session-policy-validation-performance-ref
          summary
          'tool-catalog-allowed-attempt-tool-ref-count)
         2)
        (check-equal?
         (session-policy-validation-performance-ref
          summary
          'tool-catalog-unresolved-attempt-tool-ref-count)
         0)
        (check-equal?
         (session-policy-validation-performance-ref summary
                                                    'effective-isolation-mode)
         'child-isolated)
        (check-equal?
         (session-policy-validation-performance-ref
          summary
          'effective-sandbox-profile-ref)
         'agent/nono)
        (check-equal?
         (session-policy-validation-performance-ref
          summary
          'allowed-communication-receipt-count)
         1)
        (check-equal?
         (session-policy-validation-performance-ref
          summary
          'denied-communication-receipt-count)
         1)
        (check-equal?
         (session-policy-validation-performance-ref
          summary
          'memory-catalog-resolved-store-count)
         1)
        (session-policy-validation-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
