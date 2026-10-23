;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Docker sandbox module objects.

(import :yuanxu/module-system/schema/interface
        :poo-flow/modules/sandbox-core/shared-object
        :poo-flow/modules/sandbox-core/backend-object-syntax
        :poo-flow/modules/sandbox-core/objects
        :poo-flow/modules/sandbox-core/resource-contract)

(export poo-flow-docker-sandbox-object
        poo-flow-docker-sandbox-backend-capability
        poo-flow-docker-sandbox-backend-capability-registry
        poo-flow-docker-sandbox-profile-object
        poo-flow-docker-sandbox-module-objects)

;;; Docker sandbox object data records container defaults only; image pulls,
;;; mounts, and process execution remain owned by runtime adapters.
(defpoo-sandbox-backend-object-family
  poo-flow-docker-sandbox-object
  poo-flow-docker-sandbox-backend-capability
  poo-flow-docker-sandbox-backend-capability-registry
  poo-flow-docker-sandbox-profile-object
  poo-flow-docker-sandbox-module-objects
  (sandbox objects.docker-sandbox.sandbox
           objects.docker-sandbox
           objects.shared.sandbox
           ((backend YuanxuModuleSymbolType override 'docker '((scope . docker-sandbox)))
            (image YuanxuModuleStringType override "ubuntu:latest" '((scope . docker-sandbox)))))
  (backend docker
           poo-flow-sandbox-backend-capability/docker
           '((metadata . ((scope . docker-sandbox)
                          (runtime-executed . #f)))))
  (profile objects.docker-sandbox.profile
           docker-sandbox
           objects.sandbox-core.profile
           (poo-flow-sandbox-core-profile-object
            poo-flow-docker-sandbox-object)
           ((backend-kind YuanxuModuleSymbolType override 'docker
                          '((scope . docker-sandbox)
                            (owned-by . module-config)))
            (backend-ref YuanxuModuleSymbolType override 'docker-sandbox
                         '((scope . docker-sandbox)
                           (owned-by . module-config)))
            (capabilities YuanxuModuleListType override
                          '(process-run filesystem-read filesystem-write tmpdir)
                          '((scope . docker-sandbox)
                            (dsl-row . capabilities)))
            (backend-capability YuanxuModuleObjectType override
                                poo-flow-docker-sandbox-backend-capability
                                '((scope . docker-sandbox)
                                  (owned-by . module-config)))
            (resource-policy YuanxuModuleListType override
                             (poo-flow-sandbox-filesystem-prototype->resource-policy
                              poo-flow-runtime-volume-filesystem-prototype)
                             '((scope . docker-sandbox)
                               (dsl-row . resources))))))
