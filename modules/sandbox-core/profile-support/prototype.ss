;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile POO object and prototype projection.

(import :gerbil/core
        (only-in :clan/poo/object .def .o .ref .slot? object?)
        :core/graph/interface
        :core/module-system/schema/interface
        :poo-flow/modules/sandbox-core/shared-object
        :poo-flow/modules/agent-sandbox/config
        (only-in :poo-flow/modules/agent-sandbox/profile-validation
                 agent-sandbox-profile-resource-policy-filesystem-entry?
                 agent-sandbox-profile-resource-policy-filesystem-diagnostics)
        :poo-flow/modules/sandbox-core/resource-contract
        :poo-flow/modules/sandbox-core/profile-support/policy)

(export poo-flow-sandbox-core-profile-object
        poo-flow-sandbox-profile-prototype
        poo-flow-sandbox-profile-prototype-slot/default
        poo-flow-sandbox-profile-prototype-slot/either
        poo-flow-sandbox-profile-prototype->profile
        poo-flow-sandbox-profile-prototypes)


;;; The core profile object supplies the shared prototype for sandbox backends.
;;; Backend modules extend it; users only see the resulting profile rows.
;; : PooModuleObject
;; | PooSandboxCoreProfileObject = PooModuleObject
(def poo-flow-sandbox-core-profile-object
  (poo-flow-module-object
   'objects.sandbox-core.profile
   (list poo-flow-shared-sandbox-object)
   (list
    (poo-flow-module-field-contract
     'profile-name PooFlowModuleSymbolType 'override 'default
     '((scope . sandbox-core) (dsl-row . profile-name)))
    (poo-flow-module-field-contract
     'backend-kind PooFlowModuleSymbolType 'override 'sandbox
     '((scope . sandbox-core) (owned-by . module-config)))
    (poo-flow-module-field-contract
     'backend-ref PooFlowModuleSymbolType 'override 'sandbox-profile
     '((scope . sandbox-core) (owned-by . module-config)))
    (poo-flow-module-field-contract
     'network-policy PooFlowModuleListType 'override '(deny-by-default)
     '((scope . sandbox-core) (dsl-row . network)))
    (poo-flow-module-field-contract
     'capabilities PooFlowModuleListType 'override '(process-run filesystem-read tmpdir)
     '((scope . sandbox-core) (dsl-row . capabilities)))
    (poo-flow-module-field-contract
     'backend-capability PooFlowModuleObjectType 'override
     poo-flow-sandbox-backend-capability/sandbox
     '((scope . sandbox-core) (owned-by . module-config)))
    (poo-flow-module-field-contract
     'profile-policy PooFlowModuleObjectType 'override
     poo-flow-sandbox-profile-policy/default
     '((scope . sandbox-core) (owned-by . policy-object)))
    (poo-flow-module-field-contract
     'resource-policy PooFlowModuleListType 'override
     '((filesystem
        (scope . runtime)
        (materialized-by . runtime)
        (mounts . runtime)))
     '((scope . sandbox-core) (dsl-row . resources)))
    (poo-flow-module-field-contract
     'metadata PooFlowModuleListType 'append '()
     '((scope . sandbox-core) (dsl-row . metadata))))
   '((namespace . objects.sandbox-core)
     (domain . profile)
     (collection . sandbox.profile)
     (developer-owned . #t)
     (inherits . objects.shared.sandbox))))

;;; The neutral sandbox profile prototype is backend-agnostic. Backend modules
;;; extend it rather than rewriting a resource-policy alist from scratch.
;; : PooSandboxProfilePrototype
(.def poo-flow-sandbox-profile-prototype
  backend-kind: 'sandbox
  backend-ref: 'sandbox-profile
  network-policy: '(deny-by-default)
  capabilities: '(process-run filesystem-read tmpdir)
  resources: poo-flow-runtime-volume-resources-prototype
  metadata: '((declared-by . poo-flow-poo-prototype)
              (runtime-executed . #f)))

;;; Profile projection is report-only control-plane data. It materializes the
;;; POO profile prototype as the existing public sandbox profile object without
;;; executing Docker, nono, Cube, or Marlin runtime work.
;; : (-> PooSandboxProfilePrototype Symbol Value)
(def (poo-flow-sandbox-profile-prototype-slot/default prototype slot default)
  (if (.slot? prototype slot)
    (.ref prototype slot)
    default))

;;; Public user profiles use `network` and `resources`; older internal
;;; projections may still carry `network-policy` and `resource-policy`.
;; : (-> PooSandboxProfilePrototype Symbol Symbol Value)
(def (poo-flow-sandbox-profile-prototype-slot/either prototype
                                                     public-slot
                                                     internal-slot
                                                     default)
  (cond
   ((.slot? prototype public-slot) (.ref prototype public-slot))
   ((.slot? prototype internal-slot) (.ref prototype internal-slot))
   (else default)))

;;; Boundary: sandbox profile prototype to profile is the policy-visible edge
;;; for sandbox, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol PooSandboxProfilePrototype PooSandboxProfile)
(def (poo-flow-sandbox-profile-prototype->profile name-value prototype)
  (let* ((backend-ref-value
          (poo-flow-sandbox-profile-prototype-slot/default
           prototype
           'backend-ref
           #f))
         (resources
          (poo-flow-sandbox-profile-prototype-slot/either
           prototype
           'resources
           'resource-policy
           '())))
    (.o kind: poo-flow-sandbox-profile-kind
        name: name-value
        backend-kind: (poo-flow-sandbox-profile-prototype-slot/default
                       prototype
                       'backend-kind
                       'sandbox)
        backend-ref: (if backend-ref-value backend-ref-value name-value)
        network-policy: (poo-flow-sandbox-profile-prototype-slot/either
                         prototype
                         'network
                         'network-policy
                         '(deny-by-default))
        capabilities: (poo-flow-sandbox-profile-prototype-slot/default
                       prototype
                       'capabilities
                       '(process-run filesystem-read tmpdir))
        resource-policy: (poo-flow-sandbox-resources-value->resource-policy
                          resources)
        metadata: (poo-flow-sandbox-profile-prototype-slot/default
                   prototype
                   'metadata
                   '()))))

;; poo-flow-sandbox-profile-prototypes
;;   : (-> (ProfileName PooSandboxProfilePrototype)... [PooSandboxProfile])
;;   | doc m%
;;       `poo-flow-sandbox-profile-prototypes` keeps native POO profile names
;;       visible in user files while returning sandbox profile objects consumed
;;       by runtime manifests and presentation projections.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-sandbox-profile-prototypes (agent/nono nono-prototype))
;;       ;; => (nono-profile)
;;       ```
;;     %
(defrules poo-flow-sandbox-profile-prototypes ()
  ((_)
   '())
  ((_ (name prototype) ...)
   (list (poo-flow-sandbox-profile-prototype->profile 'name prototype) ...)))

;;; Row keys are the user syntax vocabulary; slots are the POO object contract
;;; vocabulary. Keeping this table here prevents backend wrappers from drifting.
;; : (-> Symbol MaybeSymbol)
