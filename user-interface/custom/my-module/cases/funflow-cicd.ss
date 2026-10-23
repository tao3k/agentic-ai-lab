;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream Funflow CI/CD pipeline declaration.
;;; Invariant: this file declares POO workflow objects only; no runtime work.

(import (only-in :clan/poo/object .def)
        (only-in :yuanxu/modules/funflow/config-prototypes funflow-check funflow-pipeline)
        (only-in :agentic-ai-lab/modules/workflow/funflow-config agentic-ai-lab-funflow-configs))

(export agentic-ai-lab-custom-my-module-funflow-cicd-case)

(def agentic-ai-lab-custom-my-module-funflow-cicd-case
  (agentic-ai-lab-funflow-configs
  (.def (funflow/build @ funflow-check
                       check-name profile-ref command-vector
                       artifact-outputs cache-intents result-protocol
                       runtime-mode durable-task-id action-class
                       artifact-retention)
    check-name: 'build
    profile-ref: 'ci/build
    command-vector: '("gerbil" "build")
    artifact-outputs: '(build-log)
    cache-intents: '(gerbil-build-cache)
    result-protocol: '(read :lines)
    runtime-mode: 'manifest-handoff
    durable-task-id: 'task/build
    action-class: 'idempotent
    artifact-retention: 'project-retained)

  (.def (funflow/test @ funflow-check
                      check-name profile-ref command-vector
                      artifact-outputs result-protocol runtime-mode
                      dependency-refs durable-task-id action-class)
    check-name: 'test
    profile-ref: 'ci/check
    command-vector: '("gerbil" "env" "./unit-tests.ss")
    artifact-outputs: '(test-receipt)
    result-protocol: '(read :lines)
    runtime-mode: 'manifest-handoff
    dependency-refs: '(build)
    durable-task-id: 'task/test
    action-class: 'idempotent)

  (.def (funflow/package @ funflow-check
                         check-name profile-ref command-vector
                         artifact-outputs result-protocol runtime-mode
                         dependency-refs durable-task-id action-class
                         compensation-refs artifact-retention)
    check-name: 'package
    profile-ref: 'ci/check
    command-vector: '("gerbil" "env" "./unit-tests.ss")
    artifact-outputs: '(dependency-graph-receipt)
    result-protocol: '(read :lines)
    runtime-mode: 'manifest-handoff
    dependency-refs: '(test)
    durable-task-id: 'task/package
    action-class: 'compensatable
    compensation-refs: '(cleanup/package-artifacts)
    artifact-retention: 'release-retained)

  (.def (funflow/default @ funflow-pipeline
                         pipeline-name checks metadata)
    pipeline-name: 'default
    checks: (list funflow/build funflow/test funflow/package)
    metadata: '((scenario . funflow-cicd)
                (authoring-style . gerbil-poo-native)))))
