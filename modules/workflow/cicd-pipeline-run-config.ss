;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: workflow CI/CD pipeline run/result projection for user config.
;;; Invariant: this owner emits handoff-readiness data and never executes CI.

(import :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/sandbox-core/profile-catalog
        :agentic-ai-lab/modules/workflow/cicd-config
        (only-in :agentic-ai-lab/modules/workflow/funs
                 agentic-ai-lab-cicd-check-map->pipeline-run
                 agentic-ai-lab-cicd-check-map->pipeline-result))

(export agentic-ai-lab-user-workflow-cicd-pipeline-runs/add
        agentic-ai-lab-user-config-workflow-cicd-pipeline-runs
        agentic-ai-lab-user-workflow-cicd-pipeline-results
        agentic-ai-lab-user-config-workflow-cicd-pipeline-results)

;;; Pipeline runs are the tutorial-facing projection over check maps. They use
;;; the selected sandbox profile catalog so run status matches user config.
;; : (-> [YuanxuCicdCheckMap] [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-user-workflow-cicd-pipeline-runs/add check-maps
                                                     profile-catalog)
  (cond
   ((null? check-maps) '())
   (else
    (cons
     (agentic-ai-lab-cicd-check-map->pipeline-run
      (car check-maps)
      profile-catalog)
     (agentic-ai-lab-user-workflow-cicd-pipeline-runs/add
      (cdr check-maps)
      profile-catalog)))))

;;; Config-level pipeline runs expose "what would run" without duplicating the
;;; runtime command manifest or Marlin ABI surfaces.
;; : (-> PooUserConfig [Alist])
(def (agentic-ai-lab-user-config-workflow-cicd-pipeline-runs config)
  (let* ((selected-modules (yuanxu-user-config-modules config))
         (profile-catalog
          (agentic-ai-lab-user-config-sandbox-profile-catalog selected-modules)))
    (agentic-ai-lab-user-workflow-cicd-pipeline-runs/add
     (agentic-ai-lab-user-config-workflow-cicd-check-maps config)
     profile-catalog)))

;;; Result projections are derived from pipeline runs so presentation and tests
;;; see the same admission status that runtime handoff will consume.
;; : (-> [YuanxuCicdCheckMap] [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-user-workflow-cicd-pipeline-results check-maps
                                                    profile-catalog)
  (cond
   ((null? check-maps) '())
   (else
    (cons
     (agentic-ai-lab-cicd-check-map->pipeline-result
      (car check-maps)
      profile-catalog)
     (agentic-ai-lab-user-workflow-cicd-pipeline-results
      (cdr check-maps)
      profile-catalog)))))

;;; Config-level results are receipt-sized pipeline summaries. They remain
;;; handoff readiness data, not CI execution output.
;; : (-> PooUserConfig [Alist])
(def (agentic-ai-lab-user-config-workflow-cicd-pipeline-results config)
  (let* ((selected-modules (yuanxu-user-config-modules config))
         (profile-catalog
          (agentic-ai-lab-user-config-sandbox-profile-catalog selected-modules)))
    (agentic-ai-lab-user-workflow-cicd-pipeline-results
     (agentic-ai-lab-user-config-workflow-cicd-check-maps config)
     profile-catalog)))
