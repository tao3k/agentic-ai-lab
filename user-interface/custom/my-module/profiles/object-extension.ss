;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream POO object slot-operator example.
;;; Invariant: standalone module; it declares extension data only.

(import :clan/poo/object
        :tao3k/agentic-ai-lab/modules/sandbox-core/profile
        :tao3k/agentic-ai-lab/modules/sandbox-core/profile-interface
        :tao3k/agentic-ai-lab/modules/nono-sandbox/config
        :tao3k/agentic-ai-lab/modules/nono-sandbox/profile-interface
        :tao3k/agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy)

(export agentic-ai-lab-custom-my-module-object-extension-module)

(def agentic-ai-lab-custom-my-module-object-extension-module
  (let ((object-extension-capabilities
       '(process-run filesystem-read tmpdir cache-mount artifact-cache))
      (object-extension-mounts
       '(((path . "/workspace/project")
          (role . project-workspace)
          (source . ".")
          (project-marker . "gerbil.pkg")
          (target . "/workspace/project")
          (mode . read-write)
          (purpose . project-source))
         ((path . "/workspace/project/.data")
          (source . ".data")
          (target . "/workspace/project/.data")
          (mode . read)
          (purpose . research-checkouts))
         ((path . "/workspace/cache")
          (source . ".cache/agent-semantic-protocol")
          (target . "/workspace/cache")
          (mode . read-write)
          (purpose . semantic-cache))
         ((path . "/workspace/config")
          (source . "user-interface/custom/my-module")
          (target . "/workspace/config")
          (mode . read)
          (purpose . user-config))
         ((path . "/run/secrets")
          (source-kind . env)
          (source . "$AGENTIC_AI_LAB_AGENT_SECRETS")
          (target . "/run/secrets")
          (mode . read)
          (purpose . credentials))))
      (object-extension-metadata
       '((intent . poo-object-extension)
         (scope . demo)
         (poo-object . objects.nono-sandbox.profile)
         (slot-operators . (override append remove))
         (authoring-style . runtime-gerbil-poo))))
  (let* ((object-extension-filesystem
          (.o (:: @ readwrite-project-workspace-filesystem)
              mounts: 'declared))
         (object-extension-resources
          (.o (:: @ readwrite-project-workspace-resources)
              filesystem: object-extension-filesystem
              mounts: object-extension-mounts)))
    (let ()
    (.def (agent/poo-object-extension @ nono-sandbox-profile)
        network: (allowlisted-network "github.com" "crates.io")
        capabilities: object-extension-capabilities
        resources: =>.+ object-extension-resources
        metadata: => (lambda (super-metadata)
                       (append super-metadata object-extension-metadata)))
    (agentic-ai-lab-product-use-module 'nono-sandbox
      (agentic-ai-lab-nono-sandbox-config-flags 'ffi (agentic-ai-lab-sandbox-profile-prototypes (agent/poo-object-extension agent/poo-object-extension))
        '((.def (agent/poo-object-extension @ nono-sandbox-profile)
        network: (allowlisted-network "github.com" "crates.io")
        capabilities: object-extension-capabilities
        resources: =>.+ object-extension-resources
        metadata: => (lambda (super-metadata)
                       (append super-metadata object-extension-metadata))))))))))
