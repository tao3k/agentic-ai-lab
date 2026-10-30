;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: agent-sandbox request facade lives here.
;;; Boundary:
;;; - Field contracts, builders, validation, macro sugar, and task accessors
;;;   stay in separate request-specific owners.
;;; - This facade preserves the public import surface for extension users.
;;; Runtime contract:
;;; - Importing this module performs no request validation or backend work.
;;; Policy evidence:
;;; - Agent-sandbox descriptor, bridge, and profile tests import this facade.

(import :agentic-ai-lab/modules/agent-sandbox/request-field
        :agentic-ai-lab/modules/agent-sandbox/request-validation
        :agentic-ai-lab/modules/agent-sandbox/request-builder
        :agentic-ai-lab/modules/agent-sandbox/request-macro
        :agentic-ai-lab/modules/agent-sandbox/request-accessor)

(export (import: :agentic-ai-lab/modules/agent-sandbox/request-field)
        (import: :agentic-ai-lab/modules/agent-sandbox/request-validation)
        (import: :agentic-ai-lab/modules/agent-sandbox/request-builder)
        (import: :agentic-ai-lab/modules/agent-sandbox/request-macro)
        (import: :agentic-ai-lab/modules/agent-sandbox/request-accessor))
