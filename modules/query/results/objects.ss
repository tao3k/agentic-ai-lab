;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in "types.ss"
                 AgenticAILabQueryResultCell AgenticAILabQueryResultRow
                 AgenticAILabQueryResultSet))
(export AgenticAILabQueryResultCell. AgenticAILabQueryResultRow.
        AgenticAILabQueryResultSet.
        agentic-ai-lab-query-result-cell-value
        agentic-ai-lab-query-result-row-value
        agentic-ai-lab-query-result-set-value)

(def AgenticAILabQueryResultCell.
  (.o kind: 'agentic-ai-lab.query.result-cell
      semantic-digest: #f field: #f value: #f))
(def AgenticAILabQueryResultRow.
  (.o kind: 'agentic-ai-lab.query.result-row
      semantic-digest: #f identity: #f cells: '()))
(def AgenticAILabQueryResultSet.
  (.o kind: 'agentic-ai-lab.query.result-set
      identity: #f semantic-digest: #f
      query-identity: #f query-version: #f semantic-revision: #f
      result-contract-identity: #f rows: '()
      result-count: 0 result-digest: #f complete?: #f))

(def (agentic-ai-lab-query-result-cell-value digest-value field-value scalar-value)
  (validate
   AgenticAILabQueryResultCell
   (.o (:: @ AgenticAILabQueryResultCell.)
       semantic-digest: digest-value
       field: field-value value: scalar-value)))

(def (agentic-ai-lab-query-result-row-value digest-value id-value cells-value)
  (validate
   AgenticAILabQueryResultRow
   (.o (:: @ AgenticAILabQueryResultRow.)
       semantic-digest: digest-value
       identity: id-value cells: cells-value)))

(def (agentic-ai-lab-query-result-set-value
      id-value query-value version-value revision-value contract-value
      rows-value count-value digest-value complete-value)
  (validate
   AgenticAILabQueryResultSet
   (.o (:: @ AgenticAILabQueryResultSet.)
       identity: id-value semantic-digest: digest-value
       query-identity: query-value query-version: version-value
       semantic-revision: revision-value
       result-contract-identity: contract-value
       rows: rows-value result-count: count-value
       result-digest: digest-value complete?: complete-value)))
