;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Optional module role: relations spanning Provider and capability values.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/list/list delete-duplicates/hash every find)
        (only-in :std/encoding/hex hex-encode)
        :yuanxu/poo-clos/interface
        (only-in :agentic-ai-lab/modules/authorization/objects
                 AuthorizationCapabilityContractExecutor)
        (only-in :agentic-ai-lab/modules/authorization/types
                 agentic-ai-lab-authorization-provider?
                 agentic-ai-lab-authorization-capability?))

(export agentic-ai-lab-authorization-capabilities-digest
        AuthorizationCapabilityContractProtocol
        AuthorizationCapabilityContractGeneric
        AuthorizationCapabilityContractCoreMethods
        agentic-ai-lab-authorization-capability-contract/default
        agentic-ai-lab-authorization-capability-contract)

(def (require-authorization-values provider capabilities)
  (unless (agentic-ai-lab-authorization-provider? provider)
    (error "authorization contract requires a Provider" provider))
  (unless (and (pair? capabilities)
               (every agentic-ai-lab-authorization-capability? capabilities))
    (error "authorization contract requires typed capabilities" capabilities)))

(def (authorization-capabilities-digest provider capabilities)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string
       (lambda (port)
         (write
          (list 'agentic-ai-lab.authorization-capability-contract.v1
                (.ref provider 'identity)
                (.ref provider 'engines)
                (.ref provider 'arbitration)
                (.ref provider 'runtime-owner)
                (map (lambda (capability)
                       (list (.ref capability 'identity)
                             (.ref capability 'action)
                             (.ref capability 'event-kind)
                             (.ref capability 'risk)))
                     capabilities))
          port))))))))

(def (agentic-ai-lab-authorization-capabilities-digest provider capabilities)
  (require-authorization-values provider capabilities)
  (authorization-capabilities-digest provider capabilities))

(def (agentic-ai-lab-authorization-capability-contract/default
      provider-value capability-values)
  (require-authorization-values provider-value capability-values)
  (unless (= (length (.ref provider-value 'engines))
             (length (delete-duplicates/hash (.ref provider-value 'engines))))
    (error "authorization Provider engine identities must be distinct"
           (.ref provider-value 'engines)))
  (unless (or (not (find (lambda (capability)
                           (eq? (.ref capability 'risk) 'elevated))
                         capability-values))
              (eq? (.ref provider-value 'arbitration) 'strict-lockstep))
    (error "elevated authority requires strict lockstep" capability-values))
  (.o kind: 'agentic-ai-lab.authorization-capability-contract
      provider: (.ref provider-value 'identity)
      capability-identities:
      (map (lambda (capability) (.ref capability 'identity)) capability-values)
      contract-digest:
      (authorization-capabilities-digest provider-value capability-values)
      admitted?: #t
      runtime-executed?: #f))

;;; Executor strategy and Provider identity are independently extensible axes.
;;; The base method fails closed; Provider packages own concrete method bundles.
(def AuthorizationCapabilityContractProtocol
  (poo-clos-generic-protocol 'authorization/capability-contract))

(def AuthorizationCapabilityContractGeneric
  (poo-clos-generic-function
   'authorization-capability-contract 3
   protocol: AuthorizationCapabilityContractProtocol))

(def AuthorizationUnsupportedCapabilityContractMethod
  (poo-clos-method
   'authorization/unsupported-capability-contract
   (list
    (poo-clos-class-specializer AuthorizationCapabilityContractExecutor)
    (poo-clos-any-specializer)
    (poo-clos-any-specializer))
   (lambda (_frame _executor provider _capabilities)
     (error "authorization Provider lacks a capability contract method"
            (.ref provider 'identity)))))

(.defmethod-bundle AuthorizationCapabilityContractCoreMethods
  AuthorizationCapabilityContractProtocol
  AuthorizationUnsupportedCapabilityContractMethod)

(poo-clos-compose-method-bundle
 AuthorizationCapabilityContractGeneric
 AuthorizationCapabilityContractCoreMethods)

(def (agentic-ai-lab-authorization-capability-contract provider capabilities)
  (require-authorization-values provider capabilities)
  (poo-clos-call
   AuthorizationCapabilityContractGeneric
   (.ref provider 'contract-executor)
   provider
   capabilities))
