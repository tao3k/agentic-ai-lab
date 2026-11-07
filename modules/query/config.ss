;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; One POO entry object exposes the canonical Query surface.
(import (only-in :clan/poo/object .o)
        (only-in "objects.ss"
                 AgenticAILabQuery. AgenticAILabQueryElementSpace.
                 AgenticAILabGqlQueryLanguage. AgenticAILabSchemeGqlQueryLanguage.
                 AgenticAILabQueryResultContract.)
        (only-in "funs.ss" agentic-ai-lab-query-admit)
        (only-in "gql.ss" agentic-ai-lab-query->gql)
        (only-in "contracts.ss" agentic-ai-lab-query-bind-execution-receipt)
        (only-in "scheme-select.ss" agentic-ai-lab-query-select-scheme-nodes)
        (only-in "orgize-source.ss"
                 agentic-ai-lab-query-orgize-open-headlines
                 agentic-ai-lab-query-orgize-open-headlines-replay)
        (only-in "results/objects.ss"
                 AgenticAILabQueryResultCell. AgenticAILabQueryResultRow.
                 AgenticAILabQueryResultSet.)
        (only-in "results/funs.ss"
                 agentic-ai-lab-query-result-cell agentic-ai-lab-query-result-row
                 agentic-ai-lab-query-result-set))

(export AgenticAILabQueryModule.)

(def AgenticAILabQueryModule.
  (.o kind: 'agentic-ai-lab.query.module
      identity: 'agentic-ai-lab/modules/query
      query: AgenticAILabQuery.
      languages:
      (.o gql: AgenticAILabGqlQueryLanguage.
          scheme-gql: AgenticAILabSchemeGqlQueryLanguage.)
      element-space: AgenticAILabQueryElementSpace.
      result-contract: AgenticAILabQueryResultContract.
      result-cell: AgenticAILabQueryResultCell.
      result-row: AgenticAILabQueryResultRow.
      result-set: AgenticAILabQueryResultSet.
      providers: (.o)
      .admit-query: agentic-ai-lab-query-admit
      .project-gql: agentic-ai-lab-query->gql
      .bind-execution-receipt: agentic-ai-lab-query-bind-execution-receipt
      .select-scheme-nodes: agentic-ai-lab-query-select-scheme-nodes
      .select-orgize-open-headlines: agentic-ai-lab-query-orgize-open-headlines
      .replay-orgize-open-headlines:
      agentic-ai-lab-query-orgize-open-headlines-replay
      .result-cell: agentic-ai-lab-query-result-cell
      .result-row: agentic-ai-lab-query-result-row
      .result-set: agentic-ai-lab-query-result-set))
