;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CubeSandbox kernel module selection.
;;; Invariant: object inheritance and row extension live in objects.ss owners.

(import :poo-flow/modules/cubeSandbox/objects
        :poo-flow/modules/sandbox-core/objects
        :core/module-system/selection/objects
        :core/utilities/final-projection-syntax)

(export poo-flow-cubeSandbox-module-bundles
        poo-flow-cubeSandbox-config-flags
        poo-flow-cubeSandbox-profile-config
        poo-flow-cubeSandbox-profile-derive-config
        poo-flow-cubeSandbox-profile
        poo-flow-cubeSandbox-profile-derive
        poo-flow-cubeSandbox-profiles)

;;; CubeSandbox is a sandbox module row; runtime handoff stays outside selection.
;; : (-> Unit [[PooUserModuleSelection]])
(def poo-flow-cubeSandbox-module-bundles
  (list
   (list
    (poo-flow-user-module-selection
     'sandbox 'cubeSandbox
     (list '+cube '+doctor
           (cons ':backend-capability-registry
                 poo-flow-cubeSandbox-backend-capability-registry))))))

;;; Module config flags carry both the validated internal profile list and the
;;; raw user-authored config body used by user-interface presentation.
;; : (-> [PooSandboxProfile] [UserModuleFlagEntry])
(def (poo-flow-cubeSandbox-config-flags profiles . maybe-user-config)
  (if (null? maybe-user-config)
    (poo-flow-product-field-rows
     (:backend-capability-registry
      poo-flow-cubeSandbox-backend-capability-registry)
     (:config profiles))
    (poo-flow-product-field-rows
     (:backend-capability-registry
      poo-flow-cubeSandbox-backend-capability-registry)
     (:config profiles)
     (:user-config (car maybe-user-config)))))

;;; Backend wrappers pass their inherited profile object into sandbox-core; this
;;; keeps user syntax thin while object merge semantics stay centralized.
;; : (-> Symbol [SandboxProfileForm] PooSandboxProfile)
(def (poo-flow-cubeSandbox-profile-config name-value forms)
  (poo-flow-sandbox-profile-object-config
   poo-flow-cubeSandbox-profile-object
   'cube
   name-value
   forms))

;;; Derived CubeSandbox profiles reuse the sandbox-core POO derivation path;
;;; this wrapper supplies only the backend profile object.
;; : (-> PooSandboxProfile Symbol [SandboxProfileForm] Alist PooSandboxProfile)
(def (poo-flow-cubeSandbox-profile-derive-config parent-profile
                                                 name-value
                                                 forms
                                                 options)
  (poo-flow-sandbox-profile-object-derive
   poo-flow-cubeSandbox-profile-object
   parent-profile
   name-value
   forms
   options))

;;; Profile row macros quote the profile name and forms only; validation is
;;; delegated to the backend profile object above.
;; poo-flow-cubeSandbox-profile
;;   : (-> Symbol SandboxProfileForm... PooSandboxProfile)
;;   | doc m%
;;       `poo-flow-cubeSandbox-profile` documents the policy boundary that the
;;       Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-cubeSandbox-profile ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules poo-flow-cubeSandbox-profile ()
  ((_ name form ...)
   (poo-flow-cubeSandbox-profile-config 'name '(form ...))))

;;; Backend-specific shorthand over the shared sandbox-core POO derive helper.
;; poo-flow-cubeSandbox-profile-derive
;;   : (-> PooSandboxProfile Symbol DerivationOption... SandboxProfileForm... PooSandboxProfile)
;;   | doc m%
;;       `poo-flow-cubeSandbox-profile-derive` documents the policy boundary
;;       that the Gerbil policy harness treats as agent-facing behavior. The
;;       example keeps the call shape visible without duplicating
;;       implementation details.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-cubeSandbox-profile-derive ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules poo-flow-cubeSandbox-profile-derive ()
  ((_ parent name (option ...) form ...)
   (poo-flow-cubeSandbox-profile-derive-config
    parent
    'name
    '(form ...)
    '(option ...)))
  ((_ parent name form ...)
   (poo-flow-cubeSandbox-profile-derive-config
    parent
    'name
    '(form ...)
    '())))

;;; Multiple CubeSandbox profile rows remain ordered user declarations for the
;;; module-system facade and presentation tests.
;; poo-flow-cubeSandbox-profiles
;;   : (-> CubeSandboxProfileRow... [PooSandboxProfile])
;;   | doc m%
;;       `poo-flow-cubeSandbox-profiles` documents the policy boundary that the
;;       Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-cubeSandbox-profiles ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules poo-flow-cubeSandbox-profiles ()
  ((_)
   '())
  ((_ profile-clause ...)
   (poo-flow-sandbox-profile-object-profiles
    poo-flow-cubeSandbox-profile-config
    poo-flow-cubeSandbox-profile-derive-config
    profile-clause ...)))
