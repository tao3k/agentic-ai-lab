;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream Funflow CI/CD POO authoring gate configuration.
;;; Invariant: formal POO use-module config only; no runtime work.

(import (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy agentic-ai-lab-product-use-module)
        (only-in :tao3k/yuanxu/modules/funflow/config-adapter yuanxu-funflow-poo-pipeline->check-map)
        (only-in :clan/poo/object .def)
        (only-in :tao3k/yuanxu/modules/funflow/config-prototypes funflow-check funflow-pipeline)
        (only-in :agentic-ai-lab/modules/workflow/funflow-config agentic-ai-lab-funflow-config-flags))

(export agentic-ai-lab-custom-my-module-poo-introspection-case)

(def agentic-ai-lab-custom-my-module-poo-introspection-case
  (let ()
    (.def (funflow/profile-authoring @ funflow-check)
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
    (.def (funflow/readiness @ funflow-check)
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
    (.def (funflow/poo-authoring-gate @ funflow-pipeline)
      pipeline-name: 'poo-authoring-gate
      checks: (list funflow/profile-authoring funflow/readiness)
      metadata: '((scenario . poo-authoring-gate)
                (authoring-style . gerbil-poo)))
    (agentic-ai-lab-product-use-module 'funflow
      (agentic-ai-lab-funflow-config-flags
        (yuanxu-funflow-poo-pipeline->check-map funflow/poo-authoring-gate)
        (list ':config funflow/poo-authoring-gate)))))
