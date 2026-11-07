;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Clock-indexed temporal primitives. Coordinates have meaning only in their
;;; declared domain; this module never reads a live clock.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every))

(export agentic-ai-lab-temporal-instant-kind
        agentic-ai-lab-temporal-interval-kind
        agentic-ai-lab-temporal-axes-kind
        AgenticAILabTemporalInstant AgenticAILabTemporalInterval AgenticAILabTemporalAxes
        agentic-ai-lab-temporal-instant? agentic-ai-lab-temporal-interval?
        agentic-ai-lab-temporal-axes?)

(def agentic-ai-lab-temporal-instant-kind 'agentic-ai-lab.temporal-causality.instant)
(def agentic-ai-lab-temporal-interval-kind 'agentic-ai-lab.temporal-causality.interval)
(def agentic-ai-lab-temporal-axes-kind 'agentic-ai-lab.temporal-causality.time-axes)

(def (text? value)
  (and (string? value) (> (string-length value) 0)))

(def (slots? value names)
  (and (object? value) (every (lambda (name) (.slot? value name)) names)))

(def (instant-shape? value)
  (and (slots? value '(kind identity domain-identity coordinate
                             provenance-identity modality))
       (eq? (.ref value 'kind) agentic-ai-lab-temporal-instant-kind)
       (every text? (list (.ref value 'identity)
                          (.ref value 'domain-identity)
                          (.ref value 'provenance-identity)))
       (exact-integer? (.ref value 'coordinate))
       (>= (.ref value 'coordinate) 0)
       (symbol? (.ref value 'modality))))

(define-type (AgenticAILabTemporalInstant @ Type.)
  .element?: instant-shape?)
(def (agentic-ai-lab-temporal-instant? value)
  (element? AgenticAILabTemporalInstant value))

(def (interval-shape? value)
  (and (slots? value '(kind identity start end start-closed? end-closed?))
       (eq? (.ref value 'kind) agentic-ai-lab-temporal-interval-kind)
       (text? (.ref value 'identity))
       (agentic-ai-lab-temporal-instant? (.ref value 'start))
       (agentic-ai-lab-temporal-instant? (.ref value 'end))
       (equal? (.ref (.ref value 'start) 'domain-identity)
               (.ref (.ref value 'end) 'domain-identity))
       (<= (.ref (.ref value 'start) 'coordinate)
           (.ref (.ref value 'end) 'coordinate))
       (boolean? (.ref value 'start-closed?))
       (boolean? (.ref value 'end-closed?))))

(define-type (AgenticAILabTemporalInterval @ Type.)
  .element?: interval-shape?)
(def (agentic-ai-lab-temporal-interval? value)
  (element? AgenticAILabTemporalInterval value))

;;; An event may have only some axes. The role is given by its slot, and no
;;; relation among event, ingress and processing coordinates is inferred.
(def (axes-shape? value)
  (and (slots? value '(kind identity event-instant ingress-instant
                             processing-instant))
       (eq? (.ref value 'kind) agentic-ai-lab-temporal-axes-kind)
       (text? (.ref value 'identity))
       (let ((axes (list (.ref value 'event-instant)
                         (.ref value 'ingress-instant)
                         (.ref value 'processing-instant))))
         (and (ormap agentic-ai-lab-temporal-instant? axes)
              (every (lambda (axis)
                       (or (not axis) (agentic-ai-lab-temporal-instant? axis)))
                     axes)))))

(define-type (AgenticAILabTemporalAxes @ Type.)
  .element?: axes-shape?)
(def (agentic-ai-lab-temporal-axes? value)
  (element? AgenticAILabTemporalAxes value))
