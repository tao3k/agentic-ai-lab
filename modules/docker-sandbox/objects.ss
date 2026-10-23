;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Docker sandbox module objects.

(import :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/sandbox-core/shared-object
        :agentic-ai-lab/modules/sandbox-core/backend-object-syntax
        :agentic-ai-lab/modules/sandbox-core/objects
        :agentic-ai-lab/modules/sandbox-core/resource-contract)

(export agentic-ai-lab-docker-sandbox-object
        agentic-ai-lab-docker-sandbox-backend-capability
        agentic-ai-lab-docker-sandbox-backend-capability-registry
        agentic-ai-lab-docker-sandbox-profile-object
        agentic-ai-lab-docker-sandbox-module-objects)

;;; Docker sandbox object data records container defaults only; image pulls,
;;; mounts, and process execution remain owned by runtime adapters.
(defpoo-sandbox-backend-object-family
  agentic-ai-lab-docker-sandbox-object
  agentic-ai-lab-docker-sandbox-backend-capability
  agentic-ai-lab-docker-sandbox-backend-capability-registry
  agentic-ai-lab-docker-sandbox-profile-object
  agentic-ai-lab-docker-sandbox-module-objects
  (sandbox objects.docker-sandbox.sandbox
           objects.docker-sandbox
           objects.shared.sandbox
           ((backend YuanxuModuleSymbolType override 'docker '((scope . docker-sandbox)))
            (image YuanxuModuleStringType override "ubuntu:latest" '((scope . docker-sandbox)))))
  (backend docker
           agentic-ai-lab-sandbox-backend-capability/docker
           '((metadata . ((scope . docker-sandbox)
                          (runtime-executed . #f)))))
  (profile objects.docker-sandbox.profile
           docker-sandbox
           objects.sandbox-core.profile
           (agentic-ai-lab-sandbox-core-profile-object
            agentic-ai-lab-docker-sandbox-object)
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
                                agentic-ai-lab-docker-sandbox-backend-capability
                                '((scope . docker-sandbox)
                                  (owned-by . module-config)))
            (resource-policy YuanxuModuleListType override
                             (agentic-ai-lab-sandbox-filesystem-prototype->resource-policy
                              agentic-ai-lab-runtime-volume-filesystem-prototype)
                             '((scope . docker-sandbox)
                               (dsl-row . resources))))))
