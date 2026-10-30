;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile POO object and prototype projection.

(import :gerbil/core
        (only-in :clan/poo/object .def .o .ref .slot? object?)
        :yuanxu/graph/interface
        :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/sandbox-core/shared-object
        :agentic-ai-lab/modules/agent-sandbox/config
        (only-in :agentic-ai-lab/modules/agent-sandbox/profile-validation
                 agent-sandbox-profile-resource-policy-filesystem-entry?
                 agent-sandbox-profile-resource-policy-filesystem-diagnostics)
        :agentic-ai-lab/modules/sandbox-core/resource-contract
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy)

(export agentic-ai-lab-sandbox-core-profile-object
        agentic-ai-lab-sandbox-profile-prototype
        agentic-ai-lab-sandbox-profile-prototype-slot/default
        agentic-ai-lab-sandbox-profile-prototype-slot/either
        agentic-ai-lab-sandbox-profile-prototype->profile
        agentic-ai-lab-sandbox-profile-prototypes)


;;; The core profile object supplies the shared prototype for sandbox backends.
;;; Backend modules extend it; users only see the resulting profile rows.
;; : PooModuleObject
;; | PooSandboxCoreProfileObject = PooModuleObject
(def agentic-ai-lab-sandbox-core-profile-object
  (yuanxu-module-object
   'objects.sandbox-core.profile
   (list agentic-ai-lab-shared-sandbox-object)
   (list
    (yuanxu-module-field-contract
     'profile-name YuanxuModuleSymbolType 'override 'default
     '((scope . sandbox-core) (dsl-row . profile-name)))
    (yuanxu-module-field-contract
     'backend-kind YuanxuModuleSymbolType 'override 'sandbox
     '((scope . sandbox-core) (owned-by . module-config)))
    (yuanxu-module-field-contract
     'backend-ref YuanxuModuleSymbolType 'override 'sandbox-profile
     '((scope . sandbox-core) (owned-by . module-config)))
    (yuanxu-module-field-contract
     'network-policy YuanxuModuleListType 'override '(deny-by-default)
     '((scope . sandbox-core) (dsl-row . network)))
    (yuanxu-module-field-contract
     'capabilities YuanxuModuleListType 'override '(process-run filesystem-read tmpdir)
     '((scope . sandbox-core) (dsl-row . capabilities)))
    (yuanxu-module-field-contract
     'backend-capability YuanxuModuleObjectType 'override
     agentic-ai-lab-sandbox-backend-capability/sandbox
     '((scope . sandbox-core) (owned-by . module-config)))
    (yuanxu-module-field-contract
     'profile-policy YuanxuModuleObjectType 'override
     agentic-ai-lab-sandbox-profile-policy/default
     '((scope . sandbox-core) (owned-by . policy-object)))
    (yuanxu-module-field-contract
     'resource-policy YuanxuModuleListType 'override
     '((filesystem
        (scope . runtime)
        (materialized-by . runtime)
        (mounts . runtime)))
     '((scope . sandbox-core) (dsl-row . resources)))
    (yuanxu-module-field-contract
     'metadata YuanxuModuleListType 'append '()
     '((scope . sandbox-core) (dsl-row . metadata))))
   '((namespace . objects.sandbox-core)
     (domain . profile)
     (collection . sandbox.profile)
     (developer-owned . #t)
     (inherits . objects.shared.sandbox))))

;;; The neutral sandbox profile prototype is backend-agnostic. Backend modules
;;; extend it rather than rewriting a resource-policy alist from scratch.
;; : PooSandboxProfilePrototype
(.def agentic-ai-lab-sandbox-profile-prototype
  backend-kind: 'sandbox
  backend-ref: 'sandbox-profile
  network-policy: '(deny-by-default)
  capabilities: '(process-run filesystem-read tmpdir)
  resources: agentic-ai-lab-runtime-volume-resources-prototype
  metadata: '((declared-by . agentic-ai-lab-poo-prototype)
              (runtime-executed . #f)))

;;; Profile projection is report-only control-plane data. It materializes the
;;; POO profile prototype as the existing public sandbox profile object without
;;; executing Docker, nono, Cube, or Marlin runtime work.
;; : (-> PooSandboxProfilePrototype Symbol Value)
(def (agentic-ai-lab-sandbox-profile-prototype-slot/default prototype slot default)
  (if (.slot? prototype slot)
    (.ref prototype slot)
    default))

;;; Public user profiles use `network` and `resources`; older internal
;;; projections may still carry `network-policy` and `resource-policy`.
;; : (-> PooSandboxProfilePrototype Symbol Symbol Value)
(def (agentic-ai-lab-sandbox-profile-prototype-slot/either prototype
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
(def (agentic-ai-lab-sandbox-profile-prototype->profile name-value prototype)
  (let* ((backend-ref-value
          (agentic-ai-lab-sandbox-profile-prototype-slot/default
           prototype
           'backend-ref
           #f))
         (resources
          (agentic-ai-lab-sandbox-profile-prototype-slot/either
           prototype
           'resources
           'resource-policy
           '())))
    (.o kind: agentic-ai-lab-sandbox-profile-kind
        name: name-value
        backend-kind: (agentic-ai-lab-sandbox-profile-prototype-slot/default
                       prototype
                       'backend-kind
                       'sandbox)
        backend-ref: (if backend-ref-value backend-ref-value name-value)
        network-policy: (agentic-ai-lab-sandbox-profile-prototype-slot/either
                         prototype
                         'network
                         'network-policy
                         '(deny-by-default))
        capabilities: (agentic-ai-lab-sandbox-profile-prototype-slot/default
                       prototype
                       'capabilities
                       '(process-run filesystem-read tmpdir))
        resource-policy: (agentic-ai-lab-sandbox-resources-value->resource-policy
                          resources)
        metadata: (agentic-ai-lab-sandbox-profile-prototype-slot/default
                   prototype
                   'metadata
                   '()))))

;; agentic-ai-lab-sandbox-profile-prototypes
;;   : (-> (ProfileName PooSandboxProfilePrototype)... [PooSandboxProfile])
;;   | doc m%
;;       `agentic-ai-lab-sandbox-profile-prototypes` keeps native POO profile names
;;       visible in user files while returning sandbox profile objects consumed
;;       by runtime manifests and presentation projections.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-prototypes (agent/nono nono-prototype))
;;       ;; => (nono-profile)
;;       ```
;;     %
(defrules agentic-ai-lab-sandbox-profile-prototypes ()
  ((_)
   '())
  ((_ (name prototype) ...)
   (list (agentic-ai-lab-sandbox-profile-prototype->profile 'name prototype) ...)))

;;; Row keys are the user syntax vocabulary; slots are the POO object contract
;;; vocabulary. Keeping this table here prevents backend wrappers from drifting.
;; : (-> Symbol MaybeSymbol)
