;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :yuanxu/poo-clos/interface
        (only-in :agentic-ai-lab/modules/authorization/objects
                 AuthorizationCapabilityContractExecutor
                 agentic-ai-lab-authorization-provider))

(export CedarCapabilityContractExecutor
        CedarCapabilityContractProjector
        CedarAuthorizationProvider)

(def CedarCapabilityContractExecutor
  (poo-clos-class
   'authorization/cedar-capability-contract-executor
   direct-superclasses: (list AuthorizationCapabilityContractExecutor)))

(def CedarCapabilityContractProjector
  (poo-clos-make-instance CedarCapabilityContractExecutor))

(def CedarAuthorizationProvider
  (agentic-ai-lab-authorization-provider
   "agentic-ai-lab/authorization/cedar"
   '("cedar-rust" "cedar-lean")
   'strict-lockstep
   CedarCapabilityContractProjector
   'native.cedar-authority))
