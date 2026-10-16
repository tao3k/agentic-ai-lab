;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user profile objects and default config projection.
;;; Invariant: profile objects are declarative and do not realize descriptors.

(import (only-in :clan/poo/object .o .ref object?)
        :poo-flow/modules/module-authoring/module-interface
        :poo-flow/modules/user-interface/module-selection)

(export poo-flow-user-profile-kind
        poo-flow-user-profile-set-kind
        poo-flow-user-profile-diagnostic-kind
        poo-flow-user-profile-presentation-kind
        poo-flow-user-profile-set-presentation-kind
        poo-flow-user-profile-policy-receipt-kind
        poo-flow-user-profile-set-policy-receipt-kind
        pooFlowUserProfile
        pooFlowUserProfileSet
        pooFlowUserProfileExtend
        pooFlowDefaultUserSettings
        poo-flow-default-user-setting-keys
        pooFlowUserConfigFromProfile
        poo-flow-user-profile?
        poo-flow-user-profile-set?
        poo-flow-user-profile-name
        poo-flow-user-profile-set-name
        poo-flow-user-profile-set-default-profile-name
        poo-flow-user-profile-set-profiles
        poo-flow-user-profile-set-profile-names
        poo-flow-user-profile-set-find-profile
        poo-flow-user-profile-set-default-profile
        poo-flow-user-profile-module-bundles
        poo-flow-user-profile-modules
        poo-flow-user-profile-settings
        poo-flow-user-profile-setting-keys
        poo-flow-user-profile-object-kind?
        poo-flow-user-profile-alist-ref)

;;; User profiles group Doom-style module bundles and settings without crossing
;;; into descriptor realization or runtime activation.
;; : (-> Unit PooFlowUserProfileKind)
(def poo-flow-user-profile-kind
  "poo-flow.modules.user-profile.v1")

;;; Profile sets model Doom's profile registry as declarative data.
;; : (-> Unit PooFlowUserProfileSetKind)
(def poo-flow-user-profile-set-kind
  "poo-flow.modules.user-profile-set.v1")

;;; Profile diagnostics are user-facing doctor facts for profile declarations.
;; : (-> Unit PooFlowUserProfileDiagnosticKind)
(def poo-flow-user-profile-diagnostic-kind
  "poo-flow.modules.user-profile.diagnostic.v1")

;;; Profile presentation ids expose the higher-level user entrypoint shape.
;; : (-> Unit PooFlowUserProfilePresentationKind)
(def poo-flow-user-profile-presentation-kind
  "poo-flow.modules.user-profile.presentation.v1")

;;; Profile set presentations expose selection state without loading profiles.
;; : (-> Unit PooFlowUserProfileSetPresentationKind)
(def poo-flow-user-profile-set-presentation-kind
  "poo-flow.modules.user-profile-set.presentation.v1")

;;; Test-time profile policy receipts are not activation receipts.
;; : (-> Unit PooFlowUserProfilePolicyReceiptKind)
(def poo-flow-user-profile-policy-receipt-kind
  "poo-flow.modules.user-profile.policy-receipt.v1")

;;; Profile-set policy receipts validate registries before selection.
;; : (-> Unit PooFlowUserProfileSetPolicyReceiptKind)
(def poo-flow-user-profile-set-policy-receipt-kind
  "poo-flow.modules.user-profile-set.policy-receipt.v1")

