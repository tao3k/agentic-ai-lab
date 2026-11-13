;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream sandbox durable placement case.
;;; Invariant: pure profile declaration; sandbox execution stays in runtime.

(import :clan/poo/object
        :tao3k/agentic-ai-lab/modules/sandbox-core/profile
        :tao3k/agentic-ai-lab/modules/sandbox-core/profile-interface
        :tao3k/agentic-ai-lab/modules/nono-sandbox/config
        :tao3k/agentic-ai-lab/modules/nono-sandbox/profile-interface
        :tao3k/agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy
        "../profiles/all")

(export agentic-ai-lab-custom-my-module-sandbox-durable-case)

(def agentic-ai-lab-custom-my-module-sandbox-durable-case
  (let ((durable-build-metadata
       '((intent . durable-sandbox-build)
         (scope . custom-module)
         (durable-policy . durable/default)
         (runtime-executed . #f))))
  (let ()
    (.def (agent/durable-build @ nono-sandbox-profile
                               network capabilities resources metadata)
      network: (deny-network)
      capabilities: '(process-run filesystem-read filesystem-write tmpdir)
      resources: =>.+ readwrite-project-workspace-resources
      metadata: => (lambda (super-metadata)
                     (append super-metadata durable-build-metadata)))
    (agentic-ai-lab-product-use-module 'nono-sandbox
      (agentic-ai-lab-nono-sandbox-config-flags 'ffi (agentic-ai-lab-sandbox-profile-prototypes (agent/durable-build agent/durable-build))
        '((binding ffi)
(.def (agent/durable-build @ nono-sandbox-profile
                               network capabilities resources metadata)
      network: (deny-network)
      capabilities: '(process-run filesystem-read filesystem-write tmpdir)
      resources: =>.+ readwrite-project-workspace-resources
      metadata: => (lambda (super-metadata)
                     (append super-metadata durable-build-metadata)))))))))
