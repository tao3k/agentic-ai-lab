(import (only-in :agentic-ai-lab/modules/workflow/funflow-config agentic-ai-lab-funflow-module-bundles poo-upstream-flow-funflow-module-bundles))
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: modules enabled by the upstream kernel profile.
;;; Invariant: every module owns its default flags and bundle in config.ss;
;;; this profile only composes those module-owned values.

(import (only-in :yuanxu/modules/funflow/graph-projection
                 yuanxu-funflow-cicd-default-payload)
        (only-in :agentic-ai-lab/modules/session/config
                 +agentic-ai-lab-session-default-flags+
                 agentic-ai-lab-session-module-bundles)
        (only-in :agentic-ai-lab/modules/governor/config
                 agentic-ai-lab-loop-governor-module-bundles)
        (only-in :agentic-ai-lab/modules/nono-sandbox/config
                 agentic-ai-lab-nono-sandbox-module-bundles)
        (only-in :agentic-ai-lab/modules/cubeSandbox/config
                 agentic-ai-lab-cubeSandbox-module-bundles)
        (only-in :agentic-ai-lab/modules/docker-sandbox/config
                 agentic-ai-lab-docker-sandbox-module-bundles))

(export yuanxu-funflow-cicd-default-payload
        agentic-ai-lab-kernel-module-bundles
        agentic-ai-lab-funflow-module-bundles
        poo-upstream-flow-funflow-module-bundles
        +agentic-ai-lab-session-default-flags+
        agentic-ai-lab-session-module-bundles
        agentic-ai-lab-loop-governor-module-bundles
        agentic-ai-lab-nono-sandbox-module-bundles
        agentic-ai-lab-cubeSandbox-module-bundles
        agentic-ai-lab-docker-sandbox-module-bundles)

(def agentic-ai-lab-kernel-module-bundles
  (append agentic-ai-lab-funflow-module-bundles
          agentic-ai-lab-session-module-bundles
          agentic-ai-lab-loop-governor-module-bundles
          agentic-ai-lab-nono-sandbox-module-bundles
          agentic-ai-lab-cubeSandbox-module-bundles
          agentic-ai-lab-docker-sandbox-module-bundles))
