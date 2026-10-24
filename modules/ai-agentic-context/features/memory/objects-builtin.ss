;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: builtin memory stores and default catalog.

(import :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-core
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-catalog)

(export agentic-ai-lab-ai-agentic-context-memory-local-session-store
        agentic-ai-lab-ai-agentic-context-memory-durable-project-store
        agentic-ai-lab-ai-agentic-context-memory-default-catalog)

(def agentic-ai-lab-ai-agentic-context-memory-local-session-store
  (agentic-ai-lab-memory-store-spec
   'memory/local-session
   'local-session
   'session
   '(current-session parent-summary)
   '(read-latest read-summary)
   '(none ephemeral)
   "marlin-agent-core"
   'memory/local-session-handoff
   #f
   'marlin-memory-adapter
   '((builtin . #t))))

(def agentic-ai-lab-ai-agentic-context-memory-durable-project-store
  (agentic-ai-lab-memory-store-spec
   'memory/durable-project
   'durable-project
   'project
   '(current-session parent-summary project)
   '(semantic-search exact-key read-summary)
   '(append review-only)
   "marlin-agent-core"
   'memory/durable-project-handoff
   #t
   'marlin-memory-adapter
   '((builtin . #t))))

(def agentic-ai-lab-ai-agentic-context-memory-default-catalog
  (agentic-ai-lab-memory-catalog
   'memory-core/default
   (list agentic-ai-lab-ai-agentic-context-memory-local-session-store
         agentic-ai-lab-ai-agentic-context-memory-durable-project-store)
   '((source . agentic-ai-lab-memory-core)
     (runtime-executed . #f))))
