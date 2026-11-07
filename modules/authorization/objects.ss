;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: inert authorization Provider objects; execution is external.
(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        :yuanxu/poo-clos/interface
        (only-in :agentic-ai-lab/modules/authorization/types
                 agentic-ai-lab-authorization-provider-kind
                 agentic-ai-lab-authorization-capability-kind
                 AgenticAILabAuthorizationProvider
                 AgenticAILabAuthorizationCapability))

(export AuthorizationCapabilityContractExecutor
        agentic-ai-lab-authorization-provider
        agentic-ai-lab-authorization-capability)

;;; Provider packages specialize this executor class and publish their methods
;;; through a bundle.  The core owns no Provider-name branch.
(def AuthorizationCapabilityContractExecutor
  (poo-clos-class 'authorization/capability-contract-executor))

(def (agentic-ai-lab-authorization-provider identity-value engines-value
                                      arbitration-value executor-value
                                      runtime-owner-value)
  (validate
   AgenticAILabAuthorizationProvider
   (.o kind: agentic-ai-lab-authorization-provider-kind
       identity: identity-value
       engines: engines-value
       arbitration: arbitration-value
       contract-executor: executor-value
       runtime-owner: runtime-owner-value
       runtime-executed?: #f)))

(def (agentic-ai-lab-authorization-capability identity-value action-value
                                        event-kind-value risk-value)
  (validate
   AgenticAILabAuthorizationCapability
   (.o kind: agentic-ai-lab-authorization-capability-kind
       identity: identity-value
       action: action-value
       event-kind: event-kind-value
       risk: risk-value
       runtime-executed?: #f)))
