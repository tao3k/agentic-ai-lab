;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile resolution, config, and profile collection build.

(import :gerbil/core
        (only-in :clan/poo/object .o .ref .slot? .extend $constant-slot-spec)
        :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/sandbox-core/shared-object
        :agentic-ai-lab/modules/agent-sandbox/config
        (only-in :agentic-ai-lab/modules/agent-sandbox/profile-validation
                 agent-sandbox-profile-resource-policy-filesystem-entry?
                 agent-sandbox-profile-resource-policy-filesystem-diagnostics)
        :agentic-ai-lab/modules/sandbox-core/resource-contract
        :agentic-ai-lab/modules/sandbox-core/profile-support/prototype
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy
        :agentic-ai-lab/modules/sandbox-core/profile-support/authoring
        :agentic-ai-lab/modules/sandbox-core/profile-support/derivation)

(export agentic-ai-lab-sandbox-profile-object-slot
        agentic-ai-lab-sandbox-profile-object-base-prototype
        agentic-ai-lab-sandbox-profile-object-derived-base-prototype
        agentic-ai-lab-sandbox-profile-object-resolve
        agentic-ai-lab-sandbox-profile-object->profile
        agentic-ai-lab-sandbox-profile-object-profile?
        agentic-ai-lab-sandbox-profile-object-config
        agentic-ai-lab-sandbox-profile-object-derive
        agentic-ai-lab-sandbox-profile-object-profiles/build
        agentic-ai-lab-sandbox-profile-object-profiles)

;;; Boundary: sandbox profile object slot is the policy-visible edge for
;;; sandbox, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooSandboxProfilePrototype Symbol Value)
(def (agentic-ai-lab-sandbox-profile-object-slot prototype key)
  (if (.slot? prototype key)
    (.ref prototype key)
    (error "sandbox profile prototype lost required slot" key)))

;;; Backend field contracts own inherited defaults. The resolved profile is a
;;; native POO prototype, not an extension-graph node.
;; : (-> PooModuleObject Symbol Value)
(def (agentic-ai-lab-sandbox-profile-object-field-default profile-object slot)
  (let (field (yuanxu-module-object-field profile-object slot))
    (if field
      (yuanxu-module-field-contract-default field)
      (error "sandbox profile object has no required field" slot))))

