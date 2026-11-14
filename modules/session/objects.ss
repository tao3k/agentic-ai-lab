;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for report-only session dataflow objects.
;;; Invariant: lower owners keep core values, handoff receipts, and graph views
;;; separate while this module preserves the historical import path.

(import "objects-attempt.ss" :tao3k/agentic-ai-lab/modules/session/objects-core
        :tao3k/agentic-ai-lab/modules/session/objects-handoff
        :tao3k/agentic-ai-lab/modules/session/objects-graph)

(export (import: "objects-attempt.ss") (import: :tao3k/agentic-ai-lab/modules/session/objects-core)
        (import: :tao3k/agentic-ai-lab/modules/session/objects-handoff)
        (import: :tao3k/agentic-ai-lab/modules/session/objects-graph))
