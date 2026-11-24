;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o)
        (only-in :tao3k/yuanxu/module-system/convergence/types make-slot-spec)
        (only-in "./config.ss" DurableConfig)
        (only-in "./types.ss" DurableScopeContract)
        (only-in "./func.ss" durable-recovery-decision DurableWorkExports)
        "policy.ss")
(export Durable (import: "policy.ss"))

(.def Durable
  identity: 'durable
  tags: '(engine policy durable)
  slot-specs:
  (list (make-slot-spec 'detour-state
                        stage: 'runtime
                        combiner: 'exclusive
                        default: 'none
                        allowed: '(none blocker-active side-quest-active)))
  defaults: (.o detour-state: 'none)
  core:
  (.o scope-contract: DurableScopeContract
      exports: (.o recovery-policy: DurableConfig
                   decide-recovery: durable-recovery-decision
                   work: DurableWorkExports))
  features: '())
