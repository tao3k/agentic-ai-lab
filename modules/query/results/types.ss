;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Finite scalar relation rows. Rich graph values need a separate profile.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop Type. define-type element?)
        (only-in :std/list/list every))
(export AgenticAILabQueryResultCell AgenticAILabQueryResultRow AgenticAILabQueryResultSet
        agentic-ai-lab-query-result-cell? agentic-ai-lab-query-result-row?
        agentic-ai-lab-query-result-set?)

(def (identity? value)
  (or (symbol? value)
      (and (string? value) (> (string-length value) 0))))
(def (scalar? value)
  (or (string? value) (symbol? value) (boolean? value)
      (and (number? value) (exact? value))))
(def (slots? value names)
  (and (object? value)
       (every (lambda (name) (.slot? value name)) names)))
(def (common? value tag names)
  (and (slots? value (append '(kind semantic-digest) names))
       (eq? (.ref value 'kind) tag)
       (identity? (.ref value 'semantic-digest))))

(def (cell-shape? value)
  (and (common? value 'agentic-ai-lab.query.result-cell '(field value))
       (symbol? (.ref value 'field))
       (scalar? (.ref value 'value))))
(define-type (AgenticAILabQueryResultCell @ Type.) .element?: cell-shape?)
(def (agentic-ai-lab-query-result-cell? value)
  (element? AgenticAILabQueryResultCell value))

(def (row-shape? value)
  (and (common? value 'agentic-ai-lab.query.result-row '(identity cells))
       (identity? (.ref value 'identity))
       (list? (.ref value 'cells))
       (every agentic-ai-lab-query-result-cell? (.ref value 'cells))))
(define-type (AgenticAILabQueryResultRow @ Type.) .element?: row-shape?)
(def (agentic-ai-lab-query-result-row? value)
  (element? AgenticAILabQueryResultRow value))

(def (set-shape? value)
  (and (common? value 'agentic-ai-lab.query.result-set
                '(identity query-identity query-version semantic-revision
                           result-contract-identity rows result-count
                           result-digest complete?))
       (identity? (.ref value 'identity))
       (identity? (.ref value 'query-identity))
       (identity? (.ref value 'query-version))
       (identity? (.ref value 'semantic-revision))
       (identity? (.ref value 'result-contract-identity))
       (list? (.ref value 'rows))
       (every agentic-ai-lab-query-result-row? (.ref value 'rows))
       (exact-integer? (.ref value 'result-count))
       (>= (.ref value 'result-count) 0)
       (identity? (.ref value 'result-digest))
       (boolean? (.ref value 'complete?))))
(define-type (AgenticAILabQueryResultSet @ Type.) .element?: set-shape?)
(def (agentic-ai-lab-query-result-set? value)
  (element? AgenticAILabQueryResultSet value))
