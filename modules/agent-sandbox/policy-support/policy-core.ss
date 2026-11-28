;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox policy core owns shared policy facts that backend and
;;; profile modules inherit through POO object composition.
;;; Invariant: core policy defaults must remain backend-neutral and safe for
;;; module loader reuse.

(import :gerbil/core
        (only-in :clan/poo/object .ref .slot? object?))

(export agentic-ai-lab-sandbox-backend-capability-kind
        agentic-ai-lab-sandbox-backend-capability-registry-kind
        agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-kind
        agentic-ai-lab-sandbox-backend-capability-registry-validation-kind
        agentic-ai-lab-sandbox-profile-policy-kind
        agentic-ai-lab-sandbox-profile-policy-diagnostic-kind
        agentic-ai-lab-sandbox-profile-policy-validation-kind
        agentic-ai-lab-sandbox-profile-policy-projection-kind
        agentic-ai-lab-sandbox-profile-policy-option
        agentic-ai-lab-sandbox-profile-policy-option?
        agentic-ai-lab-sandbox-policy-value-index
        agentic-ai-lab-sandbox-policy-object-kind?
        agentic-ai-lab-sandbox-profile-policy-object-slot/default)

;; agentic-ai-lab-sandbox-backend-capability-kind
;;   : AgenticAILabSandboxBackendCapabilityKindId
;;   | type AgenticAILabSandboxBackendCapabilityKindId = String
;;   | doc m%
;;       Stable schema kind for backend capability POO objects.
;;
;;       # Examples
;;       ```scheme
;;       agentic-ai-lab-sandbox-backend-capability-kind
;;       ;; => "agentic-ai-lab.sandbox.backend-capability.v1"
;;       ```
(defconst agentic-ai-lab-sandbox-backend-capability-kind
  "agentic-ai-lab.sandbox.backend-capability.v1")

;; agentic-ai-lab-sandbox-backend-capability-registry-kind
;;   : AgenticAILabSandboxBackendCapabilityRegistryKindId
;;   | type AgenticAILabSandboxBackendCapabilityRegistryKindId = String
;;   | doc m%
;;       Stable schema kind for backend capability registry POO objects.
;;
;;       # Examples
;;       ```scheme
;;       agentic-ai-lab-sandbox-backend-capability-registry-kind
;;       ;; => "agentic-ai-lab.sandbox.backend-capability-registry.v1"
;;       ```
(defconst agentic-ai-lab-sandbox-backend-capability-registry-kind
  "agentic-ai-lab.sandbox.backend-capability-registry.v1")

;; agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-kind
;;   : String
;;   | contract: stable schema id for backend capability registry diagnostics
;;   | result: literal kind string emitted in projected diagnostic alists
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-kind
;;       ;; => "agentic-ai-lab.sandbox.backend-capability-registry.diagnostic.v1"
;;       ```
;;     %
(defconst agentic-ai-lab-sandbox-backend-capability-registry-diagnostic-kind
  "agentic-ai-lab.sandbox.backend-capability-registry.diagnostic.v1")

;; agentic-ai-lab-sandbox-backend-capability-registry-validation-kind
;;   : String
;;   | contract: stable schema id for backend capability registry validations
;;   | result: literal kind string emitted in registry validation receipts
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       agentic-ai-lab-sandbox-backend-capability-registry-validation-kind
;;       ;; => "agentic-ai-lab.sandbox.backend-capability-registry.validation.v1"
;;       ```
;;     %
(defconst agentic-ai-lab-sandbox-backend-capability-registry-validation-kind
  "agentic-ai-lab.sandbox.backend-capability-registry.validation.v1")

;; agentic-ai-lab-sandbox-profile-policy-kind
;;   : AgenticAILabSandboxProfilePolicyKindId
;;   | type AgenticAILabSandboxProfilePolicyKindId = String
;;   | doc m%
;;       Stable schema kind for profile policy POO objects.
;;
;;       # Examples
;;       ```scheme
;;       agentic-ai-lab-sandbox-profile-policy-kind
;;       ;; => "agentic-ai-lab.sandbox.profile-policy.v1"
;;       ```
(defconst agentic-ai-lab-sandbox-profile-policy-kind
  "agentic-ai-lab.sandbox.profile-policy.v1")

