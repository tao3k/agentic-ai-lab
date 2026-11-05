;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(def Config
  (.o profiles:
      (list
        (.o name: 'agent/nono backend-kind: 'nono backend-ref: 'nono
            capabilities: '(process-run filesystem-read filesystem-write tmpdir)
            resource-policy:
            '((filesystem (scope . project-workspace)
                          (paths ((role . project-workspace) (source . ".")
                                  (project-marker . "gerbil.pkg") (mode . read-write)))
                          (access . read-write))
              (cpu . 2) (memory . "4Gi") (timeout-ms . 300000)))
        (.o name: 'agent/cube backend-kind: 'cube backend-ref: 'cube-local
            network-policy: '(allowlisted "github.com" "crates.io")
            capabilities: '(process-run filesystem-read cache-mount)
            resource-policy:
            '((filesystem (scope . snapshot) (snapshot . clone) (access . read-only))
              (cpu . 4) (memory . "8Gi") (timeout-ms . 600000))))))