;; : (-> PooModuleObject Symbol Symbol PooSandboxProfilePrototype)
(def (agentic-ai-lab-sandbox-profile-object-base-prototype profile-object
                                                     backend-kind-value
                                                     name-value)
  (.o profile-name: name-value
      backend-kind: backend-kind-value
      backend-ref: name-value
      backend-capability:
      (agentic-ai-lab-sandbox-backend-capability-ref backend-kind-value)
      profile-policy: agentic-ai-lab-sandbox-profile-policy/default
      network-policy:
      (agentic-ai-lab-sandbox-profile-object-field-default
       profile-object 'network-policy)
      capabilities:
      (agentic-ai-lab-sandbox-profile-object-field-default
       profile-object 'capabilities)
      resource-policy:
      (agentic-ai-lab-sandbox-profile-object-field-default
       profile-object 'resource-policy)
      metadata: '((declared-by . agentic-ai-lab-user-interface)
                  (runtime-executed . #f))))

;;; A derived profile starts from an already-resolved parent profile, then
;;; accepts ordinary sandbox rows as POO extensions. The child profile is a
;;; new backend ref by default; callers may pass `(backend-ref . <ref>)` when
;;; they intentionally want to keep an existing runtime profile ref.
;; : (-> PooSandboxProfile Symbol Alist PooSandboxProfilePrototype)
(def (agentic-ai-lab-sandbox-profile-object-derived-base-prototype parent-profile
                                                             name-value
                                                             options)
  (.o profile-name: name-value
      backend-kind: (agentic-ai-lab-sandbox-profile-backend-kind parent-profile)
      backend-ref:
      (agentic-ai-lab-sandbox-profile-object-option options 'backend-ref name-value)
      backend-capability:
      (agentic-ai-lab-sandbox-backend-capability-ref
       (agentic-ai-lab-sandbox-profile-backend-kind parent-profile))
      profile-policy: agentic-ai-lab-sandbox-profile-policy/default
      network-policy: (agentic-ai-lab-sandbox-profile-network-policy parent-profile)
      capabilities: (agentic-ai-lab-sandbox-profile-capabilities parent-profile)
      resource-policy: (agentic-ai-lab-sandbox-profile-resource-policy parent-profile)
      metadata: (agentic-ai-lab-sandbox-profile-object-derived-metadata
                 parent-profile name-value options)))

;;; Shared resolver keeps validation and filesystem safety common to fresh and
;;; derived profiles. Explicit list operators reuse Core's pure value policy;
;;; the resulting field is an ordinary native POO prototype extension.
;; : (-> PooModuleObject PooSandboxProfilePrototype SandboxProfileForm PooSandboxProfilePrototype)
(def (agentic-ai-lab-sandbox-profile-object-extend-row profile-object prototype row)
  (let* ((field (agentic-ai-lab-sandbox-profile-object-row-field profile-object row))
         (slot (yuanxu-module-field-contract-identity field))
         (merge (agentic-ai-lab-sandbox-profile-object-row-merge
                 (agentic-ai-lab-sandbox-profile-object-row-operator row)
                 field))
         (value (agentic-ai-lab-sandbox-profile-object-row-value row))
         (resolved-value
          (yuanxu-module-slot-apply-policy
           merge (agentic-ai-lab-sandbox-profile-object-slot prototype slot) value)))
    (.extend prototype (cons slot ($constant-slot-spec resolved-value)))))

;; : (-> PooModuleObject Symbol PooSandboxProfilePrototype [SandboxProfileForm] PooSandboxProfile)
(def (agentic-ai-lab-sandbox-profile-object-resolve profile-object
                                              name-value
                                              base-prototype
                                              forms)
  (let (validated-rows
        (agentic-ai-lab-sandbox-profile-object-validate-rows profile-object forms))
    (agentic-ai-lab-sandbox-profile-object->profile
     name-value
     (foldl (lambda (row prototype)
              (agentic-ai-lab-sandbox-profile-object-extend-row
               profile-object prototype row))
            base-prototype
            validated-rows))))

;;; Final projection wraps the resolved prototype as the public sandbox profile
;;; recipe consumed by presentation and runtime handoff code.
;; : (-> Symbol PooSandboxProfilePrototype PooSandboxProfile)
(def (agentic-ai-lab-sandbox-profile-object->profile name-value prototype)
  (let* ((backend-kind-value
          (agentic-ai-lab-sandbox-profile-object-slot prototype 'backend-kind))
         (backend-ref-value
          (agentic-ai-lab-sandbox-profile-object-slot prototype 'backend-ref))
         (capabilities-value
          (agentic-ai-lab-sandbox-profile-object-slot prototype 'capabilities))
         (backend-capability-value
          (agentic-ai-lab-sandbox-profile-object-slot prototype 'backend-capability))
         (profile-policy-value
          (agentic-ai-lab-sandbox-profile-object-slot prototype 'profile-policy))
         (validation
          (agentic-ai-lab-sandbox-profile-policy-validation
           name-value
           backend-kind-value
           backend-ref-value
           backend-capability-value
           profile-policy-value
           capabilities-value
           (agentic-ai-lab-sandbox-profile-object-slot prototype 'resource-policy))))
    (if (agentic-ai-lab-sandbox-profile-policy-validation-valid? validation)
      (.o kind: agentic-ai-lab-sandbox-profile-kind
          name: name-value
          backend-kind: backend-kind-value
          backend-ref: backend-ref-value
          network-policy: (agentic-ai-lab-sandbox-profile-object-slot
                           prototype
                           'network-policy)
          capabilities: capabilities-value
          resource-policy: (agentic-ai-lab-sandbox-profile-object-slot
                            prototype
                            'resource-policy)
          metadata: (agentic-ai-lab-sandbox-profile-object-slot
                     prototype 'metadata))
      (error "sandbox profile policy validation failed" validation))))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-sandbox-profile-object-profile? value)
  (agentic-ai-lab-sandbox-profile? value))

;;; Backend config modules call this with their inherited POO profile object.
;;; This is the only constructor that applies validated rows to POO profiles.
;; : (-> PooModuleObject Symbol Symbol [SandboxProfileForm] PooSandboxProfile)
(def (agentic-ai-lab-sandbox-profile-object-config profile-object
                                             backend-kind
                                             name-value
                                             forms)
  (if (symbol? name-value)
    (agentic-ai-lab-sandbox-profile-object-resolve
     profile-object
     name-value
     (agentic-ai-lab-sandbox-profile-object-base-prototype
      profile-object backend-kind name-value)
     forms)
    (error "sandbox profile name must be a symbol")))

;;; Project/session/task/branch profiles should split by deriving from a parent
;;; profile, not by re-parsing backend rows. This keeps profile extension and
;;; override behavior on the native POO extension path.
;; : (-> PooModuleObject PooSandboxProfile Symbol [SandboxProfileForm] [Alist] PooSandboxProfile)
(def (agentic-ai-lab-sandbox-profile-object-derive profile-object
                                             parent-profile
                                             name-value
                                             forms
                                             . maybe-options)
  (let (options (if (null? maybe-options) '() (car maybe-options)))
    (cond
     ((not (symbol? name-value))
      (error "derived sandbox profile name must be a symbol"))
     ((not (agentic-ai-lab-sandbox-profile-object-profile? parent-profile))
      (error "derived sandbox profile parent must be a POO sandbox profile"))
     (else
      (agentic-ai-lab-sandbox-profile-object-resolve
       profile-object
       name-value
       (agentic-ai-lab-sandbox-profile-object-derived-base-prototype
        parent-profile
        name-value
        options)
       forms)))))

;; agentic-ai-lab-sandbox-profile-object-profiles/build
;;   : (-> ProfileConfigFn ProfileDeriveFn ProfileRow... [PooSandboxProfile])
;;   | doc m%
;;       `agentic-ai-lab-sandbox-profile-object-profiles/build` owns ordered parent
;;       binding and `:derive` expansion while backend modules supply concrete
;;       profile constructors.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-object-profiles/build
;;        profile-config derive-config () profile-clauses)
;;       ;; => sandbox-profiles
;;       ```
;;     %
(defrules agentic-ai-lab-sandbox-profile-object-profiles/build (:derive)
  ((_ profile-config profile-derive-config (profile-name ...) ())
   (list profile-name ...))
  ((_ profile-config
      profile-derive-config
      (profile-name ...)
      ((name (:derive parent option ...) form ...) profile-clause ...))
   (let (name (profile-derive-config
               parent
               'name
               '(form ...)
               '(option ...)))
     (agentic-ai-lab-sandbox-profile-object-profiles/build
      profile-config
      profile-derive-config
      (profile-name ... name)
      (profile-clause ...))))
  ((_ profile-config
      profile-derive-config
      (profile-name ...)
      ((name form ...) profile-clause ...))
   (let (name (profile-config 'name '(form ...)))
     (agentic-ai-lab-sandbox-profile-object-profiles/build
      profile-config
      profile-derive-config
      (profile-name ... name)
      (profile-clause ...)))))

;; agentic-ai-lab-sandbox-profile-object-profiles
;;   : (-> ProfileConfigFn ProfileDeriveFn ProfileRow... [PooSandboxProfile])
;;   | doc m%
;;       `agentic-ai-lab-sandbox-profile-object-profiles` is the public profile
;;       collection syntax; `:derive` ordering stays POO-owned
;;       through the build macro.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-object-profiles profile-config derive-config)
;;       ;; => sandbox-profiles
;;       ```
;;     %
(defrules agentic-ai-lab-sandbox-profile-object-profiles ()
  ((_ profile-config profile-derive-config)
   '())
  ((_ profile-config profile-derive-config profile-clause ...)
   (agentic-ai-lab-sandbox-profile-object-profiles/build
    profile-config
    profile-derive-config
    ()
    (profile-clause ...))))
