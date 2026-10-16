;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: modules enabled by the upstream kernel profile.
;;; Invariant: every module owns its default flags and bundle in config.ss;
;;; this profile only composes those module-owned values.

(import (only-in :poo-flow/modules/funflow/config
                 poo-flow-funflow-cicd-default-payload
                 poo-flow-funflow-module-bundles
                 poo-upstream-flow-funflow-module-bundles)
        (only-in :poo-flow/modules/session/config
                 +poo-flow-session-default-flags+
                 poo-flow-session-module-bundles)
        (only-in :poo-flow/modules/governor/config
                 poo-flow-loop-governor-module-bundles)
        (only-in :poo-flow/modules/nono-sandbox/config
                 poo-flow-nono-sandbox-module-bundles)
        (only-in :poo-flow/modules/cubeSandbox/config
                 poo-flow-cubeSandbox-module-bundles)
        (only-in :poo-flow/modules/docker-sandbox/config
                 poo-flow-docker-sandbox-module-bundles))

(export poo-flow-funflow-cicd-default-payload
        poo-flow-kernel-module-bundles
        poo-flow-funflow-module-bundles
        poo-upstream-flow-funflow-module-bundles
        +poo-flow-session-default-flags+
        poo-flow-session-module-bundles
        poo-flow-loop-governor-module-bundles
        poo-flow-nono-sandbox-module-bundles
        poo-flow-cubeSandbox-module-bundles
        poo-flow-docker-sandbox-module-bundles)

(def poo-flow-kernel-module-bundles
  (append poo-flow-funflow-module-bundles
          poo-flow-session-module-bundles
          poo-flow-loop-governor-module-bundles
          poo-flow-nono-sandbox-module-bundles
          poo-flow-cubeSandbox-module-bundles
          poo-flow-docker-sandbox-module-bundles))
