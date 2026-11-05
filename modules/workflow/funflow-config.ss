;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product selection and runtime handoff adaptation; no Core back dependency.
(import :clan/poo/object :yuanxu/modules/funflow/graph-projection
 :yuanxu/modules/funflow/config-adapter
 :yuanxu/module-system/selection/objects

 (only-in :agentic-ai-lab/modules/workflow/cicd-runtime agentic-ai-lab-cicd-check-map->runtime-command-manifests))
(export agentic-ai-lab-funflow-config-flags
        agentic-ai-lab-funflow-pipeline-runtime-command-manifests
        agentic-ai-lab-funflow-module-bundles)
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
