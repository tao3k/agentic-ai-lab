;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :yuanxu/poo-clos/interface
        (only-in :poo-flow/modules/authorization/objects
                 AuthorizationCapabilityContractExecutor
                 poo-flow-authorization-provider))

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
  (poo-flow-authorization-provider
   "poo-flow/authorization/cedar"
   '("cedar-rust" "cedar-lean")
   'strict-lockstep
   CedarCapabilityContractProjector
   'native.cedar-authority))
