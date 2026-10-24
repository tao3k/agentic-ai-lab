;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: nono sandbox kernel module selection.
;;; Invariant: object inheritance and row extension live in objects.ss owners.

(import :agentic-ai-lab/modules/nono-sandbox/objects
        :agentic-ai-lab/modules/sandbox-core/objects
        :yuanxu/module-system/selection/objects
        :yuanxu/utilities/final-projection-syntax)

(export agentic-ai-lab-nono-sandbox-module-bundles
        +agentic-ai-lab-nono-sandbox-default-binding+
        agentic-ai-lab-nono-sandbox-binding-config
        agentic-ai-lab-nono-sandbox-config-flags
        agentic-ai-lab-nono-sandbox-profile-config
        agentic-ai-lab-nono-sandbox-profile-derive-config
        agentic-ai-lab-nono-sandbox-profile
        agentic-ai-lab-nono-sandbox-profile-derive
        agentic-ai-lab-nono-sandbox-profiles)

;;; Nono is a sandbox module row; Marlin remains the runtime owner, not the row.
;; : (-> Unit [[PooUserModuleSelection]])
(def agentic-ai-lab-nono-sandbox-module-bundles
  (list
   (list
    (yuanxu-user-module-selection
     'sandbox 'nono-sandbox
     (list '+nono '+native-ffi '+doctor
           (cons ':backend-capability-registry
                 agentic-ai-lab-nono-sandbox-backend-capability-registry))))))

;; : Symbol
(def +agentic-ai-lab-nono-sandbox-default-binding+ 'native-ffi)

;;; Module-level binding flags are user-visible configuration facts. The
;;; native FFI implementation remains in native.ss; this layer only records the
;;; selected binding strategy for use-module/module presentation.
;; : (-> Symbol Symbol)
(def (agentic-ai-lab-nono-sandbox-binding-config binding-value)
  binding-value)

;;; Boundary: nono sandbox config flags is the policy-visible edge for sandbox
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Symbol [PooSandboxProfile] [UserModuleFlagEntry])
(def (agentic-ai-lab-nono-sandbox-config-flags binding-value profiles . maybe-user-config)
  (if (null? maybe-user-config)
    (yuanxu-product-field-rows
     (:binding (agentic-ai-lab-nono-sandbox-binding-config binding-value))
     (:backend-capability-registry
      agentic-ai-lab-nono-sandbox-backend-capability-registry)
     (:config profiles))
    (yuanxu-product-field-rows
     (:binding (agentic-ai-lab-nono-sandbox-binding-config binding-value))
     (:backend-capability-registry
      agentic-ai-lab-nono-sandbox-backend-capability-registry)
     (:config profiles)
     (:user-config (car maybe-user-config)))))

;;; Backend wrappers pass their inherited profile object into sandbox-core; nono
;;; runtime state stays in native.ss while module flags record binding choice.
;; : (-> Symbol [SandboxProfileForm] PooSandboxProfile)
(def (agentic-ai-lab-nono-sandbox-profile-config name-value forms)
  (agentic-ai-lab-sandbox-profile-object-config
   agentic-ai-lab-nono-sandbox-profile-object
   'nono
   name-value
   forms))

;;; Derived nono profiles keep project/session/branch/task splits on the same
;;; POO object merge path as ordinary profile rows.
;; : (-> PooSandboxProfile Symbol [SandboxProfileForm] Alist PooSandboxProfile)
(def (agentic-ai-lab-nono-sandbox-profile-derive-config parent-profile
                                                  name-value
                                                  forms
                                                  options)
  (agentic-ai-lab-sandbox-profile-object-derive
   agentic-ai-lab-nono-sandbox-profile-object
   parent-profile
   name-value
   forms
   options))

;;; Profile row macros quote user syntax and leave validation to the inherited
;;; nono profile object.
;; agentic-ai-lab-nono-sandbox-profile
;;   : (-> Symbol SandboxProfileForm... PooSandboxProfile)
;;   | doc m%
;;       `agentic-ai-lab-nono-sandbox-profile` documents the sandbox boundary that
;;       the Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-nono-sandbox-profile ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules agentic-ai-lab-nono-sandbox-profile ()
  ((_ name form ...)
   (agentic-ai-lab-nono-sandbox-profile-config 'name '(form ...))))

;;; Derived profile rows are a user-facing shorthand over the sandbox-core POO
;;; derivation API. Options are derivation metadata such as scope/scope-ref.
;; agentic-ai-lab-nono-sandbox-profile-derive
;;   : (-> PooSandboxProfile Symbol DerivationOption... SandboxProfileForm... PooSandboxProfile)
;;   | doc m%
;;       `agentic-ai-lab-nono-sandbox-profile-derive` documents the sandbox boundary
;;       that the Gerbil policy harness treats as agent-facing behavior. The
;;       example keeps the call shape visible without duplicating
;;       implementation details.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-nono-sandbox-profile-derive ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules agentic-ai-lab-nono-sandbox-profile-derive ()
  ((_ parent name (option ...) form ...)
   (agentic-ai-lab-nono-sandbox-profile-derive-config
    parent
    'name
    '(form ...)
    '(option ...)))
  ((_ parent name form ...)
   (agentic-ai-lab-nono-sandbox-profile-derive-config
    parent
    'name
    '(form ...)
    '())))

;;; Nono profile rows inherit backend kind from the selected module. Users name
;;; profile refs and policy rows; the module config owns backend projection.
;; agentic-ai-lab-nono-sandbox-profiles
;;   : (-> NonoSandboxProfileRow... [PooSandboxProfile])
;;   | doc m%
;;       `agentic-ai-lab-nono-sandbox-profiles` documents the sandbox boundary that
;;       the Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-nono-sandbox-profiles ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules agentic-ai-lab-nono-sandbox-profiles ()
  ((_)
   '())
  ((_ profile-clause ...)
   (agentic-ai-lab-sandbox-profile-object-profiles
    agentic-ai-lab-nono-sandbox-profile-config
    agentic-ai-lab-nono-sandbox-profile-derive-config
    profile-clause ...)))
