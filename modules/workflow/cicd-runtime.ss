;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; CI/CD runtime handoff facade.
;;; Downstream policy families import this module as the stable runtime surface,
;;; while checks, graph analysis, pipeline projection, and Marlin ABI assembly
;;; stay in separate owner leaves to keep policy repair local to the branch that
;;; owns the behavior.

(import (only-in :agentic-ai-lab/modules/workflow/cicd-runtime-support/checks
                 agentic-ai-lab-cicd-check->runtime-command-manifest
                 agentic-ai-lab-cicd-check->receipt
                 agentic-ai-lab-cicd-check-map->receipts
                 agentic-ai-lab-cicd-check-map->runtime-manifest-readiness
                 agentic-ai-lab-cicd-check-map->runtime-command-manifests)
        (only-in :yuanxu/modules/funflow/dependency-graph
                 yuanxu-cicd-check-map->dependency-graph)
        (only-in :agentic-ai-lab/modules/workflow/cicd-runtime-support/pipeline
                 agentic-ai-lab-cicd-check->pipeline-run-step
                 agentic-ai-lab-cicd-check-map->pipeline-run
                 agentic-ai-lab-cicd-pipeline-run->result
                 agentic-ai-lab-cicd-check-map->pipeline-result)
        (only-in :agentic-ai-lab/modules/workflow/cicd-runtime-support/marlin-abi
                 agentic-ai-lab-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
                 agentic-ai-lab-cicd-check-map->marlin-runtime-handoff-abi))

(export yuanxu-cicd-check-map->dependency-graph
        agentic-ai-lab-cicd-check->pipeline-run-step
        agentic-ai-lab-cicd-check-map->pipeline-run
        agentic-ai-lab-cicd-pipeline-run->result
        agentic-ai-lab-cicd-check-map->pipeline-result
        agentic-ai-lab-cicd-check->receipt
        agentic-ai-lab-cicd-check-map->receipts
        agentic-ai-lab-cicd-check-map->runtime-manifest-readiness
        agentic-ai-lab-cicd-check->runtime-command-manifest
        agentic-ai-lab-cicd-check-map->runtime-command-manifests
        agentic-ai-lab-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
        agentic-ai-lab-cicd-check-map->marlin-runtime-handoff-abi)
