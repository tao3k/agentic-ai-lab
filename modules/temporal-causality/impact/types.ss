;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every))
(export AgenticAILabTemporalImpactContrastPoint AgenticAILabTemporalImpactContrast
        AgenticAILabTemporalInterventionWindowAudit
        agentic-ai-lab-temporal-impact-contrast-point?
        agentic-ai-lab-temporal-impact-contrast?
        agentic-ai-lab-temporal-intervention-window-audit?)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (exact-rational? value) (and (rational? value) (exact? value)))
(def (slots? value names)
  (and (object? value) (every (lambda (name) (.slot? value name)) names)))

(def (contrast-point-shape? value)
  (and (slots? value '(kind coordinate left-instant-identity
                             right-instant-identity level-delta rate-delta))
       (eq? (.ref value 'kind)
            'agentic-ai-lab.temporal-causality.impact-contrast-point)
       (exact-integer? (.ref value 'coordinate))
       (>= (.ref value 'coordinate) 0)
       (text? (.ref value 'left-instant-identity))
       (text? (.ref value 'right-instant-identity))
       (exact-rational? (.ref value 'level-delta))
       (or (not (.ref value 'rate-delta))
           (exact-rational? (.ref value 'rate-delta)))))
(define-type (AgenticAILabTemporalImpactContrastPoint @ Type.)
  .element?: contrast-point-shape?)
(def (agentic-ai-lab-temporal-impact-contrast-point? value)
  (element? AgenticAILabTemporalImpactContrastPoint value))

(def (contrast-shape? value)
  (and (slots? value '(kind identity semantic-digest left-series-digest
                             right-series-digest source-cut-digest
                             source-projection-digest subject-identity
                             outcome-identity unit-identity time-domain-identity
                             status points causal-impact-admitted?
                             runtime-executed?))
       (eq? (.ref value 'kind)
            'agentic-ai-lab.temporal-causality.impact-contrast)
       (every text? (map (lambda (slot) (.ref value slot))
                         '(identity semantic-digest left-series-digest
                           right-series-digest source-cut-digest
                           source-projection-digest subject-identity
                           outcome-identity unit-identity time-domain-identity)))
       (memq (.ref value 'status)
             '(descriptive-contrast candidate-contrast))
       (list? (.ref value 'points))
       (>= (length (.ref value 'points)) 2)
       (every agentic-ai-lab-temporal-impact-contrast-point?
              (.ref value 'points))
       (eq? (.ref value 'causal-impact-admitted?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))
(define-type (AgenticAILabTemporalImpactContrast @ Type.)
  .element?: contrast-shape?)
(def (agentic-ai-lab-temporal-impact-contrast? value)
  (element? AgenticAILabTemporalImpactContrast value))

(def (window-audit-shape? value)
  (and (slots? value '(kind identity semantic-digest contrast-digest
                             intervention-identity onset-instant-identity
                             end-instant-identity source-cut-digest
                             source-projection-digest subject-identity
                             outcome-identity unit-identity time-domain-identity
                             prefix-status prefix-observed-count window-points
                             cumulative-delta mean-delta
                             causal-impact-admitted? runtime-executed?))
       (eq? (.ref value 'kind)
            'agentic-ai-lab.temporal-causality.intervention-window-audit)
       (every text? (map (lambda (slot) (.ref value slot))
                         '(identity semantic-digest contrast-digest
                           intervention-identity onset-instant-identity
                           end-instant-identity source-cut-digest
                           source-projection-digest subject-identity
                           outcome-identity unit-identity time-domain-identity)))
       (memq (.ref value 'prefix-status)
             '(consistent diverged unobserved))
       (exact-integer? (.ref value 'prefix-observed-count))
       (>= (.ref value 'prefix-observed-count) 0)
       (list? (.ref value 'window-points))
       (>= (length (.ref value 'window-points)) 2)
       (every agentic-ai-lab-temporal-impact-contrast-point?
              (.ref value 'window-points))
       (exact-rational? (.ref value 'cumulative-delta))
       (exact-rational? (.ref value 'mean-delta))
       (eq? (.ref value 'causal-impact-admitted?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))
(define-type (AgenticAILabTemporalInterventionWindowAudit @ Type.)
  .element?: window-audit-shape?)
(def (agentic-ai-lab-temporal-intervention-window-audit? value)
  (element? AgenticAILabTemporalInterventionWindowAudit value))
