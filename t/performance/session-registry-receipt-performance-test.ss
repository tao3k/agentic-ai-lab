;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session registry receipt performance gate.
;;; Invariant: registry projection is a bounded address-space receipt, not a
;;; live runtime store.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        :agentic-ai-lab/modules/session/config)

(export session-registry-receipt-performance-test)

;; : String
(def session-registry-receipt-fixture-path
  "t/scenarios/performance/session-registry-receipt/benchmark.ss")

;; : Alist
(def session-registry-receipt-fixture
  (call-with-input-file session-registry-receipt-fixture-path read))

;; : (-> Alist Symbol MaybeValue)
(def (registry-performance-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (registry-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] session-registry-receipt ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> String Integer Symbol)
(def (registry-performance-symbol prefix index)
  (string->symbol
   (string-append prefix "/" (number->string index))))

;; : (-> Integer PooSession)
(def (registry-performance-session index)
  (let* ((session-id (registry-performance-symbol "session" index))
         (parent-ids (if (= index 0)
                       '()
                       '(session/0))))
    (agentic-ai-lab-session-value
     session-id
     (list (agentic-ai-lab-session-chunk
            (registry-performance-symbol "chunk" index)
            'assistant
            "session registry performance node"))
     (agentic-ai-lab-session-lineage
      session-id
      parent-ids
      (if (= index 0) 'root 'child-agent))
     (agentic-ai-lab-session-placement 'agent/nono))))

;; : (-> Integer PooSessionRegistryEntry)
(def (registry-performance-entry index)
  (agentic-ai-lab-session-registry-entry
   (registry-performance-session index)
   (registry-performance-symbol "agent" index)
   (list (registry-performance-symbol "channel" index))
   (list (cons 'context
               '((allowed-session-refs . (session/0))))
         (cons 'sharing
               '((project-workspace
                  (access . read)
                  (accounting . session/0))))
         (cons 'durable
               (list (cons 'policy-id
                           (registry-performance-symbol "durable" index))
                     (cons 'valid? #t))))))

;; : (-> Integer Alist)
(def (registry-performance-summary count)
  (let* ((entries
          (agentic-ai-lab-performance-build-list
           count
           registry-performance-entry))
         (child-session-ids
          (map agentic-ai-lab-session-registry-entry-session-id (cdr entries)))
         (receipt
          (agentic-ai-lab-session-registry-receipt
           'project/performance
           '(session/0)
           child-session-ids
           'session/0
           entries))
         (receipt-row
          (agentic-ai-lab-session-registry-receipt->alist receipt)))
    (list
     (cons 'entry-count (registry-performance-ref receipt-row 'entry-count))
     (cons 'session-count
           (length (registry-performance-ref receipt-row 'session-ids)))
     (cons 'child-session-count
           (length (registry-performance-ref receipt-row 'child-session-ids)))
     (cons 'first-session
           (agentic-ai-lab-session-registry-entry-session-id (car entries)))
     (cons 'last-session
           (agentic-ai-lab-session-registry-entry-session-id
            (list-ref entries (- count 1))))
     (cons 'runtime-executed
           (registry-performance-ref receipt-row 'runtime-executed)))))

;; : TestSuite
(def session-registry-receipt-performance-test
  (test-suite "session registry receipt performance"
    (yuanxu-test-case "keeps registry receipt projection inside benchmark contract"
      (let* ((entry-count 240)
             (summary (registry-performance-summary entry-count))
             (receipt
              (benchmark-run
               session-registry-receipt-fixture
               (lambda ()
                 (registry-performance-summary entry-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass? session-registry-receipt-fixture)
         #t)
        (check-equal?
         (registry-performance-ref summary 'entry-count)
         entry-count)
        (check-equal?
         (registry-performance-ref summary 'session-count)
         entry-count)
        (check-equal?
         (registry-performance-ref summary 'child-session-count)
         (- entry-count 1))
        (check-equal?
         (registry-performance-ref summary 'first-session)
         'session/0)
        (check-equal?
         (registry-performance-ref summary 'last-session)
         'session/239)
        (check-equal?
         (registry-performance-ref summary 'runtime-executed)
         #f)
        (registry-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
