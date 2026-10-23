;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session configuration facade.
;;; Invariant: configuration composes the module-owned syntax surface only.

(import "syntax.ss" "descriptor.ss"
        :yuanxu/module-system/selection/objects)
(export (import: "syntax.ss") (import: "descriptor.ss")
        agentic-ai-lab-session-module-bundles)

;;; Independent Session selection uses its own module identity.
(def agentic-ai-lab-session-module-bundles
  (list (yuanxu-user-module-bundle
          (session session +lineage +placement +handoff +graph +transform +doctor))))
