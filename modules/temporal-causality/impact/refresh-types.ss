;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/types
                 agentic-ai-lab-temporal-impact-contrast?))
(export AgenticAILabTemporalImpactRefresh agentic-ai-lab-temporal-impact-refresh?)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (refresh-shape? value)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot))
              '(kind identity semantic-digest previous-contrast
                     revised-contrast left-delta-digest right-delta-digest
                     revised-left-series-digest revised-right-series-digest
                     action reason causal-impact-admitted?
                     runtime-executed?))
       (eq? (.ref value 'kind) 'agentic-ai-lab.temporal-causality.impact-refresh)
       (every text? (map (lambda (slot) (.ref value slot))
                         '(identity semantic-digest left-delta-digest
                           right-delta-digest revised-left-series-digest
                           revised-right-series-digest)))
       (agentic-ai-lab-temporal-impact-contrast? (.ref value 'previous-contrast))
       (or (not (.ref value 'revised-contrast))
           (agentic-ai-lab-temporal-impact-contrast? (.ref value 'revised-contrast)))
       (memq (.ref value 'action) '(reused recomputed blocked))
       (memq (.ref value 'reason)
             '(unchanged source-version scope-mismatch grid-mismatch))
       (eq? (.ref value 'causal-impact-admitted?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))
(define-type (AgenticAILabTemporalImpactRefresh @ Type.)
  .element?: refresh-shape?)
(def (agentic-ai-lab-temporal-impact-refresh? value)
  (element? AgenticAILabTemporalImpactRefresh value))
