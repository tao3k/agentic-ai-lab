;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface AgentParam scenario.
;;; Invariant: AgentParam rows bind topology to effective policy validation
;;; without opening providers, tools, memory stores, streams, or sandboxes.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-flag-entry)
        (only-in "../user-interface/custom/my-module/cases/session-agent-param"
                 agentic-ai-lab-custom-my-module-session-agent-param-case))

(export user-interface-custom-session-agent-param-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> [PooUserModuleSelection] [Alist])
(def (module-config-rows module-selection-bundle)
  (let* ((selection (car module-selection-bundle))
         (entry
          (yuanxu-user-module-selection-flag-entry selection ':session-rows)))
    (if entry (cdr entry) '())))

;; : TestSuite
(def user-interface-custom-session-agent-param-test
  (test-suite "agentic-ai-lab custom user-interface session-agent-param case"
    (yuanxu-test-case "projects custom AgentParam contract without runtime work"
      (let* ((selection
              (car agentic-ai-lab-custom-my-module-session-agent-param-case))
             (row
              (car
               (module-config-rows
                agentic-ai-lab-custom-my-module-session-agent-param-case))))
        (check-equal? (yuanxu-user-module-selection-key selection)
                      '(session . session))
        (check-equal? (test-ref row 'kind)
                      'agentic-ai-lab.session.agent-param-contract)
        (check-equal? (test-ref row 'contract-id)
                      'agent-param/custom-build)
        (check-equal? (test-ref row 'agent-id) 'agent/build)
        (check-equal? (test-ref row 'provider-ref) 'marlin/provider)
        (check-equal? (test-ref row 'effective-model-ref)
                      'marlin/model/build-review)
        (check-equal? (test-ref row 'effective-isolation-mode)
                      'child-isolated)
        (check-equal? (test-ref row 'effective-sandbox-profile-ref)
                      'agent/nono)
        (check-equal? (test-ref row 'validation-valid?) #t)
        (check-equal? (test-ref row 'validation-diagnostic-count) 0)
        (check-equal? (test-ref row 'tool-refs)
                      '(read-workspace-file run-build-command))
        (check-equal? (test-ref row 'memory-refs) '(session/memory))
        (check-equal? (test-ref row 'memory-catalog-ref)
                      'memory-core/custom-agent-param)
        (check-equal? (test-ref row 'memory-catalog-valid?) #t)
        (check-equal? (test-ref row 'memory-catalog-resolved-store-refs)
                      '(session/memory))
        (check-equal? (test-ref row 'memory-catalog-unresolved-store-refs)
                      '())
        (check-equal?
         (length (test-ref row 'allowed-communication-receipts))
         1)
        (check-equal?
         (test-ref (car (test-ref row 'allowed-communication-receipts))
                   'target-session-id)
         'custom/root-session)
        (check-equal? (test-ref row 'denied-communication-receipts)
                      '())
        (check-equal? (test-ref row 'runtime-executed) #f)))))
