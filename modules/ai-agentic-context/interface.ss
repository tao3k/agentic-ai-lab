;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(.def Context
  identity: 'ai-agentic-context
  tags: '(context)
  core:
  (.o requires: (.o)
      scope-contract: ContextScopeContract
      exports: (.o config: Config profile: ContextCoreProfile))
  features:
  (.o memory: (.o refine: EnableMemory contract: ContextMemoryScopeContract)))
