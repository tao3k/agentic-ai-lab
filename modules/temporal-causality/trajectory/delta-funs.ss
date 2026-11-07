;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure, coordinate-indexed comparison of two immutable trajectory series.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/types
                 agentic-ai-lab-temporal-trajectory-series?)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/funs
                 agentic-ai-lab-temporal-trajectory-replay)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/delta-objects
                 agentic-ai-lab-temporal-trajectory-delta-value))
(export agentic-ai-lab-temporal-trajectory-delta)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (digest datum)
  (string-append "sha256:"
   (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (port) (write datum port))))))))
(def (coordinate sample) (.ref (.ref sample 'instant) 'coordinate))
(def (sample-row sample)
  (let (instant (.ref sample 'instant))
    (list (.ref instant 'identity) (.ref instant 'domain-identity)
          (.ref instant 'coordinate) (.ref instant 'provenance-identity)
          (.ref instant 'modality) (.ref sample 'outcome))))

(def (coordinate-differences old-samples new-samples)
  (let loop ((old old-samples) (new new-samples)
             (added '()) (removed '()) (changed '()))
    (cond
     ((and (null? old) (null? new))
      (list (reverse added) (reverse removed) (reverse changed)))
     ((null? old)
      (loop old (cdr new) (cons (coordinate (car new)) added)
            removed changed))
     ((null? new)
      (loop (cdr old) new added (cons (coordinate (car old)) removed)
            changed))
     (else
      (let ((a (coordinate (car old))) (b (coordinate (car new))))
        (cond ((< a b)
               (loop (cdr old) new added (cons a removed) changed))
              ((> a b)
               (loop old (cdr new) (cons b added) removed changed))
              (else
               (loop (cdr old) (cdr new) added removed
                     (if (equal? (sample-row (car old))
                                 (sample-row (car new)))
                       changed (cons a changed))))))))))

(def (agentic-ai-lab-temporal-trajectory-delta identity previous revised)
  (unless (and (text? identity)
               (agentic-ai-lab-temporal-trajectory-series? previous)
               (agentic-ai-lab-temporal-trajectory-series? revised)
               (every (lambda (slot)
                        (equal? (.ref previous slot) (.ref revised slot)))
                      '(subject-identity scenario-identity outcome-identity
                        unit-identity time-domain-identity modality)))
    (error "trajectory delta requires one series context"))
  (let* ((previous (agentic-ai-lab-temporal-trajectory-replay previous))
         (revised (agentic-ai-lab-temporal-trajectory-replay revised))
         (old-digest (.ref previous 'semantic-digest))
         (new-digest (.ref revised 'semantic-digest)))
    (when (and (equal? (.ref previous 'identity) (.ref revised 'identity))
               (not (equal? old-digest new-digest)))
      (error "trajectory identity cannot name two different versions"))
    (let* ((differences
            (coordinate-differences (.ref previous 'samples)
                                    (.ref revised 'samples)))
           (added (car differences))
           (removed (cadr differences))
           (changed (caddr differences))
           (sample-change? (or (pair? added) (pair? removed) (pair? changed)))
           (scope-change?
            (or (not (equal? (.ref previous 'source-cut-digest)
                             (.ref revised 'source-cut-digest)))
                (not (equal? (.ref previous 'source-projection-digest)
                             (.ref revised 'source-projection-digest)))))
           (status
            (cond ((and sample-change? scope-change?)
                   'sample-and-scope-change)
                  (sample-change? 'sample-change)
                  (scope-change? 'scope-change)
                  ((equal? old-digest new-digest) 'unchanged)
                  (else 'identity-only)))
           (semantic-digest
            (digest
             (list 'agentic-ai-lab.temporal-causality.trajectory-delta.v1
                   identity old-digest new-digest added removed changed
                   status))))
      (agentic-ai-lab-temporal-trajectory-delta-value
       identity semantic-digest previous revised old-digest new-digest
       (.ref previous 'source-cut-digest) (.ref revised 'source-cut-digest)
       (.ref previous 'source-projection-digest)
       (.ref revised 'source-projection-digest)
       added removed changed status))))
