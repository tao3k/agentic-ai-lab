;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: performance gates for session transform POO row boundaries.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .o .ref)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/transform)

(export session-transform-performance-test)

;; : String
(def session-transform-memory-intent-fixture-path
  "t/scenarios/performance/poo-session-transform-memory-intent/benchmark.ss")

;; : Alist
(def session-transform-memory-intent-fixture
  (call-with-input-file session-transform-memory-intent-fixture-path read))

;; : (-> POOObject)
(def (make-session-transform-performance-profile)
  (.o name: 'agent/nono
      backend-kind: 'nono
      backend-ref: 'nono-sandbox
      network-policy: '(deny-by-default)
      capabilities: '(process-run filesystem-read filesystem-write tmpdir)
      resource-policy: '((filesystem
                          (scope . project-workspace)
                          (access . read-write)))
      metadata: '((source . session-transform-performance-test))))

;; : (-> PooSession)
(def (make-session-transform-performance-root)
  (agentic-ai-lab-session-value
   'session-transform-performance/root
   (list (agentic-ai-lab-session-chunk
          'request
          'user
          "Summarize the current repository state."))
   (agentic-ai-lab-session-lineage
    'session-transform-performance/root
    '()
    'root)
   (agentic-ai-lab-session-placement-resolve
    'agent/nono
    (list (make-session-transform-performance-profile))
    '((case . session-transform-performance)))
   '((intent . agent-flow)
      (case . session-transform-performance))))

;; : (-> PooSessionMemoryIntent)
(def (make-session-transform-performance-memory-intent)
  (agentic-ai-lab-session-memory-intent
   'review-memory
   'session/memory
   'project-workspace
   '(repository-summary review-notes)
   'commit-derived-session
   '((source . session-transform-performance-test))))

;; : (-> PooSessionTransform)
(def (make-session-transform-performance-transform)
  (agentic-ai-lab-session-transform
   'review-agent
   'review
   "Review a session receipt and derive a follow-up session."
   '(+provider-handoff +receipt-only +session-derivation)
   '((source . session-transform-performance-test))
   (list (make-session-transform-performance-memory-intent))))

;; : (-> Integer)
(def (session-transform-performance-memory-receipt-count)
  (let (receipt
        (agentic-ai-lab-session-transform-apply
         (make-session-transform-performance-transform)
         (make-session-transform-performance-root)
         'session-transform-performance/review
         (list (agentic-ai-lab-session-chunk
                'review
                'assistant
                "Review the summarized repository state."))
         '((case . session-transform-performance)
           (stage . review))))
    (.ref receipt 'memory-receipt-count)))

;; : TestSuite
(def session-transform-performance-test
  (test-suite "agentic-ai-lab session transform POO performance"
    (yuanxu-test-case "keeps memory-intent transform receipts inside row boundary"
      (let (receipt
            (benchmark-run
             session-transform-memory-intent-fixture
             session-transform-performance-memory-receipt-count))
        (check-equal? (benchmark-fixture-contract-pass?
                       session-transform-memory-intent-fixture)
                      #t)
        (check-equal? (benchmark-receipt-pass? receipt) #t)
        (check-equal? (session-transform-performance-memory-receipt-count)
                      1)))))
