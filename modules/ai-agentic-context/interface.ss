;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o)
        "types.ss" "config.ss" "objects.ss")
(export Context)

(.def Context
  identity: 'ai-agentic-context
  tags: '(context)
  core:
  (.o scope-contract: ContextScopeContract
      exports: (.o (:: @ ContextOperations) config: Config profile: ContextCoreProfile))
  features: '(memory worktree work worktrunk durable))
