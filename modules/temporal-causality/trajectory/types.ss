;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types
                 agentic-ai-lab-temporal-instant?))
(export AgenticAILabTemporalTrajectorySample AgenticAILabTemporalTrajectorySeries
        agentic-ai-lab-temporal-trajectory-sample?
        agentic-ai-lab-temporal-trajectory-series?)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (exact-rational? value) (and (rational? value) (exact? value)))
(def (slots? value names)
  (and (object? value) (every (lambda (name) (.slot? value name)) names)))

(def (sample-shape? value)
  (and (slots? value '(kind instant outcome))
       (eq? (.ref value 'kind) 'agentic-ai-lab.temporal-causality.trajectory-sample)
       (agentic-ai-lab-temporal-instant? (.ref value 'instant))
       (exact-rational? (.ref value 'outcome))))
(define-type (AgenticAILabTemporalTrajectorySample @ Type.)
  .element?: sample-shape?)
(def (agentic-ai-lab-temporal-trajectory-sample? value)
  (element? AgenticAILabTemporalTrajectorySample value))

(def (series-shape? value)
  (and (slots? value '(kind identity semantic-digest subject-identity
                             scenario-identity outcome-identity unit-identity
                             source-cut-digest source-projection-digest
                             time-domain-identity modality samples))
       (eq? (.ref value 'kind) 'agentic-ai-lab.temporal-causality.trajectory-series)
       (every text? (map (lambda (slot) (.ref value slot))
                         '(identity semantic-digest subject-identity
                           scenario-identity outcome-identity unit-identity
                           source-cut-digest source-projection-digest
                           time-domain-identity)))
       (memq (.ref value 'modality) '(observed predicted counterfactual))
       (list? (.ref value 'samples))
       (>= (length (.ref value 'samples)) 2)
       (every agentic-ai-lab-temporal-trajectory-sample? (.ref value 'samples))))
(define-type (AgenticAILabTemporalTrajectorySeries @ Type.)
  .element?: series-shape?)
(def (agentic-ai-lab-temporal-trajectory-series? value)
  (element? AgenticAILabTemporalTrajectorySeries value))
