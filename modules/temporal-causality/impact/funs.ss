;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types
                 agentic-ai-lab-temporal-instant?)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/types
                 agentic-ai-lab-temporal-trajectory-series?)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/funs
                 agentic-ai-lab-temporal-trajectory-replay)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/objects
                 agentic-ai-lab-temporal-impact-contrast-point-value
                 agentic-ai-lab-temporal-impact-contrast-value
                 agentic-ai-lab-temporal-intervention-window-audit-value))
(export agentic-ai-lab-temporal-impact-contrast
        agentic-ai-lab-temporal-intervention-window-audit)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (digest datum)
  (string-append "sha256:"
   (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (port) (write datum port))))))))
(def (sample-time sample) (.ref sample 'instant))
(def (sample-coordinate sample) (.ref (sample-time sample) 'coordinate))
(def (instant-row instant)
  (list (.ref instant 'identity) (.ref instant 'domain-identity)
        (.ref instant 'coordinate) (.ref instant 'provenance-identity)
        (.ref instant 'modality)))

(def (agentic-ai-lab-temporal-impact-contrast identity left right)
  (unless (and (text? identity)
               (agentic-ai-lab-temporal-trajectory-series? left)
               (agentic-ai-lab-temporal-trajectory-series? right)
               (every (lambda (slot)
                        (equal? (.ref left slot) (.ref right slot)))
                      '(subject-identity outcome-identity unit-identity
                        source-cut-digest source-projection-digest
                        time-domain-identity)))
    (error "trajectory contrast requires one subject, outcome, unit and evidence scope"))
  (let* ((left (agentic-ai-lab-temporal-trajectory-replay left))
         (right (agentic-ai-lab-temporal-trajectory-replay right))
         (left-samples (.ref left 'samples))
         (right-samples (.ref right 'samples)))
    (unless (equal? (map sample-coordinate left-samples)
                    (map sample-coordinate right-samples))
      (error "trajectory contrast requires an aligned time grid"))
    (let loop ((lefts left-samples) (rights right-samples)
               (previous-coordinate #f) (previous-delta #f)
               (reverse-points '()))
      (if (null? lefts)
        (let* ((points (reverse reverse-points))
               (status
                (if (and (eq? (.ref left 'modality) 'observed)
                         (eq? (.ref right 'modality) 'observed))
                  'descriptive-contrast 'candidate-contrast))
               (semantic-digest
                (digest
                 (list 'agentic-ai-lab.temporal-causality.impact-contrast.v1
                       identity (.ref left 'semantic-digest)
                       (.ref right 'semantic-digest) status
                       (map (lambda (point)
                              (list (.ref point 'coordinate)
                                    (.ref point 'left-instant-identity)
                                    (.ref point 'right-instant-identity)
                                    (.ref point 'level-delta)
                                    (.ref point 'rate-delta)))
                            points)))))
          (agentic-ai-lab-temporal-impact-contrast-value
           identity semantic-digest
           (.ref left 'semantic-digest) (.ref right 'semantic-digest)
           (.ref left 'source-cut-digest)
           (.ref left 'source-projection-digest)
           (.ref left 'subject-identity) (.ref left 'outcome-identity)
           (.ref left 'unit-identity) (.ref left 'time-domain-identity)
           status points))
        (let* ((left-sample (car lefts))
               (right-sample (car rights))
               (coordinate (sample-coordinate left-sample))
               (level-delta (- (.ref left-sample 'outcome)
                               (.ref right-sample 'outcome)))
               (rate-delta
                (and previous-coordinate
                     (/ (- level-delta previous-delta)
                        (- coordinate previous-coordinate))))
               (point
                (agentic-ai-lab-temporal-impact-contrast-point-value
                 coordinate
                 (.ref (sample-time left-sample) 'identity)
                 (.ref (sample-time right-sample) 'identity)
                 level-delta rate-delta)))
          (loop (cdr lefts) (cdr rights) coordinate level-delta
                (cons point reverse-points)))))))

;;; A candidate intervention window checks factual-prefix agreement and
;;; computes a trapezoidal score from a supplied contrast on its existing
;;; grid. It does not identify a causal effect or observed values between grid
;;; points.
(def (agentic-ai-lab-temporal-intervention-window-audit
      identity intervention left right onset end)
  (unless (and (text? identity) (text? intervention)
               (agentic-ai-lab-temporal-instant? onset)
               (agentic-ai-lab-temporal-instant? end)
               (agentic-ai-lab-temporal-trajectory-series? left)
               (agentic-ai-lab-temporal-trajectory-series? right)
               (memq (.ref left 'modality) '(predicted counterfactual))
               (eq? (.ref right 'modality) 'observed)
               (equal? (.ref onset 'domain-identity)
                       (.ref left 'time-domain-identity))
               (equal? (.ref end 'domain-identity)
                       (.ref left 'time-domain-identity))
               (< (.ref onset 'coordinate) (.ref end 'coordinate)))
    (error "invalid candidate intervention window"))
  (let* ((contrast (agentic-ai-lab-temporal-impact-contrast
                    (string-append identity "/contrast") left right))
         (points (.ref contrast 'points))
         (start (.ref onset 'coordinate))
         (finish (.ref end 'coordinate))
         (coordinates (map (lambda (point) (.ref point 'coordinate)) points))
         (prefix (filter (lambda (point)
                           (< (.ref point 'coordinate) start)) points))
         (window (filter (lambda (point)
                           (<= start (.ref point 'coordinate) finish))
                         points)))
    (unless (and (member start coordinates) (member finish coordinates)
                 (>= (length window) 2))
      (error "intervention window endpoints must occur on the observed grid"))
    (let* ((prefix-status
            (cond ((null? prefix) 'unobserved)
                  ((every (lambda (point)
                            (zero? (.ref point 'level-delta))) prefix)
                   'consistent)
                  (else 'diverged)))
           (area
            (let loop ((previous (car window)) (rest (cdr window)) (total 0))
              (if (null? rest) total
                (let (current (car rest))
                  (loop current (cdr rest)
                        (+ total
                           (* (/ (+ (.ref previous 'level-delta)
                                    (.ref current 'level-delta)) 2)
                              (- (.ref current 'coordinate)
                                 (.ref previous 'coordinate)))))))))
           (mean (/ area (- finish start)))
           (semantic-digest
            (digest (list 'agentic-ai-lab.temporal-causality.intervention-window.v1
                          identity intervention (.ref contrast 'semantic-digest)
                          (instant-row onset) (instant-row end)
                          prefix-status (length prefix) area mean))))
      (agentic-ai-lab-temporal-intervention-window-audit-value
       identity semantic-digest (.ref contrast 'semantic-digest)
       intervention (.ref onset 'identity) (.ref end 'identity)
       (.ref contrast 'source-cut-digest)
       (.ref contrast 'source-projection-digest)
       (.ref contrast 'subject-identity) (.ref contrast 'outcome-identity)
       (.ref contrast 'unit-identity) (.ref contrast 'time-domain-identity)
       prefix-status (length prefix) window area mean))))
