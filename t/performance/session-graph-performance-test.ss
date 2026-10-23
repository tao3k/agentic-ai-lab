;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session graph performance gates cover indexed lineage traversal.
;;; Invariant: graph presentation stays report-only and never executes runtime work.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        (only-in :poo-flow/modules/session/objects
                 poo-flow-session-chunk
                 poo-flow-session-lineage
                 poo-flow-session-placement
                 poo-flow-session-value
                 pooFlowSessionGraphPresentation))

(export session-graph-performance-test)

;; : String
(def session-graph-presentation-fixture-path
  "t/scenarios/performance/session-graph-presentation/benchmark.ss")

;; : Alist
(def session-graph-presentation-fixture
  (call-with-input-file session-graph-presentation-fixture-path read))

;; : (-> Integer Symbol)
(def (session-graph-performance-session-id index)
  (string->symbol
   (string-append "session-graph-node-" (number->string index))))

;; : (-> Integer PooSession)
(def (session-graph-performance-session index)
  (let ((session-id (session-graph-performance-session-id index))
        (parents
         (if (= index 0)
           '()
           (list (session-graph-performance-session-id (- index 1))))))
    (poo-flow-session-value
     session-id
     (list (poo-flow-session-chunk
            (string->symbol
             (string-append "chunk-" (number->string index)))
            'assistant
            "large session graph performance fixture"))
     (poo-flow-session-lineage session-id parents 'linear)
     (poo-flow-session-placement 'agent/nono)
     (list (cons 'index index)))))

;; : (-> Integer [PooSession])
(def (session-graph-performance-sessions count)
  (poo-flow-performance-build-list
   count
   session-graph-performance-session))

;; : (-> [PooSession] Alist)
(def (session-graph-performance-presentation-summary sessions)
  (let (presentation (pooFlowSessionGraphPresentation sessions))
    (list (cons 'session-count (.ref presentation 'session-count))
          (cons 'chunk-count (.ref presentation 'chunk-count))
          (cons 'edge-count
                (length (.ref presentation 'lineage-edge-pairs)))
          (cons 'acyclic? (.ref presentation 'acyclic?))
          (cons 'runtime-executed (.ref presentation 'runtime-executed)))))

;; : (-> Alist Symbol Value)
(def (session-graph-performance-ref alist key)
  (cdr (assoc key alist)))

;; : TestSuite
(def session-graph-performance-test
  (test-suite "session graph performance"
    (yuanxu-test-case "keeps large lineage presentation inside benchmark contract"
      (let* ((session-count 1200)
             (sessions (session-graph-performance-sessions session-count))
             (summary
              (session-graph-performance-presentation-summary sessions))
             (receipt
              (benchmark-run
               session-graph-presentation-fixture
               (lambda ()
                 (session-graph-performance-presentation-summary sessions)))))
        (check-equal?
         (benchmark-fixture-contract-pass? session-graph-presentation-fixture)
         #t)
        (check-equal?
         (session-graph-performance-ref summary 'session-count)
         session-count)
        (check-equal?
         (session-graph-performance-ref summary 'chunk-count)
         session-count)
        (check-equal?
         (session-graph-performance-ref summary 'edge-count)
         (- session-count 1))
        (check-equal?
         (session-graph-performance-ref summary 'acyclic?)
         #t)
        (check-equal?
         (session-graph-performance-ref summary 'runtime-executed)
         #f)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
