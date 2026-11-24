;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: workflow CI/CD vocabularies and value admission predicates.
;;; Invariant: this layer imports no workflow object, function, or config owner.

(import (only-in :clan/poo/object object?)
        (only-in :std/list/list every))

(export +yuanxu-durable-action-classes+
        +yuanxu-cicd-check-map-schema+
        +yuanxu-cicd-check-receipt-schema+
        +yuanxu-cicd-pipeline-run-schema+
        +yuanxu-cicd-pipeline-result-schema+
        +yuanxu-cicd-runtime-manifest-readiness-schema+
        +yuanxu-cicd-marlin-runtime-handoff-abi-schema+
        +yuanxu-cicd-marlin-runtime-owner+
        +yuanxu-cicd-marlin-runtime-handoff-abi-fields+
        yuanxu-cicd-check-kind
        yuanxu-cicd-check-map-kind
        yuanxu-cicd-require
        yuanxu-cicd-profile-ref?
        yuanxu-cicd-command-vector?
        yuanxu-cicd-symbol-list?)

(def +yuanxu-cicd-check-map-schema+
  'yuanxu.modules.workflow.cicd.check-map.v1)
(def +yuanxu-cicd-check-receipt-schema+
  'yuanxu.modules.workflow.cicd.check-receipt.v1)
(def +yuanxu-cicd-pipeline-run-schema+
  'yuanxu.modules.workflow.cicd.pipeline-run.v1)
(def +yuanxu-cicd-pipeline-result-schema+
  'yuanxu.modules.workflow.cicd.pipeline-result.v1)
(def +yuanxu-cicd-runtime-manifest-readiness-schema+
  'yuanxu.modules.workflow.cicd.runtime-manifest-readiness.v1)
(def +yuanxu-cicd-marlin-runtime-handoff-abi-schema+
  'yuanxu.workflow.cicd.marlin-runtime-handoff-abi.v1)
(def +yuanxu-cicd-marlin-runtime-owner+ "marlin-agent-core")

(def +yuanxu-cicd-marlin-runtime-handoff-abi-fields+
  '(operation request-id artifact-handle argv request policy plan-id node-id
    frontier durable-task-id action-class artifact-refs artifact-provenance
    artifact-retention sandbox-refs checkpoint-ref compensation-refs
    runtime-owner handoff-required runtime-executed))

(def (yuanxu-cicd-check-kind) 'yuanxu.workflow.cicd.check)
(def (yuanxu-cicd-check-map-kind) 'yuanxu.workflow.cicd.check-map)

(def (yuanxu-cicd-require message ok? value)
  (unless ok? (error message value)))

(def (yuanxu-cicd-profile-ref? value)
  (or (symbol? value)
      (object? value)
      (and (pair? value)
           (list? value)
           (every yuanxu-cicd-profile-ref? value))))

(def (yuanxu-cicd-command-vector? value)
  (and (pair? value)
       (list? value)
       (every string? value)))

(def (yuanxu-cicd-symbol-list? values)
  (and (list? values) (every symbol? values)))

(def +yuanxu-durable-action-classes+
  '(replayable idempotent compensatable terminal manual))
