;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; CI/CD runtime handoff facade.
;;; Downstream policy families import this module as the stable runtime surface,
;;; while checks, graph analysis, pipeline projection, and Marlin ABI assembly
;;; stay in separate owner leaves to keep policy repair local to the branch that
;;; owns the behavior.

(import (only-in :poo-flow/modules/workflow/cicd-runtime-support/checks
                 poo-flow-cicd-check->runtime-command-manifest
                 poo-flow-cicd-check->receipt
                 poo-flow-cicd-check-map->receipts
                 poo-flow-cicd-check-map->runtime-manifest-readiness
                 poo-flow-cicd-check-map->runtime-command-manifests)
        (only-in :core/modules/funflow/dependency-graph
                 poo-flow-cicd-check-map->dependency-graph)
        (only-in :poo-flow/modules/workflow/cicd-runtime-support/pipeline
                 poo-flow-cicd-check->pipeline-run-step
                 poo-flow-cicd-check-map->pipeline-run
                 poo-flow-cicd-pipeline-run->result
                 poo-flow-cicd-check-map->pipeline-result)
        (only-in :poo-flow/modules/workflow/cicd-runtime-support/marlin-abi
                 poo-flow-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
                 poo-flow-cicd-check-map->marlin-runtime-handoff-abi))

(export poo-flow-cicd-check-map->dependency-graph
        poo-flow-cicd-check->pipeline-run-step
        poo-flow-cicd-check-map->pipeline-run
        poo-flow-cicd-pipeline-run->result
        poo-flow-cicd-check-map->pipeline-result
        poo-flow-cicd-check->receipt
        poo-flow-cicd-check-map->receipts
        poo-flow-cicd-check-map->runtime-manifest-readiness
        poo-flow-cicd-check->runtime-command-manifest
        poo-flow-cicd-check-map->runtime-command-manifests
        poo-flow-cicd-runtime-command-manifest-map->marlin-runtime-handoff-abi
        poo-flow-cicd-check-map->marlin-runtime-handoff-abi)
