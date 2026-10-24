;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Agentic AI Lab metadata validation around parser-owned GQL projection.
;;; Gerbil Parser owns the syntax graph and source renderer; this module only
;;; adapts a governed Agentic AI Lab Query to that language boundary.
(import (only-in :clan/poo/object .ref)
        (only-in :gerbil-parser/src/modules/parser/graph-syntax
                 graph-syntax-program->source)
        (only-in "objects.ss" agentic-ai-lab-gql-query-program?))

(export agentic-ai-lab-query-program->gql
        agentic-ai-lab-query->gql)

(def (agentic-ai-lab-query-program->gql program)
  (unless (agentic-ai-lab-gql-query-program? program)
    (error "invalid POO GQL query program" program))
  (graph-syntax-program->source program))

(def (agentic-ai-lab-query->gql query)
  (agentic-ai-lab-query-program->gql (.ref query 'program)))