;;; Boundary: profile checks keep root user files independent of constructors.
;; : (-> POOObject String Boolean)
(def (poo-flow-user-profile-object-kind? value expected-kind)
  (and (object? value)
       (equal? (.ref value 'kind) expected-kind)))

;;; Boundary: user profile alist ref is the policy-visible edge for module-
;;; system, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Alist Symbol Value Value)
(def (poo-flow-user-profile-alist-ref entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;;; Boundary: a user profile is the Doom-style high-level entrypoint; it groups
;;; module bundles, settings, and public setting keys without realizing modules.
;; : (-> Symbol [[PooUserModuleSelection]] POOObject [Symbol] POOObject)
(def (pooFlowUserProfile name module-bundles settings setting-keys)
  (.o kind: poo-flow-user-profile-kind
      profile-name: name
      profile-selection-bundles: module-bundles
      user-settings: settings
      public-setting-keys: setting-keys))

;;; Profile sets are the POO Flow analogue of Doom's profiles.el: a named
;;; registry, a default profile key, and profile objects. No package or runtime
;;; synchronization happens here.
;; : (-> Symbol Symbol [PooUserProfile] POOObject)
(def (pooFlowUserProfileSet set-name default-name profile-list)
  (.o kind: poo-flow-user-profile-set-kind
      profile-set-name: set-name
      default-profile-name: default-name
      user-profiles: profile-list))

;;; Default user settings are upstream-owned so root init.ss can stay close to
;;; Doom's init.el: module activation only, no strategy projection details.
;; : (-> Symbol POOObject)
(def (pooFlowDefaultUserSettings profile-name)
  (poo-flow-settings
   surface: "poo-flow"
   profile: (symbol->string profile-name)
   flow-mode: 'funflow
   loop-strategy: 'governed
   sandbox-policy: 'module-gated
   sandbox-backends: '(nono cube docker)
   mode-lock: "stable"))

;; : [Symbol]
(def poo-flow-default-user-setting-keys
  '(surface
    profile
    flow-mode
    loop-strategy
    sandbox-policy
    sandbox-backends
    mode-lock))

;;; Profile projection is the only adapter from Doom-style profile data into
;;; the stable config object consumed by existing tests and tooling.
;; : (-> PooUserProfile PooUserConfig)
(def (pooFlowUserConfigFromProfile profile)
  (pooFlowUserConfig
   (poo-flow-user-profile-modules profile)
   (poo-flow-user-profile-settings profile)))

;; : (-> PooUserProfileCandidate Boolean)
(def (poo-flow-user-profile? value)
  (poo-flow-user-profile-object-kind? value poo-flow-user-profile-kind))

;; : (-> PooUserProfileSetCandidate Boolean)
(def (poo-flow-user-profile-set? value)
  (poo-flow-user-profile-object-kind? value poo-flow-user-profile-set-kind))

;; : (-> PooUserProfile Symbol)
(def (poo-flow-user-profile-name profile)
  (.ref profile 'profile-name))

;; : (-> PooUserProfileSet Symbol)
(def (poo-flow-user-profile-set-name profile-set)
  (.ref profile-set 'profile-set-name))

;; : (-> PooUserProfileSet Symbol)
(def (poo-flow-user-profile-set-default-profile-name profile-set)
  (.ref profile-set 'default-profile-name))

;; : (-> PooUserProfileSet [PooUserProfile])
(def (poo-flow-user-profile-set-profiles profile-set)
  (.ref profile-set 'user-profiles))

;;; Profile names are registry keys. They are stable user-facing selectors,
;;; matching Doom's profile name role without inheriting its env var machinery.
;; : (-> PooUserProfileSet [Symbol])
(def (poo-flow-user-profile-set-profile-names profile-set)
  (map poo-flow-user-profile-name
       (poo-flow-user-profile-set-profiles profile-set)))

;;; Profile lookup is pure data selection; missing profiles are reported by the
;;; policy path instead of triggering runtime loading.
;; : (-> Symbol [PooUserProfile] MaybePooUserProfile)
(def (poo-flow-user-profile-set-find-profile/add profile-name profiles)
  (cond
   ((null? profiles) #f)
   ((equal? profile-name (poo-flow-user-profile-name (car profiles))) (car profiles))
   (else
    (poo-flow-user-profile-set-find-profile/add profile-name (cdr profiles)))))

;; : (-> PooUserProfileSet Symbol MaybePooUserProfile)
(def (poo-flow-user-profile-set-find-profile profile-set profile-name)
  (poo-flow-user-profile-set-find-profile/add
   profile-name
   (poo-flow-user-profile-set-profiles profile-set)))

;; : (-> PooUserProfileSet MaybePooUserProfile)
(def (poo-flow-user-profile-set-default-profile profile-set)
  (poo-flow-user-profile-set-find-profile
   profile-set
   (poo-flow-user-profile-set-default-profile-name profile-set)))

;; : (-> PooUserProfile [[PooUserModuleSelection]])
(def (poo-flow-user-profile-module-bundles profile)
  (.ref profile 'profile-selection-bundles))

;; : (-> PooUserProfile [PooUserModuleSelection])
(def (poo-flow-user-profile-modules profile)
  (poo-flow-user-module-bundles->modules
   (poo-flow-user-profile-module-bundles profile)))

;; : (-> PooUserProfile POOObject)
(def (poo-flow-user-profile-settings profile)
  (.ref profile 'user-settings))

;; : (-> PooUserProfile [Symbol])
(def (poo-flow-user-profile-setting-keys profile)
  (.ref profile 'public-setting-keys))

;;; Profile extension is an upstream helper for user init surfaces. Downstream
;;; init.ss files can patch kernel module features or append custom modules
;;; without manually rebuilding config objects. The derived profile receives
;;; user defaults for its own name; kernel settings remain kernel-owned.
;; : (-> Symbol PooUserProfile [[PooUserModuleSelection]] PooUserProfile)
(def (pooFlowUserProfileExtend profile-name base-profile extra-module-bundles)
  (pooFlowUserProfile profile-name
                      (poo-flow-user-module-bundles-extend
                       (poo-flow-user-profile-module-bundles base-profile)
                       extra-module-bundles)
                      (pooFlowDefaultUserSettings profile-name)
                      poo-flow-default-user-setting-keys))
