;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: config-session syntax aggregates the session module macro facade
;;; while keeping category/module configuration separate from runtime state.
;;; Invariant: this owner must preserve the compact init/config shape expected
;;; by the module loader.
(import :agentic-ai-lab/modules/session/config-session-runtime
        :agentic-ai-lab/modules/session/config-session-syntax-core
        :agentic-ai-lab/modules/session/config-session-syntax-communication
        :agentic-ai-lab/modules/session/config-session-syntax-selector
        :agentic-ai-lab/modules/session/config-session-syntax-agent)

(export (import: :agentic-ai-lab/modules/session/config-session-runtime)
        (import: :agentic-ai-lab/modules/session/config-session-syntax-core)
        (import: :agentic-ai-lab/modules/session/config-session-syntax-communication)
        (import: :agentic-ai-lab/modules/session/config-session-syntax-selector)
        (import: :agentic-ai-lab/modules/session/config-session-syntax-agent))
