;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface session-policy scenario.
;;; Invariant: user config projects effective policy validation only; Scheme
;;; never executes tools, hooks, providers, sandboxes, or communication.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :core/module-system/selection/objects
                 poo-flow-user-module-selection-key
                 poo-flow-user-module-selection-flag-entry)
        :poo-flow/modules/session/config
        (only-in "../user-interface/custom/my-module/cases/session-policy"
                 poo-flow-custom-my-module-session-policy-case))

(export user-interface-custom-session-policy-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> [Alist] [Symbol])
(def (diagnostic-codes diagnostics)
  (map (lambda (diagnostic)
         (test-ref diagnostic 'code))
       diagnostics))

;; : (-> Symbol [Symbol] Boolean)
(def (has-code? code codes)
  (if (member code codes) #t #f))

;; : (-> [Alist] (-> Alist Boolean) MaybeAlist)
(def (find-row rows predicate)
  (cond
   ((null? rows) #f)
   ((predicate (car rows)) (car rows))
   (else (find-row (cdr rows) predicate))))

;; : (-> [Alist] Symbol MaybeAlist)
(def (find-policy-row rows policy-kind)
  (find-row rows
            (lambda (row)
              (equal? (test-ref row 'policy-kind) policy-kind))))

;; : (-> [Alist] MaybeAlist)
(def (find-validation-row rows)
  (find-row rows
            (lambda (row)
              (equal? (test-ref row 'kind)
                      'poo-flow.session.policy-validation-receipt))))

;; : (-> [Alist] MaybeAlist)
(def (find-tool-catalog-validation-row rows)
  (find-row rows
            (lambda (row)
              (equal? (test-ref row 'kind)
                      'poo-flow.tool-core.policy-catalog-validation-receipt))))

;; : (-> [Alist] MaybeAlist)
(def (find-memory-catalog-validation-row rows)
  (find-row rows
            (lambda (row)
              (equal? (test-ref row 'kind)
                      'poo-flow.memory-core.policy-catalog-validation-receipt))))

;; : (-> [Alist] Symbol MaybeAlist)
(def (find-communication-row rows relation-kind)
  (find-row rows
            (lambda (row)
              (and (equal? (test-ref row 'kind)
                           'poo-flow.session.communication-receipt)
                   (equal? (test-ref row 'relation-kind)
                           relation-kind)))))

;; : (-> [Alist] Symbol MaybeAlist)
(def (find-communication-channel-row rows channel-id)
  (find-row rows
            (lambda (row)
              (and (equal? (test-ref row 'kind)
                           'poo-flow.session.communication-channel-receipt)
                   (equal? (test-ref row 'channel-id)
                           channel-id)))))

;; : (-> [PooUserModuleSelection] [Alist])
(def (module-config-rows module-selection-bundle)
  (let* ((selection (car module-selection-bundle))
         (entry
          (poo-flow-user-module-selection-flag-entry selection ':session-rows)))
    (if entry (cdr entry) '())))

;; : TestSuite
(def user-interface-custom-session-policy-test
  (test-suite "poo-flow custom user-interface session-policy case"
    (poo-flow-test-case "projects custom effective session-policy validation"
      (let* ((selection
              (car poo-flow-custom-my-module-session-policy-case))
             (rows
              (module-config-rows
               poo-flow-custom-my-module-session-policy-case))
             (durable-row (car rows))
             (isolation-row (find-policy-row rows 'session-isolation))
             (isolation-slots (test-ref isolation-row 'policy-slots))
             (sandbox-row (find-policy-row rows 'session-sandbox))
             (sandbox-slots (test-ref sandbox-row 'policy-slots))
             (sharing-row (find-policy-row rows 'session-sharing))
             (sharing-slots (test-ref sharing-row 'policy-slots))
             (tool-catalog-validation
              (find-tool-catalog-validation-row rows))
             (memory-catalog-validation
              (find-memory-catalog-validation-row rows))
             (build-root-channel
              (find-communication-channel-row rows 'channel/build-root))
             (build-audit-channel
              (find-communication-channel-row rows 'channel/build-audit))
             (build-root-communication
              (find-communication-row rows 'child-parent))
             (build-audit-communication
              (find-communication-row rows 'sibling))
             (validation (find-validation-row rows))
             (codes (diagnostic-codes
                     (test-ref validation 'diagnostics))))
        (check-equal? (poo-flow-user-module-selection-key selection)
                      '(session . session))
        (check-equal? (test-ref durable-row 'runtime-executed) #f)
        (check-equal? (test-ref isolation-row 'schema)
                      'poo-flow.modules.session.policy.isolation.v1)
        (check-equal? (test-ref isolation-slots 'mode)
                      'child-isolated)
        (check-equal? (test-ref isolation-slots 'sibling-context)
                      'denied)
        (check-equal? (test-ref sandbox-row 'schema)
                      'poo-flow.modules.session.policy.sandbox.v1)
        (check-equal? (test-ref sandbox-slots 'profile-ref)
                      'sandbox/nono-build)
        (check-equal? (test-ref sandbox-slots 'sharing-mode)
                      'isolated-filesystem)
        (check-equal? (test-ref sharing-row 'schema)
                      'poo-flow.modules.session.policy.sharing.v1)
        (check-equal? (test-ref sharing-slots 'memory-refs)
                      '(memory/project))
        (check-equal? (test-ref sharing-slots 'workspace-paths)
                      '("build/" "reports/"))
        (check-equal? (test-ref tool-catalog-validation 'valid?) #t)
        (check-equal? (test-ref tool-catalog-validation 'policy-tool-refs)
                      '(read-workspace-file run-build-command))
        (check-equal? (test-ref tool-catalog-validation 'resolved-tool-refs)
                      '(read-workspace-file run-build-command))
        (check-equal? (test-ref memory-catalog-validation 'valid?) #t)
        (check-equal? (test-ref memory-catalog-validation 'resolved-store-refs)
                      '(memory/project))
        (check-equal? (test-ref build-root-channel 'relation-kind)
                      'child-parent)
        (check-equal? (test-ref build-root-channel 'allowed-message-kinds)
                      '(result))
        (check-equal? (test-ref build-audit-channel 'relation-kind)
                      'sibling)
        (check-equal? (test-ref build-audit-channel 'delivery-policies)
                      '(declared-channel-only))
        (check-equal? (test-ref build-root-communication 'channel-id)
                      'channel/build-root)
        (check-equal? (test-ref build-root-communication 'target-session-id)
                      'custom/session-root)
        (check-equal? (test-ref build-audit-communication 'channel-id)
                      'channel/build-audit)
        (check-equal? (test-ref build-audit-communication 'target-session-id)
                      'custom/audit-session)
        (check-equal? (test-ref validation 'kind)
                      'poo-flow.session.policy-validation-receipt)
        (check-equal? (test-ref validation 'validation-id)
                      'validation/custom-build)
        (check-equal? (test-ref validation 'scope-ref)
                      'custom/session-build-child)
        (check-equal? (test-ref validation 'effective-model-ref)
                      'marlin/model/build-review)
        (check-equal? (test-ref validation 'effective-prompt-session-ref)
                      'custom/session-build-system)
        (check-equal? (test-ref validation 'effective-isolation-mode)
                      'child-isolated)
        (check-equal? (test-ref validation 'effective-sandbox-profile-ref)
                      'sandbox/nono-build)
        (check-equal? (test-ref validation 'allowed-context-refs)
                      '(custom/session-root))
        (check-equal?
         (length (test-ref validation
                           'allowed-communication-channel-receipts))
         1)
        (check-equal?
         (test-ref (car (test-ref validation
                                   'allowed-communication-channel-receipts))
                   'channel-id)
         'channel/build-root)
        (check-equal?
         (length (test-ref validation
                           'denied-communication-channel-receipts))
         1)
        (check-equal?
         (test-ref (car (test-ref validation
                                   'denied-communication-channel-receipts))
                   'channel-id)
         'channel/build-audit)
        (check-equal?
         (length (test-ref validation 'allowed-communication-receipts))
         1)
        (check-equal?
         (test-ref (car (test-ref validation
                                   'allowed-communication-receipts))
                   'target-session-id)
         'custom/session-root)
        (check-equal?
         (length (test-ref validation 'denied-communication-receipts))
         1)
        (check-equal?
         (test-ref (car (test-ref validation
                                   'denied-communication-receipts))
                   'target-session-id)
         'custom/audit-session)
        (check-equal? (test-ref validation 'denied-resource-refs)
                      '(network-egress))
        (check-equal? (test-ref validation 'tool-catalog-validation-id)
                      'validation/custom-session-tool-catalog)
        (check-equal? (test-ref validation 'tool-catalog-ref)
                      'tool-core/custom-session-policy)
        (check-equal? (test-ref validation 'tool-catalog-valid?) #t)
        (check-equal? (test-ref validation
                                'tool-catalog-policy-tool-refs)
                      '(read-workspace-file run-build-command))
        (check-equal? (test-ref validation
                                'tool-catalog-resolved-tool-refs)
                      '(read-workspace-file run-build-command))
        (check-equal? (test-ref validation
                                'tool-catalog-allowed-attempt-tool-refs)
                      '(run-build-command))
        (check-equal? (test-ref validation
                                'tool-catalog-unresolved-attempt-tool-refs)
                      '())
        (check-equal? (test-ref validation 'memory-catalog-validation-id)
                      'validation/custom-session-memory-catalog)
        (check-equal? (test-ref validation 'memory-catalog-ref)
                      'memory-core/custom-session-policy)
        (check-equal? (test-ref validation 'memory-catalog-valid?) #t)
        (check-equal? (test-ref validation
                                'memory-catalog-resolved-store-refs)
                      '(memory/project))
        (check-equal? (test-ref validation 'valid?) #f)
        (check-equal?
         (has-code? 'hook-tool-agent-permission-not-inherited codes)
         #t)
        (check-equal? (has-code? 'sibling-context-not-granted codes) #t)
        (check-equal?
         (has-code? 'communication-receipt-channel-not-granted codes)
         #t)
        (check-equal?
         (has-code? 'communication-receipt-target-not-granted codes)
         #t)
        (check-equal?
         (has-code? 'communication-channel-receipt-not-granted codes)
         #t)
        (check-equal? (test-ref validation 'runtime-executed) #f)))))
