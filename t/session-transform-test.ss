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
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/transform)

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
  (agentic-ai-lab-session-value
   'session-transform/root
   (list (agentic-ai-lab-session-chunk
          'request
          'user
          "Summarize the current repository state."))
   (agentic-ai-lab-session-lineage
    'session-transform/root
    '()
    'root)
   (agentic-ai-lab-session-placement-resolve
    'agent/nono
    (list (make-session-transform-test-profile))
    '((case . session-transform)))
   '((intent . agent-flow)
      (case . session-transform))))

;; : (-> PooSessionMemoryIntent)
(def (make-review-memory-intent)
  (agentic-ai-lab-session-memory-intent
   'review-memory
   'session/memory
   'project-workspace
   '(repository-summary review-notes)
   'commit-derived-session
   '((source . session-transform-test))))

;; : (-> PooSessionTransform)
(def (make-review-transform)
  (agentic-ai-lab-session-transform
   'review-agent
   'review
   "Review a session receipt and derive a follow-up session."
   '(+provider-handoff +receipt-only +session-derivation)
   '((source . session-transform-test))
   (list (make-review-memory-intent))))

;; : (-> PooSessionTransformReceipt)
(def (make-review-transform-receipt)
  (agentic-ai-lab-session-transform-apply
   (make-review-transform)
   (make-session-transform-root)
   'session-transform/review
   (list (agentic-ai-lab-session-chunk
          'review
          'assistant
          "Review the summarized repository state."))
   '((case . session-transform)
     (stage . review))))

;; : TestSuite
(def session-transform-test
  (test-suite "agentic-ai-lab report-only session transforms"
    (yuanxu-test-case "declares transform specs without runtime execution"
      (let* ((review-memory-intent (make-review-memory-intent))
             (review-transform (make-review-transform)))
      (check-equal? (agentic-ai-lab-session-transform? review-transform) #t)
      (check-equal? (agentic-ai-lab-session-transform-name review-transform)
                    'review-agent)
      (check-equal? (agentic-ai-lab-session-transform-intent review-transform)
                    'review)
      (check-equal? (agentic-ai-lab-session-transform-capabilities review-transform)
                    '(+provider-handoff +receipt-only +session-derivation))
      (check-equal? (agentic-ai-lab-session-memory-intent?
                     review-memory-intent)
                    #t)
      (check-equal? (agentic-ai-lab-session-memory-intent-name
                     review-memory-intent)
                    'review-memory)
      (check-equal? (agentic-ai-lab-session-memory-intent-store-ref
                     review-memory-intent)
                    'session/memory)
      (check-equal? (agentic-ai-lab-session-memory-intent-scope
                     review-memory-intent)
                    'project-workspace)
      (check-equal? (agentic-ai-lab-session-memory-intent-recall
                     review-memory-intent)
                    '(repository-summary review-notes))
      (check-equal? (agentic-ai-lab-session-memory-intent-commit-policy
                     review-memory-intent)
                    'commit-derived-session)
      (check-equal? (length (agentic-ai-lab-session-transform-memory-intents
                             review-transform))
                    1)
      (check-equal? (agentic-ai-lab-session-transform-runtime-owner
                     review-transform)
                    "marlin-agent-core")
      (check-equal? (.ref review-transform 'runtime-executed) #f)))
    (yuanxu-test-case "applies transforms as derived sessions and receipts"
      (let* ((review-transform-receipt
              (make-review-transform-receipt))
             (derived-session
              (agentic-ai-lab-session-transform-receipt-derived-session
               review-transform-receipt))
             (handoff-intent
              (agentic-ai-lab-session-transform-receipt-handoff-intent
               review-transform-receipt))
             (memory-receipts
              (agentic-ai-lab-session-transform-receipt-memory-receipts
               review-transform-receipt))
             (memory-receipt
              (car memory-receipts))
             (handoff-memory-intents
              (agentic-ai-lab-session-alist-ref
               handoff-intent
               'memory-intents
               '())))
        (check-equal? (agentic-ai-lab-session-transform-receipt?
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
        (check-equal? (agentic-ai-lab-session? derived-session) #t)
        (check-equal? (agentic-ai-lab-session-id derived-session)
                      'session-transform/review)
        (check-equal? (agentic-ai-lab-session-lineage-parent-session-ids
                       (agentic-ai-lab-session-value-lineage derived-session))
                      '(session-transform/root))
        (check-equal? (.ref derived-session 'branch-kind) 'transform)
        (check-equal? (agentic-ai-lab-session-placement-profile-ref
                       (agentic-ai-lab-session-value-placement derived-session))
                      'agent/nono)
        (check-equal? (agentic-ai-lab-session-alist-ref
                       (agentic-ai-lab-session-metadata derived-session)
                       'transform-name
                       #f)
                      'review-agent)
        (check-equal? (agentic-ai-lab-session-alist-ref
                       handoff-intent
                       'kind
                       #f)
                      'agentic-ai-lab.session.transform.handoff-intent)
        (check-equal? (agentic-ai-lab-session-alist-ref
                       handoff-intent
                       'runtime-executed
                       #t)
                      #f)
        (check-equal? (agentic-ai-lab-session-alist-ref
                       handoff-intent
                       'memory-intent-count
                       #f)
                      1)
        (check-equal? (agentic-ai-lab-session-alist-ref
                       (car handoff-memory-intents)
                       'store-ref
                       #f)
                      'session/memory)
        (check-equal? (length memory-receipts) 1)
        (check-equal? (agentic-ai-lab-session-memory-receipt?
                       memory-receipt)
                      #t)
        (check-equal? (agentic-ai-lab-session-memory-receipt-name
                       memory-receipt)
                      'review-memory)
        (check-equal? (agentic-ai-lab-session-memory-receipt-ref
                       memory-receipt
                       'runtime-executed)
                      #f)
        (check-equal? (agentic-ai-lab-session-alist-ref
                       handoff-intent
                       'placement-resolved?
                       #f)
                      #t)))))
