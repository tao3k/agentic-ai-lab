;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox-core object aggregate.
;;; Invariant: sandbox-core is a developer-owned object namespace, not a module row.

(import :agentic-ai-lab/modules/sandbox-core/profile)

(export (import: :agentic-ai-lab/modules/sandbox-core/profile)
        agentic-ai-lab-sandbox-core-module-objects)

;; : [PooModuleObject]
(def agentic-ai-lab-sandbox-core-module-objects
  (list agentic-ai-lab-sandbox-core-profile-object))
