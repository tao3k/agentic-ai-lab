;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Domain inputs for an inert control-plane preview. Module loading is init's job.
(import (only-in :tao3k/yuanxu/module-system/selection/objects
                 yuanxuUserConfig yuanxu-settings yuanxu-user-module-selection
                 yuanxu-user-custom-module-selection yuanxu-user-module-bundles-extend
                 yuanxu-user-module-bundles->modules)
        (only-in :tao3k/agentic-ai-lab/modules/workflow/profiles/kernel/bundles
                 agentic-ai-lab-kernel-module-bundles))
(def Config
  (yuanxuUserConfig
    (yuanxu-user-module-bundles->modules
      (yuanxu-user-module-bundles-extend agentic-ai-lab-kernel-module-bundles
        (list
          (list (yuanxu-user-module-selection 'flow 'funflow
                   '(+functional +dag +typed-receipts +runtime-manifest
                     (+cicd (checks +parallel +typed-receipts) (artifacts +export)
                            (release +manual-gate) (webhook +server) (runtime +manifest-handoff)))))
          (list (yuanxu-user-module-selection 'flow 'loop-engine '()))
          (list (yuanxu-user-module-selection 'sandbox 'nono-sandbox '(+nono +doctor)))
          (list (yuanxu-user-module-selection 'sandbox 'cubeSandbox '(+cube +doctor)))
          (list (yuanxu-user-custom-module-selection 'my-module "./custom/my-module" '(+private +doctor))))))
    (yuanxu-settings surface: "agentic-ai-lab" profile: "users" flow-mode: 'funflow
                    loop-strategy: 'governed sandbox-policy: 'module-gated
                    sandbox-backends: '(nono cube docker) mode-lock: "stable")))
