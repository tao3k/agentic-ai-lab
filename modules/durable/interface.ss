;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(.def Durable
  identity: 'durable
  tags: '(engine policy)
  core:
  (.o scope-contract: DurableScopeContract
      exports: (.o recovery-policy: DurableConfig
                   decide-recovery: durable-recovery-decision
                   workspace-recovery-host: durable-workspace-recovery-host
                   agenda-start: durable-agenda-start))
  features: (.o))
