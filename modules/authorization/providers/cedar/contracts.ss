;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Optional Provider role: relational admission before runtime projection.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/list/list every)
        (only-in :std/encoding/hex hex-encode)
        (only-in :agentic-ai-lab/modules/governance/types
                 agentic-ai-lab-governance-profile?
                 agentic-ai-lab-governance-assessment?)
        :yuanxu/poo-clos/interface
        (only-in :agentic-ai-lab/modules/authorization/contracts
                 AuthorizationCapabilityContractProtocol
                 AuthorizationCapabilityContractGeneric
                 agentic-ai-lab-authorization-capability-contract/default)
        (only-in "config.ss"
                 CedarCapabilityContractExecutor
                 CedarAuthorizationProvider)
        (only-in "objects.ss" agentic-ai-lab-cedar-proof-binding?))

(export agentic-ai-lab-governance-assessments-digest
        agentic-ai-lab-cedar-governance-contract
        CedarCapabilityContractMethods)

(def CedarCapabilityContractMethod
  (poo-clos-method
   'authorization/cedar-capability-contract
   (list
    (poo-clos-class-specializer CedarCapabilityContractExecutor)
    (poo-clos-eql-specializer CedarAuthorizationProvider)
    (poo-clos-any-specializer))
   (lambda (_frame _executor provider capabilities)
     (agentic-ai-lab-authorization-capability-contract/default
      provider capabilities))))

(.defmethod-bundle CedarCapabilityContractMethods
  AuthorizationCapabilityContractProtocol
  CedarCapabilityContractMethod)

(poo-clos-compose-method-bundle
 AuthorizationCapabilityContractGeneric
 CedarCapabilityContractMethods)

(def (assessment->canonical value)
  (list (.ref value 'profile-identity)
        (.ref value 'model-identity)
        (map (lambda (threat)
               (list (.ref threat 'identity)
                     (.ref threat 'severity)
                     (.ref threat 'phase)
                     (map (lambda (precondition)
                            (list (.ref precondition 'identity)
                                  (.ref precondition 'observed?)
                                  (.ref precondition 'evidence)))
                          (.ref threat 'preconditions))
                     (.ref threat 'mitigations)
                     (.ref threat 'acceptance-authority)))
             (.ref value 'assessed-threats))
        (.ref value 'unresolved-threats)
        (.ref value 'handoff-ready?)))

(def (agentic-ai-lab-governance-assessments-digest assessment-values)
  (unless (and (pair? assessment-values)
               (every agentic-ai-lab-governance-assessment? assessment-values))
    (error "Governance digest requires typed assessments" assessment-values))
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string
       (lambda (port)
         (write (map assessment->canonical assessment-values) port))))))))

(def (agentic-ai-lab-cedar-governance-contract
      composition-identity profile-values assessment-values proof-value)
  (unless (and (string? composition-identity)
               (> (string-length composition-identity) 0))
    (error "Cedar governance contract requires a composition identity"
           composition-identity))
  (unless (and (pair? profile-values)
               (every agentic-ai-lab-governance-profile? profile-values))
    (error "Cedar governance contract requires admitted Profiles"
           profile-values))
  (unless (and (= (length profile-values) (length assessment-values))
               (every agentic-ai-lab-governance-assessment? assessment-values)
               (equal? (map (lambda (profile) (.ref profile 'identity))
                            profile-values)
                       (map (lambda (assessment)
                              (.ref assessment 'profile-identity))
                            assessment-values)))
    (error "Governance Profiles and assessments must match exactly"
           composition-identity))
  (unless (every (lambda (assessment) (.ref assessment 'handoff-ready?))
                 assessment-values)
    (error "unresolved Governance threats block Cedar handoff"
           (map (lambda (assessment) (.ref assessment 'unresolved-threats))
                assessment-values)))
  (unless (agentic-ai-lab-cedar-proof-binding? proof-value)
    (error "Cedar governance contract requires a proof binding" proof-value))
  (unless (and (equal? composition-identity (.ref proof-value 'composition))
               (equal? (map (lambda (profile) (.ref profile 'identity))
                            profile-values)
                       (.ref proof-value 'profile-identities)))
    (error "Governance composition and Cedar proof identity mismatch"
           composition-identity (.ref proof-value 'composition)))
  (unless (equal? (agentic-ai-lab-governance-assessments-digest assessment-values)
                  (.ref proof-value 'governance-assessment))
    (error "Governance assessment digest does not match Cedar proof binding"
           composition-identity))
  #t)
