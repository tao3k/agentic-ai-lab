;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream session sandbox profile declarations.
;;; Invariant: standalone module; it declares data only.

(import :poo-flow/modules/workflow/scenario/configuration/init-syntax)

(export poo-flow-custom-my-module-session-module)

(def poo-flow-custom-my-module-session-module
  (let ((session-capabilities
       '(process-run filesystem-read tmpdir cache-mount))
      (session-metadata
       '((intent . coding-agent)
         (scope . session)
         (stage . interactive))))
  (use-module nono-sandbox
    (.def (agent/session @ nono-sandbox-profile)
      network: (allowlisted-network "github.com" "crates.io")
      capabilities: session-capabilities
      resources: =>.+ runtime-volume-resources
      metadata: => (lambda (super-metadata)
                     (append super-metadata session-metadata))))))
