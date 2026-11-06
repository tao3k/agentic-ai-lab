;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/type Record)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/types ContextScopeContract))
(export ReviewScopeContract)
(def ReviewScopeContract
  (.cc (Record context: [ContextScopeContract]) identity: 'review/scope))
