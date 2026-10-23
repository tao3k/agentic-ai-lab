;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CubeSandbox module objects.

(import :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/sandbox-core/shared-object
        :agentic-ai-lab/modules/sandbox-core/backend-object-syntax
        :agentic-ai-lab/modules/sandbox-core/objects
        :agentic-ai-lab/modules/sandbox-core/resource-contract)

(export agentic-ai-lab-cubeSandbox-object
        agentic-ai-lab-cubeSandbox-backend-capability
        agentic-ai-lab-cubeSandbox-backend-capability-registry
        agentic-ai-lab-cubeSandbox-profile-object
        agentic-ai-lab-cubeSandbox-module-objects)

;;; CubeSandbox object data names backend defaults only; adapter execution and
;;; snapshot materialization stay outside this module.
(defpoo-sandbox-backend-object-family
  agentic-ai-lab-cubeSandbox-object
  agentic-ai-lab-cubeSandbox-backend-capability
  agentic-ai-lab-cubeSandbox-backend-capability-registry
  agentic-ai-lab-cubeSandbox-profile-object
  agentic-ai-lab-cubeSandbox-module-objects
  (sandbox objects.cubeSandbox.sandbox
           objects.cubeSandbox
           objects.shared.sandbox
           ((backend YuanxuModuleSymbolType override 'cube '((scope . cubeSandbox)))
            (profile YuanxuModuleSymbolType override 'default '((scope . cubeSandbox)))))
  (backend cube
           agentic-ai-lab-sandbox-backend-capability/cube
           '((aliases . ((cubeSandbox . cube)))
             (metadata . ((scope . cubeSandbox)
                          (runtime-executed . #f)))))
  (profile objects.cubeSandbox.profile
           cubeSandbox
           objects.sandbox-core.profile
           (agentic-ai-lab-sandbox-core-profile-object
            agentic-ai-lab-cubeSandbox-object)
           ((backend-kind YuanxuModuleSymbolType override 'cube
                          '((scope . cubeSandbox)
                            (owned-by . module-config)))
            (backend-ref YuanxuModuleSymbolType override 'cubeSandbox
                         '((scope . cubeSandbox)
                           (owned-by . module-config)))
            (capabilities YuanxuModuleListType override
                          '(process-run filesystem-read cache-mount)
                          '((scope . cubeSandbox)
                            (dsl-row . capabilities)))
            (backend-capability YuanxuModuleObjectType override
                                agentic-ai-lab-cubeSandbox-backend-capability
                                '((scope . cubeSandbox)
                                  (owned-by . module-config)))
            (resource-policy YuanxuModuleListType override
                             (agentic-ai-lab-sandbox-filesystem-prototype->resource-policy
                              agentic-ai-lab-snapshot-filesystem-prototype)
                             '((scope . cubeSandbox)
                               (dsl-row . resources))))))
