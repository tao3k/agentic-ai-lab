;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every delete-duplicates/hash)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/types
                 agentic-ai-lab-temporal-trajectory-sample?
                 agentic-ai-lab-temporal-trajectory-series?)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/objects
                 agentic-ai-lab-temporal-trajectory-series-value))
(export agentic-ai-lab-temporal-trajectory-series
        agentic-ai-lab-temporal-trajectory-replay)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (unique? values)
  (= (length values) (length (delete-duplicates/hash values))))
(def (digest datum)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string (lambda (port) (write datum port))))))))

(def (sample-time sample) (.ref sample 'instant))
(def (sample-coordinate sample)
  (.ref (sample-time sample) 'coordinate))
(def (sample-row sample)
  (let (instant (sample-time sample))
    (list (.ref instant 'identity) (.ref instant 'domain-identity)
          (.ref instant 'coordinate) (.ref instant 'provenance-identity)
          (.ref instant 'modality) (.ref sample 'outcome))))

(def (agentic-ai-lab-temporal-trajectory-series
      identity subject scenario outcome unit cut projection modality samples)
  (unless (and (every text? (list identity subject scenario outcome unit
                                  cut projection))
               (memq modality '(observed predicted counterfactual))
               (list? samples) (>= (length samples) 2)
               (every agentic-ai-lab-temporal-trajectory-sample? samples))
    (error "invalid temporal trajectory series"))
  (let* ((ordered
          (list-sort (lambda (a b)
                       (< (sample-coordinate a) (sample-coordinate b)))
                     samples))
         (domain (.ref (sample-time (car ordered)) 'domain-identity))
         (positions (map sample-coordinate ordered)))
    (unless (and (unique? positions)
                 (unique? (map (lambda (sample)
                                 (.ref (sample-time sample) 'identity))
                               ordered))
                 (every (lambda (sample)
                          (equal? (.ref (sample-time sample) 'domain-identity)
                                  domain))
                        ordered))
      (error "trajectory samples require one clock domain and unique times"))
    (agentic-ai-lab-temporal-trajectory-series-value
     identity
     (digest (list 'agentic-ai-lab.temporal-causality.trajectory-series.v1
                   identity subject scenario outcome unit cut projection
                   domain modality (map sample-row ordered)))
     subject scenario outcome unit cut projection domain modality ordered)))

(def (agentic-ai-lab-temporal-trajectory-replay series)
  (unless (agentic-ai-lab-temporal-trajectory-series? series)
    (error "invalid temporal trajectory series"))
  (let (canonical
        (agentic-ai-lab-temporal-trajectory-series
         (.ref series 'identity) (.ref series 'subject-identity)
         (.ref series 'scenario-identity) (.ref series 'outcome-identity)
         (.ref series 'unit-identity) (.ref series 'source-cut-digest)
         (.ref series 'source-projection-digest) (.ref series 'modality)
         (.ref series 'samples)))
    (unless (equal? (.ref series 'semantic-digest)
                    (.ref canonical 'semantic-digest))
      (error "trajectory series digest differs from its samples"))
    canonical))
