;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;;
;;; Experiment-only native tool. Candidate input is read as inert data.
(import (only-in :gerbil-ascent/candidate/reasoning
                 reasoning-source-snapshot reasoning-attempt
                 reasoning-receipt-status reasoning-receipt-rows
                 reasoning-receipt-diagnostics
                 reasoning-receipt-bound? reasoning-receipt-stratified
                 reasoning-stratified-evidence-status
                 reasoning-diagnostic-code reasoning-diagnostic-path
                 reasoning-verify-finite-receipt
                 reasoning-verify-stratified-receipt)
        (only-in :std/time/precise
                 current-time-precise PreciseTime-seconds
                 PreciseTime-nseconds))
(export main)

(def (clock-ns)
  (let (now (current-time-precise))
    (+ (* (PreciseTime-seconds now) 1000000000)
       (PreciseTime-nseconds now))))

(def (source generation edges blocks)
  (reasoning-source-snapshot
   'study-negation-count generation
   (list (list 'edge 2 edges)
         (list 'blocked 2 blocks)
         '(weight 2 ((2 4) (3 6)))
         '(root 1 ((1))))))

(def (probe name source datum)
  (let* ((receipt (reasoning-attempt source datum 100000 20000))
         (evidence (reasoning-receipt-stratified receipt)))
    (list name
          (reasoning-receipt-status receipt)
          (reasoning-receipt-rows receipt)
          (reasoning-receipt-bound? receipt source datum)
          (if evidence (reasoning-stratified-evidence-status evidence) 'none)
          (reasoning-verify-finite-receipt receipt source datum 20000)
          (reasoning-verify-stratified-receipt receipt source datum 20000)
          (map (lambda (diagnostic)
                 (list (reasoning-diagnostic-code diagnostic)
                       (reasoning-diagnostic-path diagnostic)))
               (reasoning-receipt-diagnostics receipt)))))

(def (main . _)
  (let loop ()
    (let (datum (read))
      (unless (eof-object? datum)
        (let* ((start (clock-ns))
               (first (source 1 '((1 2) (2 3)) '((1 3))))
               (changed (source 2 '((1 2) (2 3)) '()))
               (repeated (source 3 '((1 2) (1 2) (2 3)) '())))
          (write (list 'receipt
                       (probe 'blocked first datum)
                       (probe 'unblocked changed datum)
                       (probe 'duplicate-edge repeated datum)
                       (list 'stale
                             (reasoning-verify-stratified-receipt
                              (reasoning-attempt first datum 100000 20000)
                              changed datum 20000))))
          (newline)
          (display "TIMING ")
          (display (- (clock-ns) start))
          (newline)
          (display "END\n")
          (force-output)
          (loop))))))
