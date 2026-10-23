;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native session execution, tool, and hook policy contracts.
;;; Invariant: policies are declarative authorization objects; Scheme never
;;; runs tools or hooks.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .o .ref)
        :agentic-ai-lab/modules/session/config)

(export session-policy-contract-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> Alist)
(def (make-session-policy-contract-context)
  (let* ((read-grant
          (agentic-ai-lab-session-tool-grant
           'grant/project-read
           'read-workspace-file
           '(read)
           '(project-workspace)
           '(agent-turn hook/pre-check)
           '((scope . session)
             (owner . root-agent))))
         (build-grant
          (agentic-ai-lab-session-tool-grant
           'grant/project-build
           'run-build-command
           '(run)
           '(project-workspace build-cache)
           '(agent-turn)
           '((scope . child-session)
             (owner . build-agent))))
         (main-agent-tool-policy
          (agentic-ai-lab-session-tool-permission-policy
           'policy/main-agent-tools
           'custom/session-root
           (list read-grant)
           '(write-workspace-file run-build-command)
           'deny
           '((principal . main-agent))))
         (build-agent-tool-policy
          (agentic-ai-lab-session-tool-permission-policy
           'policy/build-agent-tools
           'custom/session-build-child
           (list read-grant build-grant)
           '(write-workspace-file)
           'deny
           '((principal . build-agent))))
         (hook-tool-policy
          (agentic-ai-lab-session-hook-tool-permission-policy
           'policy/pre-check-hook-tools
           'custom/session-root
           '(hook/pre-check)
           (list read-grant)
           'human-approval-on-escalation
           'deny
           '((principal . hook/pre-check)
             (inherits-agent-tools? . #f))))
         (model-policy
          (agentic-ai-lab-session-model-policy
           'policy/build-agent-model
           'custom/session-build-child
           'marlin/provider
           'marlin/model/build-review
           '(tool-calling structured-output)
           'budget/build-agent))
         (prompt-policy
          (agentic-ai-lab-session-prompt-policy
           'policy/build-agent-prompt
           'custom/session-build-child
           'custom/session-build-system
           '(system-instruction build-contract)
           'parent-summary-only))
         (resource-policy
          (agentic-ai-lab-session-resource-sharing-policy
           'policy/build-agent-resources
           'custom/session-build-child
           '((project-workspace
              (access . read)
              (accounting . root-session))
             (build-cache
              (access . read-write)
              (accounting . child-session)))
           'deny))
         (execution-policy
          (agentic-ai-lab-session-agent-execution-policy
           'policy/build-agent-execution
           'agent/build
           'custom/session-build-child
           'policy/build-agent-model
           'policy/build-agent-prompt
           'policy/build-agent-tools
           'policy/pre-check-hook-tools
           'policy/build-agent-context
           'policy/build-agent-resources)))
    (list (cons 'main-agent-tool-policy main-agent-tool-policy)
          (cons 'build-agent-tool-policy build-agent-tool-policy)
          (cons 'hook-tool-policy hook-tool-policy)
          (cons 'execution-policy execution-policy)
          (cons 'presentation
                (list (agentic-ai-lab-session-policy->alist
                       main-agent-tool-policy)
                      (agentic-ai-lab-session-policy->alist
                       build-agent-tool-policy)
                      (agentic-ai-lab-session-policy->alist hook-tool-policy)
                      (agentic-ai-lab-session-policy->alist model-policy)
                      (agentic-ai-lab-session-policy->alist prompt-policy)
                      (agentic-ai-lab-session-policy->alist resource-policy)
                      (agentic-ai-lab-session-policy->alist
                       execution-policy))))))

;; : (-> Void)
(def (check-session-tool-permission-policy!)
  (let* ((read-grant
          (agentic-ai-lab-session-tool-grant
           'grant/read
           'read-workspace-file
           '(read)
           '(project-workspace)
           '(agent-turn)
           '((case . unit))))
         (policy
          (agentic-ai-lab-session-tool-permission-policy
           'policy/test-agent-tools
           'session/test
           (list read-grant)
           '(write-workspace-file)
           'deny
           '((case . unit))))
         (row (agentic-ai-lab-session-policy->alist policy)))
    (check-equal? (agentic-ai-lab-session-tool-grant? read-grant) #t)
    (check-equal? (agentic-ai-lab-session-policy? policy) #t)
    (check-equal? (agentic-ai-lab-session-policy-kind policy)
                  'agent-tool-permission)
    (check-equal? (agentic-ai-lab-session-policy-name policy)
                  'policy/test-agent-tools)
    (check-equal? (agentic-ai-lab-session-policy-scope-ref policy)
                  'session/test)
    (check-equal? (test-ref row 'tool-grant-count) 1)
    (check-equal? (test-ref row 'runtime-executed) #f)
    (check-equal? (agentic-ai-lab-session-tool-permission-policy-allows?
                   policy
                   'read-workspace-file
                   'read)
                  #t)
    (check-equal? (agentic-ai-lab-session-tool-permission-policy-allows?
                   policy
                   'read-workspace-file
                   'write)
                  #f)
    (check-equal? (agentic-ai-lab-session-tool-permission-policy-allows?
                   policy
                   'write-workspace-file
                   'write)
                  #f)))

;; : (-> Void)
(def (check-session-hook-tool-separation!)
  (let* ((context (make-session-policy-contract-context))
         (build-agent-tool-policy
          (test-ref context 'build-agent-tool-policy))
         (hook-tool-policy (test-ref context 'hook-tool-policy))
         (main-agent-tool-policy
          (test-ref context 'main-agent-tool-policy)))
    (check-equal? (agentic-ai-lab-session-tool-permission-policy-allows?
                   build-agent-tool-policy
                   'run-build-command
                   'run)
                  #t)
    (check-equal? (agentic-ai-lab-session-hook-tool-permission-policy-allows?
                   hook-tool-policy
                   'hook/pre-check
                   'run-build-command
                   'run)
                  #f)
    (check-equal? (agentic-ai-lab-session-hook-tool-permission-policy-allows?
                   hook-tool-policy
                   'hook/pre-check
                   'read-workspace-file
                   'read)
                  #t)
    (check-equal? (agentic-ai-lab-session-tool-permission-policy-allows?
                   main-agent-tool-policy
                   'run-build-command
                   'run)
                  #f)))

;; : (-> Void)
(def (check-session-policy-poo-inheritance!)
  (let* ((base-model
          (agentic-ai-lab-session-model-policy
           'policy/base-model
           'session/root
           'marlin/provider
           'marlin/model/default
           '(tool-calling)
           'budget/root
           '((case . inheritance))))
         (child-model
          (.o (:: @ [base-model])
              policy-name: 'policy/child-model
              scope-ref: 'session/child
              model-ref: 'marlin/model/child)))
    (check-equal? (agentic-ai-lab-session-policy? child-model) #t)
    (check-equal? (agentic-ai-lab-session-policy-kind child-model)
                  'agent-model)
    (check-equal? (agentic-ai-lab-session-policy-name child-model)
                  'policy/child-model)
    (check-equal? (agentic-ai-lab-session-policy-scope-ref child-model)
                  'session/child)
    (check-equal? (.ref child-model 'provider-ref) 'marlin/provider)
    (check-equal? (.ref child-model 'model-ref)
                  'marlin/model/child)))

;; : (-> Void)
(def (check-generated-session-policy-families!)
  (let* ((context-policy
          (agentic-ai-lab-session-context-policy
           'policy/build-agent-context
           'custom/session-build-child
           'parent-summary-only
           '(custom/session-root custom/session-review)
           '((case . generated-family))))
         (isolation-policy
          (agentic-ai-lab-session-isolation-policy
           'policy/build-agent-isolation
           'custom/session-build-child
           'strict
           'deny
           'append-summary
           'via-supervisor))
         (sandbox-policy
          (agentic-ai-lab-session-sandbox-policy
           'policy/build-agent-sandbox
           'custom/session-build-child
           'sandbox/nono-build
           'parent-profile
           'isolated-filesystem))
         (history-policy
          (agentic-ai-lab-session-history-policy
           'policy/build-agent-history
           'custom/session-build-child
           'bounded
           '(record/last-failure record/build-log)))
         (communication-policy
          (agentic-ai-lab-session-communication-policy
           'policy/build-agent-communication
           'custom/session-build-child
           '(channel/build-root channel/build-audit)
           '(custom/session-root custom/session-review)))
         (sharing-policy
          (agentic-ai-lab-session-sharing-policy
           'policy/build-agent-sharing
           'custom/session-build-child
           '(memory/project)
           '(artifact/build-log)
           '(tool-result/test-summary)
           '("build/" "reports/")))
         (resource-policy
          (agentic-ai-lab-session-resource-policy
           'policy/build-agent-budget
           'custom/session-build-child
           '(budget/build-agent)
           '(capability/cache-read capability/cache-write)
           'session/build))
         (context-row (agentic-ai-lab-session-policy->alist context-policy))
         (context-slots (test-ref context-row 'policy-slots))
         (isolation-row
          (agentic-ai-lab-session-policy->alist isolation-policy))
         (isolation-slots (test-ref isolation-row 'policy-slots))
         (sandbox-row
          (agentic-ai-lab-session-policy->alist sandbox-policy))
         (sandbox-slots (test-ref sandbox-row 'policy-slots))
         (history-row
          (agentic-ai-lab-session-policy->alist history-policy))
         (history-slots (test-ref history-row 'policy-slots))
         (communication-row
          (agentic-ai-lab-session-policy->alist communication-policy))
         (communication-slots
          (test-ref communication-row 'policy-slots))
         (sharing-row
          (agentic-ai-lab-session-policy->alist sharing-policy))
         (sharing-slots (test-ref sharing-row 'policy-slots))
         (resource-row (agentic-ai-lab-session-policy->alist resource-policy))
         (resource-slots (test-ref resource-row 'policy-slots)))
    (check-equal? (agentic-ai-lab-session-policy? context-policy) #t)
    (check-equal? (agentic-ai-lab-session-policy-kind context-policy)
                  'session-context)
    (check-equal? (agentic-ai-lab-session-policy-name context-policy)
                  'policy/build-agent-context)
    (check-equal? (agentic-ai-lab-session-policy-scope-ref context-policy)
                  'custom/session-build-child)
    (check-equal? (test-ref context-slots 'visibility)
                  'parent-summary-only)
    (check-equal? (test-ref context-slots 'allowed-session-refs)
                  '(custom/session-root custom/session-review))
    (check-equal? (test-ref context-row 'default-action) 'deny)
    (check-equal? (test-ref context-row 'metadata)
                  '((case . generated-family)))
    (check-equal? (test-ref context-row 'runtime-owner)
                  "marlin-agent-core")
    (check-equal? (test-ref context-row 'runtime-executed) #f)
    (check-equal? (agentic-ai-lab-session-policy-kind isolation-policy)
                  'session-isolation)
    (check-equal? (test-ref isolation-slots 'mode) 'strict)
    (check-equal? (test-ref isolation-slots 'parent-write)
                  'append-summary)
    (check-equal? (agentic-ai-lab-session-policy-kind sandbox-policy)
                  'session-sandbox)
    (check-equal? (test-ref sandbox-slots 'profile-ref)
                  'sandbox/nono-build)
    (check-equal? (test-ref sandbox-slots 'inheritance-mode)
                  'parent-profile)
    (check-equal? (agentic-ai-lab-session-policy-kind history-policy)
                  'session-history)
    (check-equal? (test-ref history-slots 'allowed-records)
                  '(record/last-failure record/build-log))
    (check-equal? (agentic-ai-lab-session-policy-kind communication-policy)
                  'session-communication)
    (check-equal? (test-ref communication-slots 'channel-refs)
                  '(channel/build-root channel/build-audit))
    (check-equal? (agentic-ai-lab-session-policy-kind sharing-policy)
                  'session-sharing)
    (check-equal? (test-ref sharing-slots 'memory-refs)
                  '(memory/project))
    (check-equal? (test-ref sharing-slots 'workspace-paths)
                  '("build/" "reports/"))
    (check-equal? (agentic-ai-lab-session-policy-kind resource-policy)
                  'session-resource)
    (check-equal? (test-ref resource-slots 'budget-refs)
                  '(budget/build-agent))
    (check-equal? (test-ref resource-slots 'accounting-owner)
                  'session/build)))

;; : (-> Void)
(def (check-session-durable-policy-receipt!)
  (let* ((durable-policy
          (agentic-ai-lab-durable-policy
           'durable/test
           'session/root
           '((journal-owner . runtime/fact-log)
             (checkpoint-store . runtime/checkpoint-store)
             (resume-identity . session-id)
             (repair-mode . fail-closed)
             (action-classes . (replayable idempotent compensatable)))))
         (execution-policy
          (agentic-ai-lab-session-agent-execution-policy
           'policy/durable-execution
           'agent/build
           'session/child
           'policy/model
           'policy/prompt
           'policy/tools
           'policy/hooks
           'policy/context
           'policy/resources))
         (durable-execution-policy
          (agentic-ai-lab-session-policy-attach-durable
           execution-policy
           durable-policy))
         (receipt
          (agentic-ai-lab-session-policy-durable-receipt
           durable-execution-policy
           '((project-id . project/test)
             (root-session-id . session/root)
             (session-id . session/child)
             (parent-session-id . session/root)
             (loop-run-id . loop/test))))
         (receipt-row
          (agentic-ai-lab-durable-policy-receipt->alist receipt))
         (policy-row
          (agentic-ai-lab-session-policy->alist
           durable-execution-policy))
         (embedded-durable-row
          (test-ref policy-row 'durable-policy)))
    (check-equal? (agentic-ai-lab-session-policy?
                   durable-execution-policy)
                  #t)
    (check-equal? (agentic-ai-lab-durable-policy?
                   durable-execution-policy)
                  #t)
    (check-equal? (agentic-ai-lab-durable-policy-receipt? receipt) #t)
    (check-equal? (agentic-ai-lab-durable-policy-receipt-valid? receipt) #t)
    (check-equal? (test-ref receipt-row 'policy-id) 'durable/test)
    (check-equal? (test-ref receipt-row 'session-id) 'session/child)
    (check-equal? (test-ref receipt-row 'journal-owner)
                  'runtime/fact-log)
    (check-equal? (test-ref receipt-row 'diagnostic-count) 0)
    (check-equal? (test-ref policy-row 'durable-policy-ref)
                  'durable/test)
    (check-equal? (test-ref policy-row 'durable-valid?) #t)
    (check-equal? (test-ref embedded-durable-row 'schema)
                  +agentic-ai-lab-durable-policy-receipt-schema+)))

;; : (-> Void)
(def (check-invalid-session-durable-policy!)
  (let* ((invalid-policy
          (.o durable-kind: +agentic-ai-lab-durable-policy-kind+
              durable-schema: +agentic-ai-lab-durable-policy-schema+
              durable-policy-name: 'durable/invalid
              durable-scope-ref: 'session/invalid
              repair-mode: 'teleport
              action-classes: '(replayable impossible)
              runtime-owner: 'not-a-runtime-owner))
         (receipt
          (agentic-ai-lab-durable-policy->receipt invalid-policy))
         (receipt-row
          (agentic-ai-lab-durable-policy-receipt->alist receipt))
         (diagnostics
          (test-ref receipt-row 'diagnostics)))
    (check-equal? (agentic-ai-lab-durable-policy? invalid-policy) #t)
    (check-equal? (agentic-ai-lab-durable-policy-receipt-valid? receipt) #f)
    (check-equal? (test-ref receipt-row 'valid?) #f)
    (check-equal? (> (test-ref receipt-row 'diagnostic-count) 0) #t)
    (check-equal? (list? diagnostics) #t)
    (check-equal? (test-ref (car diagnostics) 'phase)
                  'durable-policy)))

;; : (-> Void)
(def (check-session-durable-policy-batch!)
  (let* ((policies
          (list
           (agentic-ai-lab-durable-policy
            'durable/batch-root
            'session/root)
           (agentic-ai-lab-durable-policy
            'durable/batch-child
            'session/child
            '((repair-mode . retry)
              (action-classes . (replayable idempotent))))))
         (receipts
          (agentic-ai-lab-durable-policies->receipts policies))
         (rows
          (agentic-ai-lab-durable-policy-receipts->alists receipts)))
    (check-equal? (length receipts) 2)
    (check-equal? (agentic-ai-lab-durable-policy-receipt? (car receipts)) #t)
    (check-equal? (agentic-ai-lab-durable-policy-receipt? (cadr receipts)) #t)
    (check-equal? (test-ref (car rows) 'policy-id)
                  'durable/batch-root)
    (check-equal? (test-ref (cadr rows) 'policy-id)
                  'durable/batch-child)
    (check-equal? (test-ref (cadr rows) 'repair-mode)
                  'retry)
    (check-equal? (test-ref (cadr rows) 'valid?) #t)))

;; : (-> Void)
(def (check-session-policy-presentation!)
  (let* ((context (make-session-policy-contract-context))
         (presentation (test-ref context 'presentation))
         (execution-row
          (agentic-ai-lab-session-policy->alist
           (test-ref context 'execution-policy))))
    (check-equal? (length presentation) 7)
    (check-equal? (test-ref execution-row 'policy-kind)
                  'agent-execution)
    (check-equal? (test-ref execution-row 'agent-ref) 'agent/build)
    (check-equal? (test-ref execution-row 'session-ref)
                  'custom/session-build-child)
    (check-equal? (test-ref execution-row 'tool-policy-ref)
                  'policy/build-agent-tools)
    (check-equal? (test-ref execution-row 'hook-policy-ref)
                  'policy/pre-check-hook-tools)
    (check-equal? (test-ref execution-row 'runtime-executed) #f)))

;; : TestSuite
(def session-policy-contract-test
  (test-suite "agentic-ai-lab session policy contracts"
    (yuanxu-test-case "declares POO-native tool permission policies"
      (check-session-tool-permission-policy!))
    (yuanxu-test-case "keeps hook-triggered tools separate from agent tools"
      (check-session-hook-tool-separation!))
    (yuanxu-test-case "uses native POO inheritance for policy refinement"
      (check-session-policy-poo-inheritance!))
    (yuanxu-test-case "projects generated foundational policy families"
      (check-generated-session-policy-families!))
    (yuanxu-test-case "projects durable policy receipts from session policy composition"
      (check-session-durable-policy-receipt!))
    (yuanxu-test-case "reports invalid durable policies through receipt diagnostics"
      (check-invalid-session-durable-policy!))
    (yuanxu-test-case "batch projects durable policies as struct receipts before alists"
      (check-session-durable-policy-batch!))
    (yuanxu-test-case "exposes custom-shaped policy presentation"
      (check-session-policy-presentation!))))
