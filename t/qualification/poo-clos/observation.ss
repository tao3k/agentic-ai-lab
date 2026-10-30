;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; CLOS qualification adapter over the native POO memory-observation owner.

(import :gerbil/runtime/gambit
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/observability/debug
                 yuanxu-debug-memory-policy
                 yuanxu-debug-memory-snapshot
                 call-with-agentic-ai-lab-debug-memory-monitor
                 YuanxuDebugMemoryAnomaly?
                 YuanxuDebugMemoryAnomaly-receipt))

(export poo-clos-observe-fixture!)

(def +poo-clos-heap-growth-limit-bytes+ (* 256 1024 1024))
(def +poo-clos-live-growth-limit-bytes+ (* 64 1024 1024))
(def +poo-clos-sample-interval-milliseconds+ 25)

(def (poo-clos-observation-emit port phase event fields)
  (write
   (cons 'poo-clos-observation
         (cons '(schema v1)
               (cons (list 'phase phase)
                     (cons (list 'event event) fields))))
   port)
  (newline port)
  (force-output port))

(def (poo-clos-memory-fields receipt)
  (list
   (list 'outcome (if (.ref receipt 'accepted?) 'within-budget 'rejected))
   (list 'reason (.ref receipt 'reason))
   (list 'heap-size-bytes (.ref (.ref receipt 'after) 'heap-size-bytes))
   (list 'heap-growth-bytes (.ref receipt 'heap-growth-bytes))
   (list 'live-bytes (.ref (.ref receipt 'after) 'live-bytes))
   (list 'live-growth-bytes (.ref receipt 'live-growth-bytes))))

(def (poo-clos-observe-fixture! phase thunk
                               port: (port (current-error-port)))
  (unless (and (symbol? phase) (procedure? thunk) (output-port? port))
    (error "invalid POO CLOS fixture observation request" phase))
  (let* ((baseline (yuanxu-debug-memory-snapshot phase))
         (heap-limit
          (+ (.ref baseline 'heap-size-bytes)
             +poo-clos-heap-growth-limit-bytes+))
         (policy
          (yuanxu-debug-memory-policy
           phase
           heap-limit-bytes: heap-limit
           live-growth-limit-bytes: +poo-clos-live-growth-limit-bytes+
           sample-interval-milliseconds:
           +poo-clos-sample-interval-milliseconds+
           fail-closed?: #t)))
    (poo-clos-observation-emit
     port phase 'begin
     (list (list 'heap-limit-bytes heap-limit)
           (list 'live-growth-limit-bytes
                 +poo-clos-live-growth-limit-bytes+)
           (list 'sample-interval-milliseconds
                 +poo-clos-sample-interval-milliseconds+)))
    (with-exception-catcher
     (lambda (failure)
       (if (YuanxuDebugMemoryAnomaly? failure)
         (poo-clos-observation-emit
          port phase 'end
          (poo-clos-memory-fields
           (YuanxuDebugMemoryAnomaly-receipt failure)))
         (poo-clos-observation-emit
          port phase 'end '((outcome raised) (reason test-failure))))
       (raise failure))
     (lambda ()
       (call-with-values
        (lambda ()
          (call-with-agentic-ai-lab-debug-memory-monitor
           policy phase thunk port: port emit?: #f))
        (lambda (value receipt)
          (poo-clos-observation-emit
           port phase 'end (poo-clos-memory-fields receipt))
          value))))))
