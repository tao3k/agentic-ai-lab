;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO profile descriptors for agent-sandbox backend defaults.
;;; Invariant: descriptors project through the shared validation owner.

(import (only-in :clan/poo/object .@ object?)
        (only-in :poo-flow/modules/workflow/control-plane/roles execution-policy-role)
        :core/object-family/role-syntax
        :poo-flow/modules/agent-sandbox/alist
        :poo-flow/modules/agent-sandbox/projection-syntax
        :poo-flow/modules/agent-sandbox/profile-data
        :poo-flow/modules/agent-sandbox/profile-validation)

(export agent-sandbox-profile-descriptor-prototype
        make-agent-sandbox-backend-profile-descriptor
        make-agent-sandbox-profile-descriptor
        agent-sandbox-profile-descriptor?
        agent-sandbox-profile-descriptor-name
        agent-sandbox-profile-descriptor-backend-kind
        agent-sandbox-profile-descriptor-backend-ref
        agent-sandbox-profile-descriptor-network-policy
        agent-sandbox-profile-descriptor-capabilities
        agent-sandbox-profile-descriptor-resource-policy
        agent-sandbox-profile-descriptor-metadata
        agent-sandbox-profile-descriptor-validator
        agent-sandbox-profile-descriptor->profile)

;;; Profile descriptors are POO policy objects: backend modules override slots,
;;; while core keeps one validation and projection path into request profiles.
;;; Higher-order boundary:
;;; - The validator slot is a Profile -> Profile procedure.
;;; - Backend overrides may replace policy data, but validation remains explicit.
;; : (-> AgentSandboxProfile AgentSandboxProfile)
(def (agent-sandbox-profile-validator profile)
  (agent-sandbox-validate-profile profile))

;; : (-> Unit AgentSandboxProfileDescriptorPrototype)
(def agent-sandbox-profile-descriptor-prototype
  (poo-core-role-object
   (slots ((name 'agent-sandbox-profile)
           (backend-kind #f)
           (backend-ref #f)
           (network-policy '())
           (capabilities '())
           (resource-policy '())
           (metadata '())
           (validator agent-sandbox-profile-validator)))
   (supers execution-policy-role)))

;;; Descriptor construction is the override point for backend modules. The
;;; resulting object still projects through the same core profile contract.
;; : (-> Symbol Symbol BackendRef NetworkPolicy Capabilities ResourcePolicy Metadata [Alist] AgentSandboxProfileDescriptor)
(def (make-agent-sandbox-profile-descriptor name
                                            backend-kind
                                            backend-ref
                                            network-policy
                                            capabilities
                                            resource-policy
                                            metadata
                                            . maybe-overrides)
  (poo-core-role-object
   (slot-rows
    (agent-sandbox-field-rows/tail
     (if (null? maybe-overrides) '() (car maybe-overrides))
     (name name)
     (backend-kind backend-kind)
     (backend-ref backend-ref)
     (network-policy network-policy)
     (capabilities capabilities)
     (resource-policy resource-policy)
     (metadata metadata)))
   (supers agent-sandbox-profile-descriptor-prototype)))

;;; Runtime source for the backend declaration macro. Keeping this as a normal
;;; function makes option merging and metadata callbacks inspectable by policy.
;;; Macro-expansion witness:
;;; - =defagent-sandbox-backend-profile= only supplies constructor names.
;;; - Every generated descriptor constructor delegates here before validation.
;; : (-> Symbol Symbol BackendRef NetworkPolicy Capabilities ResourcePolicy MetadataProcedure Alist AgentSandboxProfileDescriptor)
(def (make-agent-sandbox-backend-profile-descriptor descriptor-name
                                                   backend-kind
                                                   backend-ref
                                                   default-network-policy
                                                   default-capabilities
                                                   default-resource-policy
                                                   metadata-procedure
                                                   options)
  (let (metadata-maker metadata-procedure)
    (make-agent-sandbox-profile-descriptor
     descriptor-name
     backend-kind
     backend-ref
     (agent-sandbox-option options 'network-policy default-network-policy)
     (agent-sandbox-option options 'capabilities default-capabilities)
     (agent-sandbox-option options 'resource-policy default-resource-policy)
     (agent-sandbox-option options
                           'metadata
                           (metadata-maker backend-ref)))))

;; : (-> AgentSandboxProfileDescriptorCandidate Boolean)
(def (agent-sandbox-profile-descriptor? descriptor)
  (object? descriptor))

;; : (-> AgentSandboxProfileDescriptor Symbol)
(def (agent-sandbox-profile-descriptor-name descriptor)
  (.@ descriptor name))

;; : (-> AgentSandboxProfileDescriptor (U Symbol #f))
(def (agent-sandbox-profile-descriptor-backend-kind descriptor)
  (.@ descriptor backend-kind))

;; : (-> AgentSandboxProfileDescriptor (U BackendRef #f))
(def (agent-sandbox-profile-descriptor-backend-ref descriptor)
  (.@ descriptor backend-ref))

;; : (-> AgentSandboxProfileDescriptor NetworkPolicy)
(def (agent-sandbox-profile-descriptor-network-policy descriptor)
  (.@ descriptor network-policy))

;; : (-> AgentSandboxProfileDescriptor Capabilities)
(def (agent-sandbox-profile-descriptor-capabilities descriptor)
  (.@ descriptor capabilities))

;; : (-> AgentSandboxProfileDescriptor ResourcePolicy)
(def (agent-sandbox-profile-descriptor-resource-policy descriptor)
  (.@ descriptor resource-policy))

;; : (-> AgentSandboxProfileDescriptor Metadata)
(def (agent-sandbox-profile-descriptor-metadata descriptor)
  (.@ descriptor metadata))

;; : (-> AgentSandboxProfileDescriptor Validator)
(def (agent-sandbox-profile-descriptor-validator descriptor)
  (.@ descriptor validator))

;;; Descriptor projection validates the final profile, so backend slot override
;;; remains extensible without bypassing the stable profile schema.
;; : (-> AgentSandboxProfileDescriptor AgentSandboxProfile)
(def (agent-sandbox-profile-descriptor->profile descriptor)
  ((agent-sandbox-profile-descriptor-validator descriptor)
   (make-agent-sandbox-backend-profile
    (agent-sandbox-profile-descriptor-backend-kind descriptor)
    (agent-sandbox-profile-descriptor-backend-ref descriptor)
    (agent-sandbox-profile-descriptor-network-policy descriptor)
    (agent-sandbox-profile-descriptor-capabilities descriptor)
    (agent-sandbox-profile-descriptor-resource-policy descriptor)
    (agent-sandbox-profile-descriptor-metadata descriptor))))
