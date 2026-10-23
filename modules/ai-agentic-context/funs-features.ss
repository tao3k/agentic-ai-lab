;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Pure profile qualification through the existing Feature resolver.
(import :yuanxu/feature-system/feature-manifest "objects.ss")
(export agentic-ai-lab-ai-agentic-context-profile)
(def (agentic-ai-lab-ai-agentic-context-profile memory?)
  (unless (boolean? memory?)
    (error "Context Feature selections must be Boolean values"))
  (require-valid-feature-manifest-bundle
    (feature-manifest-bundle 'ai-agentic-context
      (append (list ai-agentic-context-core-feature)
        (if memory? (list ai-agentic-context-memory-feature) '())))))
