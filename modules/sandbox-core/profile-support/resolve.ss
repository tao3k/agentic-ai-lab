;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile resolution, config, and profile collection build.

(import :gerbil/core
        (only-in :clan/poo/object .o .ref .slot? .extend $constant-slot-spec)
        :yuanxu/module-system/schema/interface
        :poo-flow/modules/sandbox-core/shared-object
        :poo-flow/modules/agent-sandbox/config
        (only-in :poo-flow/modules/agent-sandbox/profile-validation
                 agent-sandbox-profile-resource-policy-filesystem-entry?
                 agent-sandbox-profile-resource-policy-filesystem-diagnostics)
        :poo-flow/modules/sandbox-core/resource-contract
        :poo-flow/modules/sandbox-core/profile-support/prototype
        :poo-flow/modules/sandbox-core/profile-support/policy
        :poo-flow/modules/sandbox-core/profile-support/authoring
        :poo-flow/modules/sandbox-core/profile-support/derivation)

(export poo-flow-sandbox-profile-object-slot
        poo-flow-sandbox-profile-object-base-prototype
        poo-flow-sandbox-profile-object-derived-base-prototype
        poo-flow-sandbox-profile-object-resolve
        poo-flow-sandbox-profile-object->profile
        poo-flow-sandbox-profile-object-profile?
        poo-flow-sandbox-profile-object-config
        poo-flow-sandbox-profile-object-derive
        poo-flow-sandbox-profile-object-profiles/build
        poo-flow-sandbox-profile-object-profiles)

;;; Boundary: sandbox profile object slot is the policy-visible edge for
;;; sandbox, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooSandboxProfilePrototype Symbol Value)
(def (poo-flow-sandbox-profile-object-slot prototype key)
  (if (.slot? prototype key)
    (.ref prototype key)
    (error "sandbox profile prototype lost required slot" key)))

;;; Backend field contracts own inherited defaults. The resolved profile is a
;;; native POO prototype, not an extension-graph node.
;; : (-> PooModuleObject Symbol Value)
(def (poo-flow-sandbox-profile-object-field-default profile-object slot)
  (let (field (yuanxu-module-object-field profile-object slot))
    (if field
      (yuanxu-module-field-contract-default field)
      (error "sandbox profile object has no required field" slot))))

