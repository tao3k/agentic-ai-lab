;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "gql.ss" "funs.ss" "contracts.ss"
        "scheme-select.ss" "scheme-graph.ss" "orgize-source.ss"
        "results/interface.ss"
        "config.ss")
(export Query
        (import: "types.ss")
        (import: "objects.ss")
        (import: "gql.ss")
        (import: "funs.ss")
        (import: "contracts.ss")
        (import: "scheme-select.ss")
        (import: "scheme-graph.ss")
        (import: "orgize-source.ss")
        (import: "results/interface.ss")
        (import: "config.ss"))

(.def Query
  identity: 'query
  tags: '(query gql)
  core: (.o scope-contract: QueryScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/query/interface))
  features: (.o))
