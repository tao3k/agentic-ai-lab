;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream Funflow CI/CD POO authoring gate configuration.
;;; Invariant: formal POO-native use-module config only; no runtime work.

(import (only-in :clan/poo/object .def)
        (only-in :yuanxu/modules/funflow/config-prototypes funflow-check funflow-pipeline)
        (only-in :agentic-ai-lab/modules/workflow/funflow-config agentic-ai-lab-funflow-configs))

(export agentic-ai-lab-custom-my-module-poo-introspection-case)

(def agentic-ai-lab-custom-my-module-poo-introspection-case
  (agentic-ai-lab-funflow-configs
  (.def (funflow/profile-authoring @ funflow-check
                                   check-name profile-ref command-vector
                                   artifact-outputs cache-intents
                                   result-protocol runtime-mode
                                   observability observes guards report)
    check-name: 'profile-authoring
    profile-ref: 'ci/build
    command-vector: '("gxpkg"
                      "env"
                      "gxtest"
                      "t/sandbox-core-profile-authoring-diagnostics-test.ss")
    artifact-outputs: '(poo-authoring-report)
    cache-intents: '(gerbil-build-cache)
    result-protocol: '(read :lines)
    runtime-mode: 'manifest-handoff
    observability: 'poo-slot-authoring-summary
    observes: '(profile-slots object-extension funflow-check-metadata)
    guards: '(self-referential-slot-initializer primitive-shadow-slot)
    report: 'authoring-report)

  (.def (funflow/readiness @ funflow-check
                           check-name profile-ref command-vector
                           artifact-outputs result-protocol runtime-mode
                           dependency-refs)
    check-name: 'funflow-readiness
    profile-ref: 'ci/check
    command-vector: '("gxpkg"
                      "env"
                      "gxtest"
                      "t/user-interface-cicd-pipeline-run-test.ss")
    artifact-outputs: '(runtime-manifest-readiness)
    result-protocol: '(read :lines)
    runtime-mode: 'manifest-handoff
    dependency-refs: '(profile-authoring))

  (.def (funflow/poo-authoring-gate @ funflow-pipeline
                                    pipeline-name checks metadata)
    pipeline-name: 'poo-authoring-gate
    checks: (list funflow/profile-authoring funflow/readiness)
    metadata: '((scenario . poo-authoring-gate)
                (authoring-style . gerbil-poo-native)))))
