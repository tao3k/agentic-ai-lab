;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: construct values from prototypes owned by explicit Type declarations.
(import (only-in :clan/poo/object .o .mix .ref)
        (only-in :clan/poo/mop validate)
        :core/module-system/schema/relations
        :core/module-system/types
        (only-in :core/module-system/objects
                 SemanticModule. ModuleSourceRole. ModuleAuthoringProfile.
                 make-semantic-module))
(export SemanticModule. ModuleSourceRole.
        ModuleAuthoringProfile. ModuleAuthoringExecutor.
        TypesSourceRole. ObjectsSourceRole. FunsSourceRole.
        ConfigSourceRole. UserConfigSourceRole.
        InterfaceSourceRole.
        SemanticModuleContract
        ModuleSourceRoleContract ModuleAuthoringProfileContract
        poo-flow-semantic-module
        poo-flow-default-module-authoring-profile
        poo-flow-user-root-module-authoring-profile)

;;; The executor stays a native POO prototype.  CLOS specializes it through
;;; the explicit prototype bridge rather than requiring a duplicate class.
(def ModuleAuthoringExecutor.
  (.o identity: 'module-authoring/default-executor))

;; : (-> Symbol [Symbol] [Symbol] [Symbol] Symbol PooModuleSourceRole)
(def (poo-flow-module-source-role identity-value recommended-forms-value
                                  forbidden-slot-verbs-value
                                  forbidden-root-forms-value freedom-value)
  (validate ModuleSourceRoleContract
    (.o (:: @ ModuleSourceRole.)
        identity: identity-value
        recommended-forms: recommended-forms-value
        forbidden-slot-verbs: forbidden-slot-verbs-value
        forbidden-root-forms: forbidden-root-forms-value
        recursive-root-forms?: #f
        forbidden-imports: '()
        forbidden-forms: '()
        forbid-raw-behavior-hooks?: #f
        forbid-raw-query-initializers?: #t
        repair-operators: '(? => =>.+ override)
        freedom: freedom-value)))

;;; Role Profiles state the default engineering envelope.  They intentionally
;;; admit ordinary Scheme helpers; the Contract rejects only competing public
;;; semantics, leaving algorithms and domain behavior open to the module owner.
(def TypesSourceRole.
  (poo-flow-module-source-role
   'types '(define-type def defstruct) '(add remove replace delete) '()
   'open-with-boundary-contracts))
(def ObjectsSourceRole.
  (poo-flow-module-source-role
   'objects '(.def .o .defgeneric defmethod) '(add remove replace delete) '()
   'open-native-poo))
(def FunsSourceRole.
  (poo-flow-module-source-role
   'funs '(def lambda) '(add remove replace delete) '()
   'open-pure-functions))
(def ConfigSourceRole.
  (poo-flow-module-source-role
   'config '(.def .o user-composition use-module)
   '(add remove replace delete)
   '(stage graph loop prove handoff provider runtime)
   'composition-only))

;;; The ordinary user root is deliberately narrower than a maintained module's
;;; config.ss.  It selects maintained values and never reopens the advanced
;;; POO object layer; vertical owners retain that layer in their own Profiles.
(def UserConfigSourceRole.
  (validate ModuleSourceRoleContract
    (.o (:: @ ConfigSourceRole.)
        identity: 'user-config
        recommended-forms: '(user-composition compose use-module)
        forbidden-root-forms:
        '(.def .o stage graph loop prove handoff provider runtime)
        recursive-root-forms?: #t
        forbidden-imports:
        '(:clan/poo/mop
          :core/poo-clos/interface)
        forbidden-forms:
        '(poo-clos-class
          poo-clos-generic-function
          poo-clos-method
          poo-clos-method-bundle
          .defmethod-bundle)
        forbid-raw-behavior-hooks?: #t
        forbid-raw-query-initializers?: #t
        freedom: 'maintained-value-composition-only)))
(def InterfaceSourceRole.
  (poo-flow-module-source-role
   'interface '(import export) '(add remove replace delete) '()
   'reexport-only))

(def (poo-flow-default-module-authoring-profile)
  (validate ModuleAuthoringProfileContract
    (.o (:: @ ModuleAuthoringProfile.)
        executor: (.mix ModuleAuthoringExecutor.)
        types: TypesSourceRole.
        objects: ObjectsSourceRole.
        funs: FunsSourceRole.
        config: ConfigSourceRole.
        interface: InterfaceSourceRole.)))

(def (poo-flow-user-root-module-authoring-profile)
  (validate ModuleAuthoringProfileContract
    (.o (:: @ (poo-flow-default-module-authoring-profile))
        config: UserConfigSourceRole.)))

;; : (-> ModuleIdentity imports: ModuleImports capabilities: ModuleCapabilities profiles: ModuleProfiles authoring: ModuleAuthoringProfile SemanticModule)
(def (poo-flow-semantic-module identity-value
                             imports: (imports-value (poo-flow-empty-imports))
                             capabilities: (capabilities-value (poo-flow-empty-capabilities))
                             profiles: (profiles-value (poo-flow-empty-profiles))
                             authoring: (authoring-value
                                         (poo-flow-default-module-authoring-profile)))
  (make-semantic-module identity-value authoring-value
                        imports: imports-value
                        capabilities: capabilities-value
                        profiles: profiles-value))
