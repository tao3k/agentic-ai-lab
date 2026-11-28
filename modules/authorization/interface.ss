;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "contracts.ss" "funs.ss" "config.ss"
        (only-in "providers/cedar/objects.ss"
                 agentic-ai-lab-cedar-policy
                 agentic-ai-lab-cedar-authority-snapshot))
(export Authorization
        (import: "types.ss")
        (import: "objects.ss")
        (import: "contracts.ss")
        (import: "funs.ss")
        (import: "config.ss"))

(.def Authorization
  identity: 'authorization
  tags: '(authorization policy)
  core: (.o scope-contract: AuthorizationScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/authorization/interface
                         provider?: agentic-ai-lab-authorization-provider?
                         capability?: agentic-ai-lab-authorization-capability?
                         cedar: (.o policy: agentic-ai-lab-cedar-policy
                                    authority-snapshot: agentic-ai-lab-cedar-authority-snapshot)))
  features: (.o))