;; agentic-ai-lab-sandbox-profile-policy-diagnostic-kind
;;   : AgenticAILabSandboxProfilePolicyDiagnosticKindId
;;   | type AgenticAILabSandboxProfilePolicyDiagnosticKindId = String
;;   | doc m%
;;       Stable schema kind for profile policy diagnostic POO objects.
;;
;;       # Examples
;;       ```scheme
;;       agentic-ai-lab-sandbox-profile-policy-diagnostic-kind
;;       ;; => "agentic-ai-lab.sandbox.profile-policy.diagnostic.v1"
;;       ```
(defconst agentic-ai-lab-sandbox-profile-policy-diagnostic-kind
  "agentic-ai-lab.sandbox.profile-policy.diagnostic.v1")

;; agentic-ai-lab-sandbox-profile-policy-validation-kind
;;   : AgenticAILabSandboxProfilePolicyValidationKindId
;;   | type AgenticAILabSandboxProfilePolicyValidationKindId = String
;;   | doc m%
;;       Stable schema kind for profile policy validation receipts.
;;
;;       # Examples
;;       ```scheme
;;       agentic-ai-lab-sandbox-profile-policy-validation-kind
;;       ;; => "agentic-ai-lab.sandbox.profile-policy.validation.v1"
;;       ```
(defconst agentic-ai-lab-sandbox-profile-policy-validation-kind
  "agentic-ai-lab.sandbox.profile-policy.validation.v1")

;; agentic-ai-lab-sandbox-profile-policy-projection-kind
;;   : AgenticAILabSandboxProfilePolicyProjectionKindId
;;   | type AgenticAILabSandboxProfilePolicyProjectionKindId = String
;;   | doc m%
;;       Stable schema kind for non-executing profile policy projections.
;;
;;       # Examples
;;       ```scheme
;;       agentic-ai-lab-sandbox-profile-policy-projection-kind
;;       ;; => "agentic-ai-lab.sandbox.profile-policy.projection.v1"
;;       ```
(defconst agentic-ai-lab-sandbox-profile-policy-projection-kind
  "agentic-ai-lab.sandbox.profile-policy.projection.v1")

;; agentic-ai-lab-sandbox-profile-policy-option
;;   : (-> Alist Symbol Value Value)
;;   | contract: read one optional profile policy setting with a default
;;   | result: option value when present, otherwise the caller-supplied default
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-option
;;        '((network . deny)) 'network 'allow)
;;       ;; => deny
;;       ```
;;     %
;;; Profile policy options share the same row shape across sandbox backends.
;;; - Keep kind/value/default metadata construction centralized for backend and profile helpers.
;; : (-> Alist Symbol Object Object)
(def (agentic-ai-lab-sandbox-profile-policy-option options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; agentic-ai-lab-sandbox-profile-policy-option?
;;   : (-> Alist Symbol Boolean)
;;   | contract: test whether a profile policy option key is present
;;   | result: #t when the key has an entry, otherwise #f
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-option?
;;        '((network . deny)) 'network)
;;       ;; => #t
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-option? options key)
  (and (assoc key options) #t))

;; agentic-ai-lab-sandbox-policy-value-index
;;   : (-> [Value] HashTable)
;;   | contract: build a membership index for policy validation values
;;   | result: hash table mapping every input value to #t
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (hash-get (agentic-ai-lab-sandbox-policy-value-index '(read write)) 'read)
;;       ;; => #t
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-policy-value-index values)
  (let (index (make-hash-table))
    (for-each
     (lambda (value)
       (hash-put! index value #t))
     values)
    index))

;; agentic-ai-lab-sandbox-policy-object-kind?
;;   : (-> SandboxPolicyCandidate SandboxPolicyKindId Boolean)
;;   | contract: recognize POO policy objects carrying the expected kind slot
;;   | result: #t when value is a POO object whose kind equals the expected id
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-policy-object-kind? '() "kind")
;;       ;; => #f
;;       ```
;;     %
;; : (-> SandboxPolicyCandidate SandboxPolicyKindId Boolean)
(def (agentic-ai-lab-sandbox-policy-object-kind? value kind)
  (and (object? value)
       (.slot? value 'kind)
       (equal? (.ref value 'kind) kind)))

;; agentic-ai-lab-sandbox-profile-policy-object-slot/default
;;   : (-> AgenticAILabProfileObject Symbol Value Value)
;;   | contract: read one optional policy object slot with a default value
;;   | result: slot value when available, otherwise default
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-object-slot/default '() 'network-policy 'deny)
;;       ;; => deny
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-object-slot/default object
                                                           key
                                                           default-value)
  (if (and (object? object) (.slot? object key))
    (.ref object key)
    default-value))
