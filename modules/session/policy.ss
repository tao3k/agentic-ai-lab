;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Policy Facade Boundary
;;;
;;; This file intentionally exports the stable policy surface only. Concrete
;;; policy object construction, tool grants, reusable families, and permission
;;; projections live in the split submodules so policy users keep one import
;;; path while the implementation stays below the source-owner modularity gate.

(import :tao3k/agentic-ai-lab/modules/session/policy-core
        :tao3k/agentic-ai-lab/modules/session/policy-tool-grant
        :tao3k/agentic-ai-lab/modules/session/policy-families
        :tao3k/agentic-ai-lab/modules/session/policy-permissions)

(export
  (import: :tao3k/agentic-ai-lab/modules/session/policy-core)
  (import: :tao3k/agentic-ai-lab/modules/session/policy-tool-grant)
  (import: :tao3k/agentic-ai-lab/modules/session/policy-families)
  (import: :tao3k/agentic-ai-lab/modules/session/policy-permissions))
