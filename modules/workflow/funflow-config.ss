;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product selection and runtime handoff adaptation; no Core back dependency.
(import :clan/poo/object :yuanxu/modules/funflow/graph-projection
 :yuanxu/modules/funflow/config-adapter
 :yuanxu/module-system/selection/objects
 :agentic-ai-lab/modules/module-authoring/module-config-syntax
 :agentic-ai-lab/modules/workflow/funs)
(export agentic-ai-lab-funflow-configs
        agentic-ai-lab-funflow-poo-config-flags
        agentic-ai-lab-funflow-config-flags
        agentic-ai-lab-funflow-pipeline-runtime-command-manifests
        agentic-ai-lab-funflow-module-bundles
        poo-upstream-flow-funflow-module-bundles)
;;; Module-owned user syntax delegates to the one generic config lowering.
(defsyntax (agentic-ai-lab-funflow-configs stx)
  (syntax-case stx ()
    ((_ config-form ...)
     (syntax
      (agentic-ai-lab-module-configs
       funflow
       agentic-ai-lab-funflow-poo-config-flags
       (quoted :config config-form ...)
       config-form ...)))))

;;; Funflow owns the public pipeline object, while workflow/cicd owns the
;;; runtime-command manifest projection shape.
;; : (-> YuanxuCicdCheckMap [PooSandboxProfile] Alist)
(def (agentic-ai-lab-funflow-pipeline-runtime-command-manifests
      pipeline
      . maybe-profile-catalog)
  (if (null? maybe-profile-catalog)
    (agentic-ai-lab-cicd-check-map->runtime-command-manifests pipeline)
    (agentic-ai-lab-cicd-check-map->runtime-command-manifests
     pipeline
     (car maybe-profile-catalog))))

;;; Boundary: funflow poo config pipelines is the policy-visible edge for
;;; policy behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [AgenticAILabFunflowConfigPrototype] [YuanxuCicdCheckMap] [YuanxuCicdCheckMap])
(def (agentic-ai-lab-funflow-poo-config-pipelines/rev prototypes pipelines-rev)
  (if (null? prototypes)
    pipelines-rev
    (let (pipeline
          (agentic-ai-lab-funflow-poo-config-pipeline (car prototypes)))
      (agentic-ai-lab-funflow-poo-config-pipelines/rev
       (cdr prototypes)
       (if pipeline
         (cons pipeline pipelines-rev)
         pipelines-rev)))))

;; : (-> [AgenticAILabFunflowConfigPrototype] [YuanxuCicdCheckMap])
(def (agentic-ai-lab-funflow-poo-config-pipelines prototypes)
  (if (list? prototypes)
    (reverse (agentic-ai-lab-funflow-poo-config-pipelines/rev prototypes '()))
    (error "funflow POO config prototypes must be a list" prototypes)))

;; : (-> AgenticAILabFunflowConfigPrototype MaybeYuanxuCicdCheckMap)
(def (agentic-ai-lab-funflow-poo-config-pipeline prototype)
  (and (yuanxu-funflow-poo-pipeline? prototype)
       (yuanxu-funflow-poo-pipeline->check-map prototype)))

;; : (-> [AgenticAILabFunflowConfigPrototype] Alist [UserModuleFlagEntry])
(def (agentic-ai-lab-funflow-poo-config-flags prototypes user-config)
  (let (pipelines (agentic-ai-lab-funflow-poo-config-pipelines prototypes))
    (yuanxu-funflow-require
     "funflow POO config must define exactly one funflow-pipeline"
     (= (length pipelines) 1)
     prototypes)
    (agentic-ai-lab-funflow-config-flags (car pipelines) user-config)))

;;; Config flags carry both the normal Funflow feature vocabulary and the POO
;;; check-map object. This keeps `use-module` ergonomic while giving downstream
;;; tools a typed object to inspect before runtime handoff.
;; : (-> YuanxuCicdCheckMap Alist [UserModuleFlagEntry])
(def (agentic-ai-lab-funflow-config-flags pipeline user-config)
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
(def agentic-ai-lab-funflow-module-bundles
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
  agentic-ai-lab-funflow-module-bundles)
