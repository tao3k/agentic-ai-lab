;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: nono sandbox module objects.

(import :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/sandbox-core/shared-object
        :agentic-ai-lab/modules/sandbox-core/backend-object-syntax
        :agentic-ai-lab/modules/sandbox-core/objects
        :agentic-ai-lab/modules/sandbox-core/resource-contract)

(export agentic-ai-lab-nono-sandbox-object
        agentic-ai-lab-nono-sandbox-backend-capability
        agentic-ai-lab-nono-sandbox-backend-capability-registry
        agentic-ai-lab-nono-sandbox-profile-object
        agentic-ai-lab-nono-sandbox-module-objects)

;;; Nono sandbox object data names the backend family and native binding
;;; default; native calls remain in their dedicated owner.
(defpoo-sandbox-backend-object-family
  agentic-ai-lab-nono-sandbox-object
  agentic-ai-lab-nono-sandbox-backend-capability
  agentic-ai-lab-nono-sandbox-backend-capability-registry
  agentic-ai-lab-nono-sandbox-profile-object
  agentic-ai-lab-nono-sandbox-module-objects
  (sandbox objects.nono-sandbox.sandbox
           objects.nono-sandbox
           objects.shared.sandbox
           ((backend YuanxuModuleSymbolType override 'nono '((scope . nono-sandbox)))
            (binding YuanxuModuleSymbolType override 'native-ffi '((scope . nono-sandbox)))))
  (backend nono
           agentic-ai-lab-sandbox-backend-capability/nono
           '((metadata . ((scope . nono-sandbox)
                          (runtime-executed . #f)))))
  (profile objects.nono-sandbox.profile
           nono-sandbox
           objects.nono-sandbox.sandbox
           (agentic-ai-lab-sandbox-core-profile-object
            agentic-ai-lab-nono-sandbox-object)
           ((profile-name YuanxuModuleSymbolType override 'default
                          '((scope . nono-sandbox)
                            (dsl-row . profile-name)))
            (backend-kind YuanxuModuleSymbolType override 'nono
                          '((scope . nono-sandbox)
                            (owned-by . module-config)))
            (backend-ref YuanxuModuleSymbolType override 'nono-sandbox
                         '((scope . nono-sandbox)
                           (owned-by . module-config)))
            (network-policy YuanxuModuleListType override '(deny-by-default)
                            '((scope . nono-sandbox)
                              (dsl-row . network)))
            (capabilities YuanxuModuleListType override '(process filesystem tmpdir)
                          '((scope . nono-sandbox)
                            (dsl-row . capabilities)))
            (backend-capability YuanxuModuleObjectType override
                                agentic-ai-lab-nono-sandbox-backend-capability
                                '((scope . nono-sandbox)
                                  (owned-by . module-config)))
            (resource-policy YuanxuModuleListType override
                             (agentic-ai-lab-sandbox-filesystem-prototype->resource-policy
                              agentic-ai-lab-runtime-filesystem-prototype)
                             '((scope . nono-sandbox)
                               (dsl-row . resources)))
            (metadata YuanxuModuleListType append '()
                      '((scope . nono-sandbox)
                        (dsl-row . metadata))))))
