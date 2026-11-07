;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CubeSandbox kernel module selection.
;;; Invariant: object inheritance and row extension live in objects.ss owners.

(import :agentic-ai-lab/modules/cubeSandbox/objects
        :agentic-ai-lab/modules/sandbox-core/objects
        :yuanxu/module-system/selection/objects
        :yuanxu/utilities/final-projection-syntax)

(export agentic-ai-lab-cubeSandbox-module-bundles
        agentic-ai-lab-cubeSandbox-config-flags
        agentic-ai-lab-cubeSandbox-profile-config
        agentic-ai-lab-cubeSandbox-profile-derive-config
        agentic-ai-lab-cubeSandbox-profile
        agentic-ai-lab-cubeSandbox-profile-derive
        agentic-ai-lab-cubeSandbox-profiles)

;;; CubeSandbox is a sandbox module row; runtime handoff stays outside selection.
;; : (-> Unit [[PooUserModuleSelection]])
(def agentic-ai-lab-cubeSandbox-module-bundles
  (list
   (list
    (yuanxu-user-module-selection
     'sandbox 'cubeSandbox
     (list '+cube '+doctor
           (cons ':backend-capability-registry
                 agentic-ai-lab-cubeSandbox-backend-capability-registry))))))

;;; Module config flags carry both the validated internal profile list and the
;;; raw user-authored config body used by user-interface presentation.
;; : (-> [PooSandboxProfile] [UserModuleFlagEntry])
(def (agentic-ai-lab-cubeSandbox-config-flags profiles . maybe-user-config)
  (if (null? maybe-user-config)
    (yuanxu-product-field-rows
     (:backend-capability-registry
      agentic-ai-lab-cubeSandbox-backend-capability-registry)
     (:config profiles))
    (yuanxu-product-field-rows
     (:backend-capability-registry
      agentic-ai-lab-cubeSandbox-backend-capability-registry)
     (:config profiles)
     (:user-config (car maybe-user-config)))))

;;; Backend wrappers pass their inherited profile object into sandbox-core; this
;;; keeps user syntax thin while object merge semantics stay centralized.
;; : (-> Symbol [SandboxProfileForm] PooSandboxProfile)
(def (agentic-ai-lab-cubeSandbox-profile-config name-value forms)
  (agentic-ai-lab-sandbox-profile-object-config
   agentic-ai-lab-cubeSandbox-profile-object
   'cube
   name-value
   forms))

;;; Derived CubeSandbox profiles reuse the sandbox-core POO derivation path;
;;; this wrapper supplies only the backend profile object.
;; : (-> PooSandboxProfile Symbol [SandboxProfileForm] Alist PooSandboxProfile)
(def (agentic-ai-lab-cubeSandbox-profile-derive-config parent-profile
                                                 name-value
                                                 forms
                                                 options)
  (agentic-ai-lab-sandbox-profile-object-derive
   agentic-ai-lab-cubeSandbox-profile-object
   parent-profile
   name-value
   forms
   options))

;;; Profile row macros quote the profile name and forms only; validation is
;;; delegated to the backend profile object above.
;; agentic-ai-lab-cubeSandbox-profile
;;   : (-> Symbol SandboxProfileForm... PooSandboxProfile)
;;   | doc m%
;;       `agentic-ai-lab-cubeSandbox-profile` documents the policy boundary that the
;;       Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-cubeSandbox-profile ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules agentic-ai-lab-cubeSandbox-profile ()
  ((_ name form ...)
   (agentic-ai-lab-cubeSandbox-profile-config 'name '(form ...))))

;;; Backend-specific shorthand over the shared sandbox-core POO derive helper.
;; agentic-ai-lab-cubeSandbox-profile-derive
;;   : (-> PooSandboxProfile Symbol DerivationOption... SandboxProfileForm... PooSandboxProfile)
;;   | doc m%
;;       `agentic-ai-lab-cubeSandbox-profile-derive` documents the policy boundary
;;       that the Gerbil policy harness treats as agent-facing behavior. The
;;       example keeps the call shape visible without duplicating
;;       implementation details.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-cubeSandbox-profile-derive ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules agentic-ai-lab-cubeSandbox-profile-derive ()
  ((_ parent name (option ...) form ...)
   (agentic-ai-lab-cubeSandbox-profile-derive-config
    parent
    'name
    '(form ...)
    '(option ...)))
  ((_ parent name form ...)
   (agentic-ai-lab-cubeSandbox-profile-derive-config
    parent
    'name
    '(form ...)
    '())))

;;; Multiple CubeSandbox profile rows remain ordered user declarations for the
;;; module-system facade and presentation tests.
;; agentic-ai-lab-cubeSandbox-profiles
;;   : (-> CubeSandboxProfileRow... [PooSandboxProfile])
;;   | doc m%
;;       `agentic-ai-lab-cubeSandbox-profiles` documents the policy boundary that the
;;       Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-cubeSandbox-profiles ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules agentic-ai-lab-cubeSandbox-profiles ()
  ((_)
   '())
  ((_ profile-clause ...)
   (agentic-ai-lab-sandbox-profile-object-profiles
    agentic-ai-lab-cubeSandbox-profile-config
    agentic-ai-lab-cubeSandbox-profile-derive-config
    profile-clause ...)))
