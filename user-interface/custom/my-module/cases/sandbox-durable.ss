;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream sandbox durable placement case.
;;; Invariant: pure profile declaration; sandbox execution stays in runtime.

(import :poo-flow/modules/workflow/scenario/configuration/init-syntax
        "../profiles/all")

(export poo-flow-custom-my-module-sandbox-durable-case)

(def poo-flow-custom-my-module-sandbox-durable-case
  (let ((durable-build-metadata
       '((intent . durable-sandbox-build)
         (scope . custom-module)
         (durable-policy . durable/default)
         (runtime-executed . #f))))
  (use-module nono-sandbox
    (binding native-ffi)

    (.def (agent/durable-build @ nono-sandbox-profile
                               network capabilities resources metadata)
      network: (deny-network)
      capabilities: '(process-run filesystem-read filesystem-write tmpdir)
      resources: =>.+ readwrite-project-workspace-resources
      metadata: => (lambda (super-metadata)
                     (append super-metadata durable-build-metadata))))))
