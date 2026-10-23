;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only session registry receipts.
;;; Invariant: registry receipts index declared sessions; they are not runtime
;;; stores and never retain live execution state.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/session/config)

(export session-registry-receipt-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : PooSession
(def registry-root-session
  (agentic-ai-lab-session-value
   'registry/root
   (list (agentic-ai-lab-session-chunk 'request 'user "Create registry."))
   (agentic-ai-lab-session-lineage 'registry/root '() 'root)
   (agentic-ai-lab-session-placement 'agent/nono)))

;; : PooSession
(def registry-child-session
  (agentic-ai-lab-session-value
   'registry/child
   (list (agentic-ai-lab-session-chunk 'child 'assistant "Child work."))
   (agentic-ai-lab-session-lineage 'registry/child '(registry/root) 'child-agent)
   (agentic-ai-lab-session-placement 'agent/nono)))

;; : TestSuite
(def session-registry-receipt-test
  (test-suite "agentic-ai-lab session registry receipts"
    (yuanxu-test-case "projects root and child sessions into registry entries"
      (let* ((isolation
              (agentic-ai-lab-session-isolation-policy
               'policy/child-isolation
               'registry/child
               'isolated
               'denied
               'receipt-only
               'declared-channel-only))
             (context
              (agentic-ai-lab-session-context-policy
               'policy/child-context
               'registry/child
               'parent-summary
               '(registry/root)))
             (child-entry
              (agentic-ai-lab-session-registry-entry
               registry-child-session
               'agent/child
               '(channel/root-child)
               (list (cons 'isolation
                           (agentic-ai-lab-session-policy->alist isolation))
                     (cons 'context
                           (agentic-ai-lab-session-policy->alist context))
                     (cons 'durable
                           '((policy-id . durable/registry)
                             (valid? . #t))))))
             (root-entry
              (agentic-ai-lab-session-registry-entry
               registry-root-session
               'agent/root
               '()
               '((isolation . root))))
             (receipt
              (agentic-ai-lab-session-registry-receipt
               'project/demo
               '(registry/root)
               '(registry/child)
               'registry/root
               (list root-entry child-entry)))
             (receipt-row
              (agentic-ai-lab-session-registry-receipt->alist receipt)))
        (check-equal? (agentic-ai-lab-session-registry-entry? child-entry) #t)
        (check-equal? (agentic-ai-lab-session-registry-entry-session-id
                       child-entry)
                      'registry/child)
        (check-equal? (agentic-ai-lab-session-registry-entry-agent-id child-entry)
                      'agent/child)
        (check-equal? (agentic-ai-lab-session-registry-entry-parent-session-ids
                       child-entry)
                      '(registry/root))
        (check-equal? (test-ref child-entry 'communication-channels)
                      '(channel/root-child))
        (check-equal? (test-ref (test-ref child-entry
                                           'isolation-policy-summary)
                                'policy-kind)
                      'session-isolation)
        (check-equal? (test-ref child-entry 'durable-policy-ref)
                      'durable/registry)
        (check-equal? (test-ref (test-ref child-entry
                                           'durable-policy-summary)
                                'valid?)
                      #t)
        (check-equal? (agentic-ai-lab-session-registry-receipt? receipt) #t)
        (check-equal? (agentic-ai-lab-session-registry-receipt-project-id
                       receipt)
                      'project/demo)
        (check-equal? (agentic-ai-lab-session-registry-receipt-session-ids
                       receipt)
                      '(registry/root registry/child))
        (check-equal? (test-ref receipt-row 'root-session-ids)
                      '(registry/root))
        (check-equal? (test-ref receipt-row 'child-session-ids)
                      '(registry/child))
        (check-equal? (test-ref receipt-row 'durable-policy-refs)
                      '(durable/registry))
        (check-equal? (test-ref receipt-row 'runtime-executed) #f)
        (check-equal? (test-ref receipt-row 'kind)
                      'agentic-ai-lab.session.registry-receipt)
        (check-equal? (test-ref receipt-row 'entry-count) 2)
        (check-equal? (test-ref receipt-row 'runtime-executed) #f)))))
