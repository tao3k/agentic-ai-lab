;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/types
                 agentic-ai-lab-temporal-trajectory-series?))
(export AgenticAILabTemporalTrajectoryDelta agentic-ai-lab-temporal-trajectory-delta?)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (coordinates? value)
  (and (list? value)
       (every (lambda (item) (and (exact-integer? item) (>= item 0))) value)))
(def (delta-shape? value)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot))
              '(kind identity semantic-digest previous-series revised-series
                     previous-series-digest revised-series-digest
                     previous-cut-digest revised-cut-digest
                     previous-projection-digest revised-projection-digest
                     added-coordinates removed-coordinates changed-coordinates
                     status))
       (eq? (.ref value 'kind) 'agentic-ai-lab.temporal-causality.trajectory-delta)
       (every text? (map (lambda (slot) (.ref value slot))
                         '(identity semantic-digest previous-series-digest
                           revised-series-digest previous-cut-digest
                           revised-cut-digest previous-projection-digest
                           revised-projection-digest)))
       (agentic-ai-lab-temporal-trajectory-series? (.ref value 'previous-series))
       (agentic-ai-lab-temporal-trajectory-series? (.ref value 'revised-series))
       (every coordinates?
              (list (.ref value 'added-coordinates)
                    (.ref value 'removed-coordinates)
                    (.ref value 'changed-coordinates)))
       (memq (.ref value 'status)
             '(unchanged identity-only scope-change sample-change
                         sample-and-scope-change))))
(define-type (AgenticAILabTemporalTrajectoryDelta @ Type.)
  .element?: delta-shape?)
(def (agentic-ai-lab-temporal-trajectory-delta? value)
  (element? AgenticAILabTemporalTrajectoryDelta value))
