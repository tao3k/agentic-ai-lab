;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: config-session agent syntax maps user authoring forms into
;;; session POO objects without crossing runtime execution boundaries.
;;; Invariant: generated agent objects must retain stable ids for parent and
;;; child session policy checks.
(import :agentic-ai-lab/modules/session/config-session-syntax-materialization
        :agentic-ai-lab/modules/session/config-session-syntax-agent-node)

(export (import: :agentic-ai-lab/modules/session/config-session-syntax-materialization)
        (import: :agentic-ai-lab/modules/session/config-session-syntax-agent-node))
