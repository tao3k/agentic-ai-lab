;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CubeSandbox module objects.

(import :yuanxu/module-system/schema/interface
        :poo-flow/modules/sandbox-core/shared-object
        :poo-flow/modules/sandbox-core/backend-object-syntax
        :poo-flow/modules/sandbox-core/objects
        :poo-flow/modules/sandbox-core/resource-contract)

(export poo-flow-cubeSandbox-object
        poo-flow-cubeSandbox-backend-capability
        poo-flow-cubeSandbox-backend-capability-registry
        poo-flow-cubeSandbox-profile-object
        poo-flow-cubeSandbox-module-objects)

;;; CubeSandbox object data names backend defaults only; adapter execution and
;;; snapshot materialization stay outside this module.
(defpoo-sandbox-backend-object-family
  poo-flow-cubeSandbox-object
  poo-flow-cubeSandbox-backend-capability
  poo-flow-cubeSandbox-backend-capability-registry
  poo-flow-cubeSandbox-profile-object
  poo-flow-cubeSandbox-module-objects
  (sandbox objects.cubeSandbox.sandbox
           objects.cubeSandbox
           objects.shared.sandbox
           ((backend YuanxuModuleSymbolType override 'cube '((scope . cubeSandbox)))
            (profile YuanxuModuleSymbolType override 'default '((scope . cubeSandbox)))))
  (backend cube
           poo-flow-sandbox-backend-capability/cube
           '((aliases . ((cubeSandbox . cube)))
             (metadata . ((scope . cubeSandbox)
                          (runtime-executed . #f)))))
  (profile objects.cubeSandbox.profile
           cubeSandbox
           objects.sandbox-core.profile
           (poo-flow-sandbox-core-profile-object
            poo-flow-cubeSandbox-object)
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
                                poo-flow-cubeSandbox-backend-capability
                                '((scope . cubeSandbox)
                                  (owned-by . module-config)))
            (resource-policy YuanxuModuleListType override
                             (poo-flow-sandbox-filesystem-prototype->resource-policy
                              poo-flow-snapshot-filesystem-prototype)
                             '((scope . cubeSandbox)
                               (dsl-row . resources))))))
