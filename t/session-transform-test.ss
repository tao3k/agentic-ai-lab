;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only session transforms for agent-flow control-plane work.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .o .ref)
        :poo-flow/modules/session/objects
        :poo-flow/modules/session/transform)

(export session-transform-test)

;; : (-> POOObject)
(def (make-session-transform-test-profile)
  (.o name: 'agent/nono
      backend-kind: 'nono
      backend-ref: 'nono-sandbox
      network-policy: '(deny-by-default)
      capabilities: '(process-run filesystem-read filesystem-write tmpdir)
      resource-policy: '((filesystem
                          (scope . project-workspace)
                          (access . read-write)))
      metadata: '((source . session-transform-test))))

;; : (-> PooSession)
(def (make-session-transform-root)
  (poo-flow-session-value
   'session-transform/root
   (list (poo-flow-session-chunk
          'request
          'user
          "Summarize the current repository state."))
   (poo-flow-session-lineage
    'session-transform/root
    '()
    'root)
   (poo-flow-session-placement-resolve
    'agent/nono
    (list (make-session-transform-test-profile))
    '((case . session-transform)))
   '((intent . agent-flow)
      (case . session-transform))))

;; : (-> PooSessionMemoryIntent)
(def (make-review-memory-intent)
  (poo-flow-session-memory-intent
   'review-memory
   'session/memory
   'project-workspace
   '(repository-summary review-notes)
   'commit-derived-session
   '((source . session-transform-test))))

;; : (-> PooSessionTransform)
(def (make-review-transform)
  (poo-flow-session-transform
   'review-agent
   'review
   "Review a session receipt and derive a follow-up session."
   '(+provider-handoff +receipt-only +session-derivation)
   '((source . session-transform-test))
   (list (make-review-memory-intent))))

;; : (-> PooSessionTransformReceipt)
(def (make-review-transform-receipt)
  (poo-flow-session-transform-apply
   (make-review-transform)
   (make-session-transform-root)
   'session-transform/review
   (list (poo-flow-session-chunk
          'review
          'assistant
          "Review the summarized repository state."))
   '((case . session-transform)
     (stage . review))))

;; : TestSuite
(def session-transform-test
  (test-suite "poo-flow report-only session transforms"
    (yuanxu-test-case "declares transform specs without runtime execution"
      (let* ((review-memory-intent (make-review-memory-intent))
             (review-transform (make-review-transform)))
      (check-equal? (poo-flow-session-transform? review-transform) #t)
      (check-equal? (poo-flow-session-transform-name review-transform)
                    'review-agent)
      (check-equal? (poo-flow-session-transform-intent review-transform)
                    'review)
      (check-equal? (poo-flow-session-transform-capabilities review-transform)
                    '(+provider-handoff +receipt-only +session-derivation))
      (check-equal? (poo-flow-session-memory-intent?
                     review-memory-intent)
                    #t)
      (check-equal? (poo-flow-session-memory-intent-name
                     review-memory-intent)
                    'review-memory)
      (check-equal? (poo-flow-session-memory-intent-store-ref
                     review-memory-intent)
                    'session/memory)
      (check-equal? (poo-flow-session-memory-intent-scope
                     review-memory-intent)
                    'project-workspace)
      (check-equal? (poo-flow-session-memory-intent-recall
                     review-memory-intent)
                    '(repository-summary review-notes))
      (check-equal? (poo-flow-session-memory-intent-commit-policy
                     review-memory-intent)
                    'commit-derived-session)
      (check-equal? (length (poo-flow-session-transform-memory-intents
                             review-transform))
                    1)
      (check-equal? (poo-flow-session-transform-runtime-owner
                     review-transform)
                    "marlin-agent-core")
      (check-equal? (.ref review-transform 'runtime-executed) #f)))
    (yuanxu-test-case "applies transforms as derived sessions and receipts"
      (let* ((review-transform-receipt
              (make-review-transform-receipt))
             (derived-session
              (poo-flow-session-transform-receipt-derived-session
               review-transform-receipt))
             (handoff-intent
              (poo-flow-session-transform-receipt-handoff-intent
               review-transform-receipt))
             (memory-receipts
              (poo-flow-session-transform-receipt-memory-receipts
               review-transform-receipt))
             (memory-receipt
              (car memory-receipts))
             (handoff-memory-intents
              (poo-flow-session-alist-ref
               handoff-intent
               'memory-intents
               '())))
        (check-equal? (poo-flow-session-transform-receipt?
                       review-transform-receipt)
                      #t)
        (check-equal? (.ref review-transform-receipt 'transform-name)
                      'review-agent)
        (check-equal? (.ref review-transform-receipt 'source-session-id)
                      'session-transform/root)
        (check-equal? (.ref review-transform-receipt 'derived-session-id)
                      'session-transform/review)
        (check-equal? (.ref review-transform-receipt 'parent-session-ids)
                      '(session-transform/root))
        (check-equal? (.ref review-transform-receipt 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (.ref review-transform-receipt 'descriptor-realized?)
                      #f)
        (check-equal? (.ref review-transform-receipt 'runtime-executed)
                      #f)
        (check-equal? (poo-flow-session? derived-session) #t)
        (check-equal? (poo-flow-session-id derived-session)
                      'session-transform/review)
        (check-equal? (poo-flow-session-lineage-parent-session-ids
                       (poo-flow-session-value-lineage derived-session))
                      '(session-transform/root))
        (check-equal? (.ref derived-session 'branch-kind) 'transform)
        (check-equal? (poo-flow-session-placement-profile-ref
                       (poo-flow-session-value-placement derived-session))
                      'agent/nono)
        (check-equal? (poo-flow-session-alist-ref
                       (poo-flow-session-metadata derived-session)
                       'transform-name
                       #f)
                      'review-agent)
        (check-equal? (poo-flow-session-alist-ref
                       handoff-intent
                       'kind
                       #f)
                      'poo-flow.session.transform.handoff-intent)
        (check-equal? (poo-flow-session-alist-ref
                       handoff-intent
                       'runtime-executed
                       #t)
                      #f)
        (check-equal? (poo-flow-session-alist-ref
                       handoff-intent
                       'memory-intent-count
                       #f)
                      1)
        (check-equal? (poo-flow-session-alist-ref
                       (car handoff-memory-intents)
                       'store-ref
                       #f)
                      'session/memory)
        (check-equal? (length memory-receipts) 1)
        (check-equal? (poo-flow-session-memory-receipt?
                       memory-receipt)
                      #t)
        (check-equal? (poo-flow-session-memory-receipt-name
                       memory-receipt)
                      'review-memory)
        (check-equal? (poo-flow-session-memory-receipt-ref
                       memory-receipt
                       'runtime-executed)
                      #f)
        (check-equal? (poo-flow-session-alist-ref
                       handoff-intent
                       'placement-resolved?
                       #f)
                      #t)))))
