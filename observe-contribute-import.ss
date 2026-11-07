#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; -*- Gerbil -*-
;;; Boundary: bounded, phase-attributed import observation for one contribution test.

(import (only-in :clan/poo/object .ref)
        (only-in :yuanxu/observability/debug
                 YuanxuDebugMemoryAnomaly?
                 YuanxuDebugMemoryAnomaly-receipt
                 yuanxu-debug-memory-policy
                 yuanxu-debug-memory-receipt-sexp
                 yuanxu-debug-memory-snapshot
                 call-with-agentic-ai-lab-debug-memory-monitor))

(def (elapsed-milliseconds started)
  (quotient (* (- (current-jiffy) started) 1000)
            (jiffies-per-second)))

(def (test-path->module-id contribution module test-file)
  (let* ((path (string-append contribution "/t/" module "/" test-file))
         (length (string-length path)))
    (unless (and (> length 3)
                 (string=? (substring path (- length 3) length) ".ss"))
      (error "contribution test import requires an .ss file" path))
    (string->symbol
     (string-append ":agentic-ai-lab/" (substring path 0 (- length 3))))))

(def (emit-import-event phase owner module test-file module-id . fields)
  (display "[agentic-ai-lab-observability] phase=")
  (display phase)
  (display " owner=")
  (display owner)
  (display " module=")
  (display module)
  (display " test=")
  (display test-file)
  (display " import=")
  (display module-id)
  (for-each (lambda (field)
              (display " ")
              (display (car field))
              (display "=")
              (display (cdr field)))
            fields)
  (newline)
  (force-output))

(def (observe-contribution-test-import contribution module test-file)
  (let* ((module-id (test-path->module-id contribution module test-file))
         (started (current-jiffy))
         (initial (yuanxu-debug-memory-snapshot 'test-import))
         ;; A unit-test import must stay small. This catches the lazy POO slot
         ;; cycle that previously grew gxi into gigabytes before wall timeout.
         (policy
          (yuanxu-debug-memory-policy
           'contribution-test-import
           heap-limit-bytes: (+ (.ref initial 'heap-size-bytes) 268435456)
           live-growth-limit-bytes: 67108864
           sample-interval-milliseconds: 25
           fail-closed?: #t)))
    (emit-import-event 'import-start contribution module test-file module-id)
    (with-catch
     (lambda (failure)
       (if (YuanxuDebugMemoryAnomaly? failure)
         (begin
           (display "[agentic-ai-lab-observability] phase=import-memory-rejected receipt=")
           (write
            (yuanxu-debug-memory-receipt-sexp
             (YuanxuDebugMemoryAnomaly-receipt failure)))
           (newline)
           (force-output)
           (exit 3))
         (raise failure)))
     (lambda ()
       (call-with-values
        (lambda ()
          (call-with-agentic-ai-lab-debug-memory-monitor
           policy
           'test-import
           (lambda () (eval `(import ,module-id)))))
        (lambda (_ receipt)
          (emit-import-event
           'import-complete contribution module test-file module-id
           (cons 'elapsed-ms (elapsed-milliseconds started))
           (cons 'heap-growth-bytes (.ref receipt 'heap-growth-bytes))
           (cons 'live-growth-bytes (.ref receipt 'live-growth-bytes)))))))))

(let (arguments (cddr (command-line)))
  (unless (= (length arguments) 3)
    (error "usage: observe-contribute-import.ss <contribution> <module> <test-file>"))
  (apply observe-contribution-test-import arguments))
