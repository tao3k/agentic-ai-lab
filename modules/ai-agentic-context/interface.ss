;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o)
        (only-in :tao3k/yuanxu/module-system/convergence/types make-slot-spec)
        "types.ss" "config.ss" "objects.ss")
(export Context)

(.def Context
  identity: 'ai-agentic-context
  tags: '(context org-backed)
  slot-specs:
  (list (make-slot-spec 'disclosure-mode
                        stage: 'runtime
                        combiner: 'exclusive
                        default: 'progressive
                        allowed: '(progressive detour-blocker)))
  defaults: (.o disclosure-mode: 'progressive)
  profiles:
  (.o durable.detour-state:
      (.o blocker-active:
          (.o profile-id: 'DetourBlockerContextProfile.
              disclosure-mode: 'detour-blocker)))
  core:
  (.o scope-contract: ContextScopeContract
      exports: (.o (:: @ ContextOperations) config: Config profile: ContextCoreProfile))
  features: '(memory worktree work worktrunk durable))
