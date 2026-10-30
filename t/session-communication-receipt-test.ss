;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only session communication receipts.
;;; Invariant: receipts describe routed intent; Scheme never delivers messages.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :agentic-ai-lab/modules/session/config)

(export session-communication-receipt-test)

;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : TestSuite
(def session-communication-receipt-test
  (test-suite "agentic-ai-lab session communication receipts"
    (yuanxu-test-case "names parent, child, sibling, and cross-root routing edges"
      (let* ((parent-child-channel
              (agentic-ai-lab-session-communication-channel-receipt
               'project/session
               'channel/root-build
               'parent-child
               'session/root
               'session/build
               'agent/root
               'agent/build
               '(request)
               '(receipt-only)))
             (child-parent-channel
              (agentic-ai-lab-session-communication-channel-receipt
               'project/session
               'channel/build-root
               'child-parent
               'session/build
               'session/root
               'agent/build
               'agent/root
               '(result)
               '(receipt-only)))
             (sibling-channel
              (agentic-ai-lab-session-communication-channel-receipt
               'project/session
               'channel/build-audit
               'sibling
               'session/build
               'session/audit
               'agent/build
               'agent/audit
               '(artifact)
               '(declared-channel-only)))
             (cross-root-channel
              (agentic-ai-lab-session-communication-channel-receipt
               'project/session
               'channel/audit-release
               'cross-root
               'session/audit
               'session/release
               'agent/audit
               'agent/release
               '(receipt)
               '(explicit-project-root)
               '((communication-ledger-ref . runtime/communication-ledger)
                 (durable-policy-ref . durable/session-communication))))
             (channel-rows
              (agentic-ai-lab-session-communication-channel-receipts->alists
               (list parent-child-channel
                     child-parent-channel
                     sibling-channel
                     cross-root-channel)))
             (parent-child
              (agentic-ai-lab-session-communication-receipt
               'project/session
               'parent-child
               'root/a
               'root/a
               'session/root
               'session/build
               'agent/root
               'agent/build
               'channel/root-build
               'request
               '((summary . "run build checks"))
               'receipt-only))
             (child-parent
              (agentic-ai-lab-session-communication-receipt
               'project/session
               'child-parent
               'root/a
               'root/a
               'session/build
               'session/root
               'agent/build
               'agent/root
               'channel/build-root
               'result
               '((summary . "build completed"))
               'receipt-only))
             (sibling
              (agentic-ai-lab-session-communication-receipt
               'project/session
               'sibling
               'root/a
               'root/a
               'session/build
               'session/audit
               'agent/build
               'agent/audit
               'channel/build-audit
               'artifact
               '((artifact . build-report))
               'declared-channel-only))
             (cross-root
              (agentic-ai-lab-session-communication-receipt
               'project/session
               'cross-root
               'root/a
               'root/b
               'session/audit
               'session/release
               'agent/audit
               'agent/release
               'channel/audit-release
               'receipt
               '((receipt . release-gate))
               'explicit-project-root
               '((communication-ledger-ref . runtime/communication-ledger)
                 (durable-policy-ref . durable/session-communication))))
             (rows
              (agentic-ai-lab-session-communication-receipts->alists
               (list parent-child child-parent sibling cross-root)))
             (root-build-channel-row (car channel-rows))
             (cross-root-channel-row (cadddr channel-rows))
             (cross-root-row (cadddr rows)))
        (check-equal? (agentic-ai-lab-session-communication-channel-receipt?
                       parent-child-channel)
                      #t)
        (check-equal?
         (agentic-ai-lab-session-communication-channel-receipt-channel-id
          sibling-channel)
         'channel/build-audit)
        (check-equal?
         (agentic-ai-lab-session-communication-channel-receipt-relation-kind
          cross-root-channel)
         'cross-root)
        (check-equal? (test-ref root-build-channel-row 'kind)
                      +agentic-ai-lab-session-communication-channel-receipt-kind+)
        (check-equal? (test-ref root-build-channel-row
                                'allowed-message-kinds)
                      '(request))
        (check-equal? (test-ref cross-root-channel-row 'delivery-policies)
                      '(explicit-project-root))
        (check-equal? (test-ref cross-root-channel-row
                                'communication-ledger-ref)
                      'runtime/communication-ledger)
        (check-equal? (test-ref cross-root-channel-row 'durable-policy-ref)
                      'durable/session-communication)
        (check-equal? (test-ref cross-root-channel-row 'open?) #f)
        (check-equal? (agentic-ai-lab-session-communication-receipt?
                       parent-child)
                      #t)
        (check-equal?
         (agentic-ai-lab-session-communication-receipt-project-id parent-child)
         'project/session)
        (check-equal?
         (agentic-ai-lab-session-communication-receipt-relation-kind sibling)
         'sibling)
        (check-equal?
         (agentic-ai-lab-session-communication-receipt-channel-id sibling)
         'channel/build-audit)
        (check-equal?
         (agentic-ai-lab-session-communication-receipt-source-session-id
          child-parent)
         'session/build)
        (check-equal?
         (agentic-ai-lab-session-communication-receipt-target-session-id
          cross-root)
         'session/release)
        (check-equal?
         (agentic-ai-lab-session-communication-receipt-target-root-session-id
          cross-root)
         'root/b)
        (check-equal? (test-ref cross-root-row 'kind)
                      +agentic-ai-lab-session-communication-receipt-kind+)
        (check-equal? (test-ref cross-root-row 'communication-ledger-ref)
                      'runtime/communication-ledger)
        (check-equal? (test-ref cross-root-row 'durable-policy-ref)
                      'durable/session-communication)
        (check-equal? (test-ref cross-root-row 'valid?) #t)
        (check-equal? (test-ref cross-root-row 'diagnostic-count) 0)
        (check-equal? (test-ref (car rows) 'handoff-required) #t)
        (check-equal? (test-ref (car rows) 'delivered?) #f)
        (check-equal? (test-ref (car rows) 'runtime-executed) #f)))))
