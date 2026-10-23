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
        :poo-flow/modules/session/config)

(export session-registry-receipt-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : PooSession
(def registry-root-session
  (poo-flow-session-value
   'registry/root
   (list (poo-flow-session-chunk 'request 'user "Create registry."))
   (poo-flow-session-lineage 'registry/root '() 'root)
   (poo-flow-session-placement 'agent/nono)))

;; : PooSession
(def registry-child-session
  (poo-flow-session-value
   'registry/child
   (list (poo-flow-session-chunk 'child 'assistant "Child work."))
   (poo-flow-session-lineage 'registry/child '(registry/root) 'child-agent)
   (poo-flow-session-placement 'agent/nono)))

;; : TestSuite
(def session-registry-receipt-test
  (test-suite "poo-flow session registry receipts"
    (yuanxu-test-case "projects root and child sessions into registry entries"
      (let* ((isolation
              (poo-flow-session-isolation-policy
               'policy/child-isolation
               'registry/child
               'isolated
               'denied
               'receipt-only
               'declared-channel-only))
             (context
              (poo-flow-session-context-policy
               'policy/child-context
               'registry/child
               'parent-summary
               '(registry/root)))
             (child-entry
              (poo-flow-session-registry-entry
               registry-child-session
               'agent/child
               '(channel/root-child)
               (list (cons 'isolation
                           (poo-flow-session-policy->alist isolation))
                     (cons 'context
                           (poo-flow-session-policy->alist context))
                     (cons 'durable
                           '((policy-id . durable/registry)
                             (valid? . #t))))))
             (root-entry
              (poo-flow-session-registry-entry
               registry-root-session
               'agent/root
               '()
               '((isolation . root))))
             (receipt
              (poo-flow-session-registry-receipt
               'project/demo
               '(registry/root)
               '(registry/child)
               'registry/root
               (list root-entry child-entry)))
             (receipt-row
              (poo-flow-session-registry-receipt->alist receipt)))
        (check-equal? (poo-flow-session-registry-entry? child-entry) #t)
        (check-equal? (poo-flow-session-registry-entry-session-id
                       child-entry)
                      'registry/child)
        (check-equal? (poo-flow-session-registry-entry-agent-id child-entry)
                      'agent/child)
        (check-equal? (poo-flow-session-registry-entry-parent-session-ids
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
        (check-equal? (poo-flow-session-registry-receipt? receipt) #t)
        (check-equal? (poo-flow-session-registry-receipt-project-id
                       receipt)
                      'project/demo)
        (check-equal? (poo-flow-session-registry-receipt-session-ids
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
                      'poo-flow.session.registry-receipt)
        (check-equal? (test-ref receipt-row 'entry-count) 2)
        (check-equal? (test-ref receipt-row 'runtime-executed) #f)))))
