;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream task sandbox profile declarations.
;;; Invariant: standalone module; it declares data only.

(import :poo-flow/modules/workflow/scenario/configuration/init-syntax)

(export poo-flow-custom-my-module-task-module)

(def poo-flow-custom-my-module-task-module
  (let ((task-capabilities
       '(process-run filesystem-read tmpdir))
      (cache-capabilities
       '(cache-mount))
      (task-metadata
       '((intent . task-sandbox)
         (stage . task)
         (runtime-executed . #f)))
      (task-cache-metadata
       '((intent . task-cache)
         (stage . task)
         (cache . cargo))))
  (let (task-cache-resources
        (.o (:: @ readonly-project-workspace-resources)
            cpu: 2
            memory: "2Gi"
            timeout-ms: 180000))
    (use-module nono-sandbox
      (.def (agent/task @ nono-sandbox-profile)
        network: (deny-network)
        capabilities: task-capabilities
        resources: =>.+ readonly-project-workspace-resources
        metadata: => (lambda (super-metadata)
                       (append super-metadata task-metadata)))

      (.def (agent/task-cache @ agent/task)
        network: (allowlisted-network "github.com")
        capabilities: => (lambda (super-capabilities)
                           (append super-capabilities cache-capabilities))
        resources: =>.+ task-cache-resources
        metadata: => (lambda (super-metadata)
                       (append super-metadata task-cache-metadata)))))))
