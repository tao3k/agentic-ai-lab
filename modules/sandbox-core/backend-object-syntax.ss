;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: hygienic macros for repeated sandbox backend module object families.
;;; Invariant: macros expand to ordinary POO module objects and field contracts.

(import :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/sandbox-core/shared-object
        :agentic-ai-lab/modules/sandbox-core/objects)

(export defpoo-sandbox-backend-object-family)

;; defpoo-sandbox-backend-object-family
;;   : (-> Identifier Identifier Identifier Identifier Identifier Syntax ...)
;;   | doc m%
;;       Internal macro family generator for sandbox backend object modules.
;;       The call site still names every exported binding, identity, slot, and
;;       contract value; the macro removes only the repeated POO construction
;;       frame shared by nono, CubeSandbox, and Docker backend modules.
;;
;;       The generated code is normal =yuanxu-module-object= and
;;       =yuanxu-module-field-contract= data. It is not a user-facing DSL.
;;     %
;; defpoo-sandbox-backend-object-family
;; : (-> SandboxBackendObjectFamilySyntax SandboxBackendObjectFamilyExpansionSyntax)
;; | doc m%
;;   Expands sandbox, backend capability, registry, and profile object family
;;   declarations into POO-native module objects.
;;   # Examples
;;   ```scheme
;;   (defpoo-sandbox-backend-object-family ...)
;;   ;; => (begin ...)
;;   ```
(defrules defpoo-sandbox-backend-object-family
  (sandbox backend profile)
  ((_ sandbox-object
      backend-capability
      backend-capability-registry
      profile-object
      module-objects
      (sandbox sandbox-identity namespace-value sandbox-inherits-value
       ((sandbox-field sandbox-type sandbox-merge sandbox-default sandbox-metadata)
        ...))
      (backend backend-key capability-value registry-metadata)
      (profile profile-identity module-value profile-inherits-value
       (profile-super ...)
       ((profile-field profile-type profile-merge profile-default profile-metadata)
        ...)))
   (begin
     ;; Engineering note: policy-sensitive helpers in this owner keep explicit
     ;; contracts adjacent to definitions so downstream reports stay actionable.
     ;; : Any
     (def sandbox-object
       (yuanxu-module-object
        'sandbox-identity
        (list agentic-ai-lab-shared-sandbox-object)
        (list
         (yuanxu-module-field-contract
          'sandbox-field sandbox-type 'sandbox-merge
          sandbox-default
          sandbox-metadata)
         ...)
        '((namespace . namespace-value)
          (domain . sandbox)
          (inherits . sandbox-inherits-value))))

     ;; : Any
     (def backend-capability
       capability-value)

     ;; : Any
     (def backend-capability-registry
       (agentic-ai-lab-sandbox-backend-capability-registry
        (list (cons 'backend-key backend-capability))
        registry-metadata))

     ;; : Any
     (def profile-object
       (yuanxu-module-object
        'profile-identity
	        (list profile-super ...)
	        (list
	         (yuanxu-module-field-contract
	          'backend YuanxuModuleSymbolType 'override
	          'backend-key
	          '((scope . backend-key)
	            (owned-by . module-config)))
	         (yuanxu-module-field-contract
	          'profile-field profile-type 'profile-merge
	          profile-default
          profile-metadata)
         ...)
        '((namespace . namespace-value)
          (domain . profile)
          (module . module-value)
          (collection . sandbox.profile)
          (backend-owned-by . use-module)
          (inherits . profile-inherits-value))))

     ;; : Any
     (def module-objects
       (list sandbox-object profile-object)))))
