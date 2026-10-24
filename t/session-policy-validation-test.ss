;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: effective multi-agent session policy validation.
;;; Invariant: validation inspects composed POO policies and bounded attempts;
;;; it does not run tools, hooks, providers, sandboxes, or communication.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/session/config
        :agentic-ai-lab/modules/tool-core/config
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/config)

(export session-policy-validation-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> [Alist] [Symbol])
(def (diagnostic-codes diagnostics)
  (map (lambda (diagnostic)
         (test-ref diagnostic 'code))
       diagnostics))

;; : (-> Symbol [Symbol] Boolean)
(def (has-code? code codes)
  (if (member code codes) #t #f))

;; : (-> Alist)
(def (make-session-policy-validation-context)
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
           'project/session
           'child-parent
           'session/root
           'session/root
           'session/build
           'session/root
           'agent/build
           'agent/root
           'channel/build-root
           'result
           '((summary . "build completed"))
           'receipt-only))
         (build-audit-communication
          (agentic-ai-lab-session-communication-receipt
           'project/session
           'sibling
           'session/root
           'session/root
           'session/build
           'session/audit
           'agent/build
           'agent/audit
           'channel/build-audit
           'artifact
           '((artifact . build-report))
           'declared-channel-only))
         (sharing-policy
          (agentic-ai-lab-session-resource-sharing-policy
           'policy/build-sharing
           'session/build
           '((project-workspace
              (access . read))
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
           'policy/build-agent-tools
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
           'deny))
         (tool-catalog
          (agentic-ai-lab-tool-catalog
           'tool-core/session-policy-test
           (list agentic-ai-lab-tool-core-builtin-read-workspace-file)))
         (tool-catalog-validation-row
          (agentic-ai-lab-tool-policy-catalog-validation-receipt->alist
           (agentic-ai-lab-tool-policy-catalog-validation-receipt
            'validation/session-policy-tool-catalog
            tool-catalog
            agent-tool-policy
            hook-tool-policy)))
         (memory-store
          (agentic-ai-lab-memory-store-spec
           'memory/project-notes
           'durable-project
           'project
           '(current-session project)
           '(semantic-search)
           '(append review-only)
           "marlin-agent-core"
           'memory/project-notes
           #t
           'marlin-memory-adapter))
         (memory-catalog
          (agentic-ai-lab-memory-catalog
           'memory-core/session-policy-test
           (list memory-store)))
         (valid-memory-intent
          (agentic-ai-lab-session-memory-intent
           'intent/project-notes
           'memory/project-notes
           'project
           '(current-ticket)
           'append))
         (missing-memory-intent
          (agentic-ai-lab-session-memory-intent
           'intent/missing
           'memory/missing
           'project
           '(current-ticket)
           'append))
         (memory-catalog-validation-row
          (agentic-ai-lab-memory-policy-catalog-validation-receipt->alist
           (agentic-ai-lab-memory-policy-catalog-validation-receipt
            'validation/session-policy-memory-catalog
            memory-catalog
            (list valid-memory-intent missing-memory-intent))))
         (agent-attempts
          (list
           (agentic-ai-lab-session-policy-tool-attempt
            'attempt/agent-read
            'agent-turn
            'read-workspace-file
            'read
            'project-workspace
            'agent/build)
           (agentic-ai-lab-session-policy-tool-attempt
            'attempt/agent-build
            'agent-turn
            'run-build-command
            'run
            'build-cache
            'agent/build)
           (agentic-ai-lab-session-policy-tool-attempt
            'attempt/agent-write
            'agent-turn
            'write-workspace-file
            'write
            'project-workspace
            'agent/build)))
         (hook-attempts
          (list
           (agentic-ai-lab-session-policy-tool-attempt
            'attempt/hook-read
            'hook/pre-check
            'read-workspace-file
            'read
            'project-workspace
            'hook/pre-check)
           (agentic-ai-lab-session-policy-tool-attempt
            'attempt/hook-build
            'hook/pre-check
            'run-build-command
            'run
            'build-cache
            'hook/pre-check))))
    (list (cons 'model model-policy)
          (cons 'prompt prompt-policy)
          (cons 'isolation isolation-policy)
          (cons 'sandbox sandbox-policy)
          (cons 'context context-policy)
          (cons 'history history-policy)
          (cons 'communication communication-policy)
          (cons 'communication-receipts
                (list build-root-communication
                      build-audit-communication))
          (cons 'sharing sharing-policy)
          (cons 'resource resource-policy)
          (cons 'agent-tool agent-tool-policy)
          (cons 'hook-tool hook-tool-policy)
          (cons 'tool-catalog-validation-row
                tool-catalog-validation-row)
          (cons 'memory-catalog-validation-row
                memory-catalog-validation-row)
          (cons 'agent-attempts agent-attempts)
          (cons 'hook-attempts hook-attempts))))

;; : TestSuite
(def session-policy-validation-test
  (test-suite "agentic-ai-lab session policy validation"
    (yuanxu-test-case "validates effective policy and reports denied session edges"
      (let* ((context (make-session-policy-validation-context))
             (receipt
              (agentic-ai-lab-session-policy-validation-receipt
               'validation/build-session
               'session/build
               (test-ref context 'model)
               (test-ref context 'prompt)
               (test-ref context 'isolation)
               (test-ref context 'sandbox)
               (test-ref context 'context)
               (test-ref context 'history)
               (test-ref context 'communication)
               (test-ref context 'sharing)
               (test-ref context 'resource)
               (test-ref context 'agent-tool)
               (test-ref context 'hook-tool)
               '(session/root session/audit)
               '(record/last-failure record/full-transcript)
               '(channel/build-root channel/build-audit)
               '(project-workspace build-cache network-egress)
               (test-ref context 'agent-attempts)
               (test-ref context 'hook-attempts)
               (list
                (cons 'tool-catalog-validation
                      (test-ref context 'tool-catalog-validation-row))
                (cons 'memory-catalog-validation
                      (test-ref context 'memory-catalog-validation-row))
                (cons 'communication-receipts
                      (test-ref context 'communication-receipts))
                (cons 'sibling-session-refs '(session/audit)))))
             (diagnostics
              (agentic-ai-lab-session-policy-validation-receipt-diagnostics
               receipt))
             (receipt-row
              (agentic-ai-lab-session-policy-validation-receipt->alist receipt))
             (codes (diagnostic-codes diagnostics)))
        (check-equal?
         (agentic-ai-lab-session-policy-validation-receipt? receipt)
         #t)
        (check-equal?
         (agentic-ai-lab-session-policy-validation-receipt-valid? receipt)
         #f)
        (check-equal?
         (agentic-ai-lab-session-policy-validation-receipt-effective-model-ref
          receipt)
         'marlin/model/build-review)
        (check-equal?
         (agentic-ai-lab-session-policy-validation-receipt-effective-prompt-session-ref
          receipt)
         'session/build-system)
        (check-equal?
         (test-ref receipt-row 'effective-isolation-mode)
         'child-isolated)
        (check-equal?
         (test-ref receipt-row 'isolation-sibling-context)
         'denied)
        (check-equal?
         (test-ref receipt-row 'effective-sandbox-profile-ref)
         'agent/nono)
        (check-equal?
         (test-ref receipt-row 'sandbox-sharing-mode)
         'isolated-filesystem)
        (check-equal? (test-ref receipt-row 'allowed-context-refs)
                      '(session/root))
        (check-equal? (test-ref receipt-row 'denied-context-refs)
                      '(session/audit))
        (check-equal?
         (test-ref receipt-row 'allowed-communication-channels)
         '(channel/build-root))
        (check-equal?
         (length (test-ref receipt-row 'allowed-communication-receipts))
         1)
        (check-equal?
         (test-ref (car (test-ref receipt-row
                                   'allowed-communication-receipts))
                   'target-session-id)
         'session/root)
        (check-equal?
         (length (test-ref receipt-row 'denied-communication-receipts))
         1)
        (check-equal?
         (test-ref (car (test-ref receipt-row
                                   'denied-communication-receipts))
                   'target-session-id)
         'session/audit)
        (check-equal? (test-ref receipt-row 'denied-resource-refs)
                      '(network-egress))
        (check-equal? (test-ref receipt-row 'tool-catalog-validation-id)
                      'validation/session-policy-tool-catalog)
        (check-equal? (test-ref receipt-row 'tool-catalog-ref)
                      'tool-core/session-policy-test)
        (check-equal? (test-ref receipt-row 'tool-catalog-valid?) #f)
        (check-equal? (test-ref receipt-row
                                'tool-catalog-policy-tool-refs)
                      '(read-workspace-file run-build-command))
        (check-equal? (test-ref receipt-row
                                'tool-catalog-resolved-tool-refs)
                      '(read-workspace-file))
        (check-equal? (test-ref receipt-row
                                'tool-catalog-unresolved-tool-refs)
                      '(run-build-command))
        (check-equal? (test-ref receipt-row
                                'tool-catalog-allowed-attempt-tool-refs)
                      '(read-workspace-file))
        (check-equal? (test-ref receipt-row
                                'tool-catalog-unresolved-attempt-tool-refs)
                      '(run-build-command))
        (check-equal? (test-ref receipt-row 'memory-catalog-validation-id)
                      'validation/session-policy-memory-catalog)
        (check-equal? (test-ref receipt-row 'memory-catalog-ref)
                      'memory-core/session-policy-test)
        (check-equal? (test-ref receipt-row 'memory-catalog-valid?) #f)
        (check-equal? (test-ref receipt-row
                                'memory-catalog-resolved-store-refs)
                      '(memory/project-notes))
        (check-equal? (test-ref receipt-row
                                'memory-catalog-unresolved-store-refs)
                      '(memory/missing))
        (check-equal?
         (length (test-ref receipt-row 'allowed-agent-tool-attempts))
                      2)
        (check-equal?
         (length (test-ref receipt-row 'denied-agent-tool-attempts))
                      1)
        (check-equal?
         (length (test-ref receipt-row 'allowed-hook-tool-attempts))
                      1)
        (check-equal?
         (length (test-ref receipt-row 'denied-hook-tool-attempts))
                      1)
        (check-equal? (has-code? 'context-session-not-granted codes) #t)
        (check-equal? (has-code? 'sibling-context-not-granted codes) #t)
        (check-equal? (has-code? 'history-record-not-granted codes) #t)
        (check-equal? (has-code? 'communication-channel-not-granted codes)
                      #t)
        (check-equal?
         (has-code? 'communication-receipt-channel-not-granted codes)
         #t)
        (check-equal?
         (has-code? 'communication-receipt-target-not-granted codes)
         #t)
        (check-equal? (has-code? 'resource-capability-not-granted codes)
                      #t)
        (check-equal? (has-code? 'agent-tool-attempt-not-granted codes)
                      #t)
        (check-equal? (has-code? 'hook-tool-attempt-not-granted codes)
                      #t)
        (check-equal?
         (has-code? 'hook-tool-agent-permission-not-inherited codes)
         #t)
        (check-equal?
         (has-code? 'resource-sharing-missing-accounting-owner codes)
         #t)
        (check-equal? (has-code? 'tool-spec-not-in-catalog codes) #t)
        (check-equal? (has-code? 'tool-attempt-not-in-catalog codes) #t)
        (check-equal? (has-code? 'memory-store-not-in-catalog codes) #t)
        (check-equal? (test-ref receipt-row 'kind)
                      'agentic-ai-lab.session.policy-validation-receipt)
        (check-equal? (test-ref receipt-row 'diagnostic-count)
                      (length diagnostics))
        (check-equal? (test-ref receipt-row 'denied-context-refs)
                      '(session/audit))
        (check-equal?
         (agentic-ai-lab-session-policy-validation-receipt-runtime-executed?
          receipt)
         #f)))))