;; : (-> PooModuleObject Symbol Symbol PooSandboxProfilePrototype)
(def (poo-flow-sandbox-profile-object-base-prototype profile-object
                                                     backend-kind-value
                                                     name-value)
  (.o profile-name: name-value
      backend-kind: backend-kind-value
      backend-ref: name-value
      backend-capability:
      (poo-flow-sandbox-backend-capability-ref backend-kind-value)
      profile-policy: poo-flow-sandbox-profile-policy/default
      network-policy:
      (poo-flow-sandbox-profile-object-field-default
       profile-object 'network-policy)
      capabilities:
      (poo-flow-sandbox-profile-object-field-default
       profile-object 'capabilities)
      resource-policy:
      (poo-flow-sandbox-profile-object-field-default
       profile-object 'resource-policy)
      metadata: '((declared-by . poo-flow-user-interface)
                  (runtime-executed . #f))))

;;; A derived profile starts from an already-resolved parent profile, then
;;; accepts ordinary sandbox rows as POO extensions. The child profile is a
;;; new backend ref by default; callers may pass `(backend-ref . <ref>)` when
;;; they intentionally want to keep an existing runtime profile ref.
;; : (-> PooSandboxProfile Symbol Alist PooSandboxProfilePrototype)
(def (poo-flow-sandbox-profile-object-derived-base-prototype parent-profile
                                                             name-value
                                                             options)
  (.o profile-name: name-value
      backend-kind: (poo-flow-sandbox-profile-backend-kind parent-profile)
      backend-ref:
      (poo-flow-sandbox-profile-object-option options 'backend-ref name-value)
      backend-capability:
      (poo-flow-sandbox-backend-capability-ref
       (poo-flow-sandbox-profile-backend-kind parent-profile))
      profile-policy: poo-flow-sandbox-profile-policy/default
      network-policy: (poo-flow-sandbox-profile-network-policy parent-profile)
      capabilities: (poo-flow-sandbox-profile-capabilities parent-profile)
      resource-policy: (poo-flow-sandbox-profile-resource-policy parent-profile)
      metadata: (poo-flow-sandbox-profile-object-derived-metadata
                 parent-profile name-value options)))

;;; Shared resolver keeps validation and filesystem safety common to fresh and
;;; derived profiles. Explicit list operators reuse Core's pure value policy;
;;; the resulting field is an ordinary native POO prototype extension.
;; : (-> PooModuleObject PooSandboxProfilePrototype SandboxProfileForm PooSandboxProfilePrototype)
(def (poo-flow-sandbox-profile-object-extend-row profile-object prototype row)
  (let* ((field (poo-flow-sandbox-profile-object-row-field profile-object row))
         (slot (yuanxu-module-field-contract-identity field))
         (merge (poo-flow-sandbox-profile-object-row-merge
                 (poo-flow-sandbox-profile-object-row-operator row)
                 field))
         (value (poo-flow-sandbox-profile-object-row-value row))
         (resolved-value
          (yuanxu-module-slot-apply-policy
           merge (poo-flow-sandbox-profile-object-slot prototype slot) value)))
    (.extend prototype (cons slot ($constant-slot-spec resolved-value)))))

;; : (-> PooModuleObject Symbol PooSandboxProfilePrototype [SandboxProfileForm] PooSandboxProfile)
(def (poo-flow-sandbox-profile-object-resolve profile-object
                                              name-value
                                              base-prototype
                                              forms)
  (let (validated-rows
        (poo-flow-sandbox-profile-object-validate-rows profile-object forms))
    (poo-flow-sandbox-profile-object->profile
     name-value
     (foldl (lambda (row prototype)
              (poo-flow-sandbox-profile-object-extend-row
               profile-object prototype row))
            base-prototype
            validated-rows))))

;;; Final projection wraps the resolved prototype as the public sandbox profile
;;; recipe consumed by presentation and runtime handoff code.
;; : (-> Symbol PooSandboxProfilePrototype PooSandboxProfile)
(def (poo-flow-sandbox-profile-object->profile name-value prototype)
  (let* ((backend-kind-value
          (poo-flow-sandbox-profile-object-slot prototype 'backend-kind))
         (backend-ref-value
          (poo-flow-sandbox-profile-object-slot prototype 'backend-ref))
         (capabilities-value
          (poo-flow-sandbox-profile-object-slot prototype 'capabilities))
         (backend-capability-value
          (poo-flow-sandbox-profile-object-slot prototype 'backend-capability))
         (profile-policy-value
          (poo-flow-sandbox-profile-object-slot prototype 'profile-policy))
         (validation
          (poo-flow-sandbox-profile-policy-validation
           name-value
           backend-kind-value
           backend-ref-value
           backend-capability-value
           profile-policy-value
           capabilities-value
           (poo-flow-sandbox-profile-object-slot prototype 'resource-policy))))
    (if (poo-flow-sandbox-profile-policy-validation-valid? validation)
      (.o kind: poo-flow-sandbox-profile-kind
          name: name-value
          backend-kind: backend-kind-value
          backend-ref: backend-ref-value
          network-policy: (poo-flow-sandbox-profile-object-slot
                           prototype
                           'network-policy)
          capabilities: capabilities-value
          resource-policy: (poo-flow-sandbox-profile-object-slot
                            prototype
                            'resource-policy)
          metadata: (poo-flow-sandbox-profile-object-slot
                     prototype 'metadata))
      (error "sandbox profile policy validation failed" validation))))

;; : (-> POOObject Boolean)
(def (poo-flow-sandbox-profile-object-profile? value)
  (poo-flow-sandbox-profile? value))

;;; Backend config modules call this with their inherited POO profile object.
;;; This is the only constructor that applies validated rows to POO profiles.
;; : (-> PooModuleObject Symbol Symbol [SandboxProfileForm] PooSandboxProfile)
(def (poo-flow-sandbox-profile-object-config profile-object
                                             backend-kind
                                             name-value
                                             forms)
  (if (symbol? name-value)
    (poo-flow-sandbox-profile-object-resolve
     profile-object
     name-value
     (poo-flow-sandbox-profile-object-base-prototype
      profile-object backend-kind name-value)
     forms)
    (error "sandbox profile name must be a symbol")))

;;; Project/session/task/branch profiles should split by deriving from a parent
;;; profile, not by re-parsing backend rows. This keeps profile extension and
;;; override behavior on the native POO extension path.
;; : (-> PooModuleObject PooSandboxProfile Symbol [SandboxProfileForm] [Alist] PooSandboxProfile)
(def (poo-flow-sandbox-profile-object-derive profile-object
                                             parent-profile
                                             name-value
                                             forms
                                             . maybe-options)
  (let (options (if (null? maybe-options) '() (car maybe-options)))
    (cond
     ((not (symbol? name-value))
      (error "derived sandbox profile name must be a symbol"))
     ((not (poo-flow-sandbox-profile-object-profile? parent-profile))
      (error "derived sandbox profile parent must be a POO sandbox profile"))
     (else
      (poo-flow-sandbox-profile-object-resolve
       profile-object
       name-value
       (poo-flow-sandbox-profile-object-derived-base-prototype
        parent-profile
        name-value
        options)
       forms)))))

;; poo-flow-sandbox-profile-object-profiles/build
;;   : (-> ProfileConfigFn ProfileDeriveFn ProfileRow... [PooSandboxProfile])
;;   | doc m%
;;       `poo-flow-sandbox-profile-object-profiles/build` owns ordered parent
;;       binding and `:derive` expansion while backend modules supply concrete
;;       profile constructors.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-sandbox-profile-object-profiles/build
;;        profile-config derive-config () profile-clauses)
;;       ;; => sandbox-profiles
;;       ```
;;     %
(defrules poo-flow-sandbox-profile-object-profiles/build (:derive)
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
     (poo-flow-sandbox-profile-object-profiles/build
      profile-config
      profile-derive-config
      (profile-name ... name)
      (profile-clause ...))))
  ((_ profile-config
      profile-derive-config
      (profile-name ...)
      ((name form ...) profile-clause ...))
   (let (name (profile-config 'name '(form ...)))
     (poo-flow-sandbox-profile-object-profiles/build
      profile-config
      profile-derive-config
      (profile-name ... name)
      (profile-clause ...)))))

;; poo-flow-sandbox-profile-object-profiles
;;   : (-> ProfileConfigFn ProfileDeriveFn ProfileRow... [PooSandboxProfile])
;;   | doc m%
;;       `poo-flow-sandbox-profile-object-profiles` is the public profile
;;       collection syntax; `:derive` ordering stays POO-owned
;;       through the build macro.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-sandbox-profile-object-profiles profile-config derive-config)
;;       ;; => sandbox-profiles
;;       ```
;;     %
(defrules poo-flow-sandbox-profile-object-profiles ()
  ((_ profile-config profile-derive-config)
   '())
  ((_ profile-config profile-derive-config profile-clause ...)
   (poo-flow-sandbox-profile-object-profiles/build
    profile-config
    profile-derive-config
    ()
    (profile-clause ...))))
