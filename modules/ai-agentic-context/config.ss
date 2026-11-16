;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(def Config (.o))

;;; Public operations are selected through this Module's init.exports scope.
(import "types.ss" "objects.ss" "funs-scope.ss" "org-contract/elements.ss")
(export ContextOperations)
(def ContextOperations
  (.o admit-scope: agentic-ai-lab-ai-agentic-context-scope-admit
      admission-type: AiAgenticContextAdmissionType
      scope-prototype: AiAgenticContextScope.
      scope-shape?: agentic-ai-lab-ai-agentic-context-scope-shape?
      org-source: context-org-source))
