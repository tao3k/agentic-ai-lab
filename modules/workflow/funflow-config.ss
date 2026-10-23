;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product selection and runtime handoff adaptation; no Core back dependency.
(import :clan/poo/object :yuanxu/modules/funflow/graph-projection
 :yuanxu/modules/funflow/config-adapter
 :yuanxu/module-system/selection/objects
 :poo-flow/modules/module-authoring/module-config-syntax
 :poo-flow/modules/workflow/funs)
(export poo-flow-funflow-configs
        poo-flow-funflow-poo-config-flags
        poo-flow-funflow-config-flags
        poo-flow-funflow-pipeline-runtime-command-manifests
        poo-flow-funflow-module-bundles
        poo-upstream-flow-funflow-module-bundles)
;;; Module-owned user syntax delegates to the one generic config lowering.
(defsyntax (poo-flow-funflow-configs stx)
  (syntax-case stx ()
    ((_ config-form ...)
     (syntax
      (poo-flow-module-configs
       funflow
       poo-flow-funflow-poo-config-flags
       (quoted :config config-form ...)
       config-form ...)))))

;;; Funflow owns the public pipeline object, while workflow/cicd owns the
;;; runtime-command manifest projection shape.
;; : (-> YuanxuCicdCheckMap [PooSandboxProfile] Alist)
(def (poo-flow-funflow-pipeline-runtime-command-manifests
      pipeline
      . maybe-profile-catalog)
  (if (null? maybe-profile-catalog)
    (poo-flow-cicd-check-map->runtime-command-manifests pipeline)
    (poo-flow-cicd-check-map->runtime-command-manifests
     pipeline
     (car maybe-profile-catalog))))

;;; Boundary: funflow poo config pipelines is the policy-visible edge for
;;; policy behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [PooFlowFunflowConfigPrototype] [YuanxuCicdCheckMap] [YuanxuCicdCheckMap])
(def (poo-flow-funflow-poo-config-pipelines/rev prototypes pipelines-rev)
  (if (null? prototypes)
    pipelines-rev
    (let (pipeline
          (poo-flow-funflow-poo-config-pipeline (car prototypes)))
      (poo-flow-funflow-poo-config-pipelines/rev
       (cdr prototypes)
       (if pipeline
         (cons pipeline pipelines-rev)
         pipelines-rev)))))

;; : (-> [PooFlowFunflowConfigPrototype] [YuanxuCicdCheckMap])
(def (poo-flow-funflow-poo-config-pipelines prototypes)
  (if (list? prototypes)
    (reverse (poo-flow-funflow-poo-config-pipelines/rev prototypes '()))
    (error "funflow POO config prototypes must be a list" prototypes)))

;; : (-> PooFlowFunflowConfigPrototype MaybeYuanxuCicdCheckMap)
(def (poo-flow-funflow-poo-config-pipeline prototype)
  (and (yuanxu-funflow-poo-pipeline? prototype)
       (yuanxu-funflow-poo-pipeline->check-map prototype)))

;; : (-> [PooFlowFunflowConfigPrototype] Alist [UserModuleFlagEntry])
(def (poo-flow-funflow-poo-config-flags prototypes user-config)
  (let (pipelines (poo-flow-funflow-poo-config-pipelines prototypes))
    (yuanxu-funflow-require
     "funflow POO config must define exactly one funflow-pipeline"
     (= (length pipelines) 1)
     prototypes)
    (poo-flow-funflow-config-flags (car pipelines) user-config)))

;;; Config flags carry both the normal Funflow feature vocabulary and the POO
;;; check-map object. This keeps `use-module` ergonomic while giving downstream
;;; tools a typed object to inspect before runtime handoff.
;; : (-> YuanxuCicdCheckMap Alist [UserModuleFlagEntry])
(def (poo-flow-funflow-config-flags pipeline user-config)
  (let* ((normalized-flow
          (yuanxu-funflow-check-map->normalized-flow pipeline))
         (plan
          (yuanxu-funflow-normalized-flow->plan normalized-flow)))
    (list '+functional
          '+dag
          '+typed-receipts
          '+runtime-manifest
          yuanxu-funflow-cicd-default-payload
          (cons ':config (list pipeline))
          (cons ':workflow-pipeline pipeline)
          (cons ':normalized-flow normalized-flow)
          (cons ':funflow-plan plan)
          (cons ':user-config user-config))))

;;; The Funflow module is the default functional DAG flow surface.
;; : (-> Unit [[PooUserModuleSelection]])
(def poo-flow-funflow-module-bundles
  (list
   (list
    (yuanxu-user-module-selection
     'flow
     'funflow
     (list '+functional
           '+dag
           '+typed-receipts
           '+runtime-manifest
           yuanxu-funflow-cicd-default-payload)))))

;; : (-> Unit [[PooUserModuleSelection]])
(def poo-upstream-flow-funflow-module-bundles
  poo-flow-funflow-module-bundles)
