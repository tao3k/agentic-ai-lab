;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (only-in :agentic-ai-lab/modules/services/opentofu/execution NullExecution.))
(export Scenario)
;; The scenario reuses the service recipe; it owns no second Null implementation.
(def Scenario NullExecution.)
