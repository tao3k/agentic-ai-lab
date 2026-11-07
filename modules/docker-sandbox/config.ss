;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Docker sandbox kernel module selection.
;;; Invariant: Docker task-flow extension remains in the Docker module config.

(import :agentic-ai-lab/modules/docker-sandbox/objects
        :agentic-ai-lab/modules/sandbox-core/objects
        :yuanxu/module-system/selection/objects
        :yuanxu/utilities/final-projection-syntax)

(export agentic-ai-lab-docker-sandbox-module-bundles
        agentic-ai-lab-docker-sandbox-config-flags
        agentic-ai-lab-docker-sandbox-profile-config
        agentic-ai-lab-docker-sandbox-profile-derive-config
        agentic-ai-lab-docker-sandbox-profile
        agentic-ai-lab-docker-sandbox-profile-derive
        agentic-ai-lab-docker-sandbox-profiles)

;;; Docker is exposed as a sandbox module row; concrete container operations
;;; remain in runtime-facing Docker task modules.
;; : (-> Unit [[PooUserModuleSelection]])
(def agentic-ai-lab-docker-sandbox-module-bundles
  (list
   (list
    (yuanxu-user-module-selection
     'sandbox 'docker-sandbox
     (list '+docker '+doctor
           (cons ':backend-capability-registry
                 agentic-ai-lab-docker-sandbox-backend-capability-registry))))))

;;; Module config flags keep the internal POO profile payload separate from the
;;; user-authored config body shown by the user-interface presentation.
;; : (-> [PooSandboxProfile] [UserModuleFlagEntry])
(def (agentic-ai-lab-docker-sandbox-config-flags profiles . maybe-user-config)
  (if (null? maybe-user-config)
    (yuanxu-product-field-rows
     (:backend-capability-registry
      agentic-ai-lab-docker-sandbox-backend-capability-registry)
     (:config profiles))
    (yuanxu-product-field-rows
     (:backend-capability-registry
      agentic-ai-lab-docker-sandbox-backend-capability-registry)
     (:config profiles)
     (:user-config (car maybe-user-config)))))

;;; Backend wrappers pass their inherited profile object into sandbox-core; this
;;; keeps Docker-specific defaults out of the user-facing macro body.
;; : (-> Symbol [SandboxProfileForm] PooSandboxProfile)
(def (agentic-ai-lab-docker-sandbox-profile-config name-value forms)
  (agentic-ai-lab-sandbox-profile-object-config
   agentic-ai-lab-docker-sandbox-profile-object
   'docker
   name-value
   forms))

;;; Derived Docker profiles reuse the sandbox-core POO derivation path; this
;;; module only supplies the backend profile object.
;; agentic-ai-lab-docker-sandbox-profile-derive
;;   : (-> PooSandboxProfile Symbol [SandboxProfileForm] Alist PooSandboxProfile)
;;   | doc m%
;;       `agentic-ai-lab-docker-sandbox-profile-derive` documents the sandbox
;;       boundary that the Gerbil policy harness treats as agent-facing
;;       behavior. The example keeps the call shape visible without duplicating
;;       implementation details.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-docker-sandbox-profile-derive ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(def (agentic-ai-lab-docker-sandbox-profile-derive-config parent-profile
                                                    name-value
                                                    forms
                                                    options)
  (agentic-ai-lab-sandbox-profile-object-derive
   agentic-ai-lab-docker-sandbox-profile-object
   parent-profile
   name-value
   forms
   options))

;;; Profile row macros are syntax-only quotation; object validation and POO
;;; merge/remove semantics are owned by sandbox-core.
;; agentic-ai-lab-docker-sandbox-profile
;;   : (-> Symbol SandboxProfileForm... PooSandboxProfile)
;;   | doc m%
;;       `agentic-ai-lab-docker-sandbox-profile` documents the sandbox boundary that
;;       the Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-docker-sandbox-profile ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules agentic-ai-lab-docker-sandbox-profile ()
  ((_ name form ...)
   (agentic-ai-lab-docker-sandbox-profile-config 'name '(form ...))))

;;; Backend-specific shorthand over the shared sandbox-core POO derive helper.
;; agentic-ai-lab-docker-sandbox-profile-derive
;;   : (-> PooSandboxProfile Symbol DerivationOption... SandboxProfileForm... PooSandboxProfile)
;;   | doc m%
;;       `agentic-ai-lab-docker-sandbox-profile-derive` documents the sandbox
;;       boundary that the Gerbil policy harness treats as agent-facing
;;       behavior. The example keeps the call shape visible without duplicating
;;       implementation details.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-docker-sandbox-profile-derive ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules agentic-ai-lab-docker-sandbox-profile-derive ()
  ((_ parent name (option ...) form ...)
   (agentic-ai-lab-docker-sandbox-profile-derive-config
    parent
    'name
    '(form ...)
    '(option ...)))
  ((_ parent name form ...)
   (agentic-ai-lab-docker-sandbox-profile-derive-config
    parent
    'name
    '(form ...)
    '())))

;;; Docker profile collections preserve declaration order for config receipts
;;; and runtime handoff planning.
;; agentic-ai-lab-docker-sandbox-profiles
;;   : (-> DockerSandboxProfileRow... [PooSandboxProfile])
;;   | doc m%
;;       `agentic-ai-lab-docker-sandbox-profiles` documents the sandbox boundary that
;;       the Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-docker-sandbox-profiles ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules agentic-ai-lab-docker-sandbox-profiles ()
  ((_)
   '())
  ((_ profile-clause ...)
   (agentic-ai-lab-sandbox-profile-object-profiles
    agentic-ai-lab-docker-sandbox-profile-config
    agentic-ai-lab-docker-sandbox-profile-derive-config
    profile-clause ...)))
