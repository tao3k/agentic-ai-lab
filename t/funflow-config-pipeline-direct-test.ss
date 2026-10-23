(import (only-in :agentic-ai-lab/modules/workflow/funflow-config agentic-ai-lab-funflow-pipeline-runtime-command-manifests))
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: direct Funflow POO config lowers to CI/CD runtime facts.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/modules/funflow/config-prototypes funflow-check funflow-pipeline)
         (only-in :std/test check-equal? test-suite)
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :agentic-ai-lab/modules/workflow/scenario/configuration/init-syntax
        :agentic-ai-lab/modules/workflow/cicd-config
        :agentic-ai-lab/modules/agent-sandbox/config
        :agentic-ai-lab/modules/workflow/interface)

(export funflow-config-pipeline-direct-test)

'agentic-ai-lab-import-side-effect-test-suite?

;; : (-> List Symbol Object)
(def (funflow-config-direct-alist-ref alist key)
  (match alist
    ([[(? symbol? row-key) . row-value] . rest]
     (if (eq? row-key key)
       row-value
       (funflow-config-direct-alist-ref rest key)))
    ([_ . rest]
     (funflow-config-direct-alist-ref rest key))
    (else #f)))

;; : (-> Unit [PooUserModuleSelection])
(def (funflow-config-direct-selection)
  (use-module funflow
    :config
    (.def (funflow-test/build @ funflow-check
                              check-name profile-ref command-vector
                              artifact-outputs cache-intents result-protocol
                              runtime-mode)
      check-name: 'build
      profile-ref: 'ci/build
      command-vector: '("gerbil" "build")
      artifact-outputs: '(build-log)
      cache-intents: '(gerbil-build-cache)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff)

    (.def (funflow-test/integration @ funflow-check
                                    check-name profile-ref command-vector
                                    artifact-outputs result-protocol
                                    runtime-mode dependency-refs)
      check-name: 'integration
      profile-ref: '(ci/check agent/poo-object-extension)
      command-vector: '("gerbil" "env" "./unit-tests.ss")
      artifact-outputs: '(test-receipt)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff
      dependency-refs: '(build))

    (.def (funflow-test/default @ funflow-pipeline
                                pipeline-name checks metadata)
      pipeline-name: 'default
      checks: (list funflow-test/build funflow-test/integration)
      metadata: '((scenario . direct-test)
                  (authoring-style . gerbil-poo-native)))))

;; : (-> Unit [PooSandboxProfile])
(def (funflow-config-direct-sandbox-profiles)
  (agentic-ai-lab-sandbox-profiles
   (ci/build
    (backend nono)
    (network allowlisted "github.com" "crates.io")
    (capabilities process-run filesystem-read filesystem-write tmpdir)
    (resources (filesystem
                (scope . project-workspace)
                (paths
                 ((role . project-workspace)
                  (source . ".")
                  (project-marker . "gerbil.pkg")
                  (mode . read-write)))
                (access . read-write))
               (cpu . 4)
               (memory . "8Gi")
               (timeout-ms . 600000))
    (metadata (intent . funflow-ci-build)
              (scope . funflow-test)))
   (ci/check
    (backend nono)
    (network deny-by-default)
    (capabilities process-run filesystem-read tmpdir)
    (resources (filesystem
                (scope . project-workspace)
                (paths
                 ((role . project-workspace)
                  (source . ".")
                  (project-marker . "gerbil.pkg")
                  (mode . read-only)))
                (access . read-only))
               (cpu . 1)
               (memory . "1Gi")
               (timeout-ms . 90000))
    (metadata (intent . funflow-ci-check)
              (scope . funflow-test)))))

;; : (-> Unit Symbol)
(def (run-funflow-config-pipeline-direct-checks)
  (let* ((selection (car (funflow-config-direct-selection)))
         (flags (yuanxu-user-module-selection-flags selection))
         (pipeline
          (funflow-config-direct-alist-ref flags ':workflow-pipeline))
         (checks (yuanxu-cicd-check-map-checks pipeline))
         (integration-check (cadr checks))
         (receipts
          (agentic-ai-lab-cicd-check-map->receipts
           pipeline
           (funflow-config-direct-sandbox-profiles)))
         (integration-receipt (cadr receipts))
         (manifest-map
          (agentic-ai-lab-funflow-pipeline-runtime-command-manifests
           pipeline
           (funflow-config-direct-sandbox-profiles)))
         (dependency-graph
          (funflow-config-direct-alist-ref manifest-map 'dependency-graph))
         (integration-edge
          (car (funflow-config-direct-alist-ref dependency-graph 'edges)))
         (manifests
          (funflow-config-direct-alist-ref manifest-map 'manifests))
         (integration-manifest (cadr manifests))
         (integration-request
          (funflow-config-direct-alist-ref integration-manifest 'request))
         (manifest-summaries
          (agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-summaries
           (list manifest-map)))
         (integration-summary (cadr manifest-summaries)))
    (check-equal? (yuanxu-user-module-selection-key selection)
                  '(flow . funflow))
    (check-equal? (yuanxu-cicd-check-map? pipeline) #t)
    (check-equal? (yuanxu-cicd-check-map-name pipeline) 'default)
    (check-equal? (length checks) 2)
    (check-equal? (yuanxu-cicd-check-name integration-check)
                  'integration)
    (check-equal? (yuanxu-cicd-check-profile integration-check)
                  '(ci/check agent/poo-object-extension))
    (check-equal? (yuanxu-cicd-check-dependency-refs integration-check)
                  '(build))
    (check-equal? (funflow-config-direct-alist-ref dependency-graph 'nodes)
                  '(build integration))
    (check-equal? (funflow-config-direct-alist-ref integration-edge 'from)
                  'build)
    (check-equal? (funflow-config-direct-alist-ref integration-edge 'to)
                  'integration)
    (check-equal? (funflow-config-direct-alist-ref
                   dependency-graph
                   'unresolved-dependency-refs)
                  '())
    (check-equal? (funflow-config-direct-alist-ref
                   integration-receipt
                   'runtime-executed)
                  #f)
    (check-equal? (funflow-config-direct-alist-ref
                   integration-receipt
                   'sandbox-unresolved-profile-refs)
                  '(agent/poo-object-extension))
    (check-equal? (funflow-config-direct-alist-ref manifest-map 'kind)
                  'agentic-ai-lab.workflow.cicd.runtime-command-manifest-map)
    (check-equal? (funflow-config-direct-alist-ref manifest-map
                                                  'runtime-executed)
                  #f)
    (check-equal? (length manifests) 2)
    (check-equal? (funflow-config-direct-alist-ref integration-manifest
                                                  'executable)
                  "gerbil")
    (check-equal? (funflow-config-direct-alist-ref integration-manifest
                                                  'arguments)
                  '("env" "./unit-tests.ss"))
    (check-equal? (funflow-config-direct-alist-ref integration-request
                                                  'check)
                  'integration)
    (check-equal? (funflow-config-direct-alist-ref integration-request
                                                  'dependency-refs)
                  '(build))
    (check-equal? (funflow-config-direct-alist-ref integration-summary
                                                  'status)
                  'blocked)
    (check-equal? (funflow-config-direct-alist-ref integration-summary
                                                  'handoff-ready)
                  #f)
    (check-equal? (funflow-config-direct-alist-ref
                   integration-summary
                   'sandbox-unresolved-profile-refs)
                  '(agent/poo-object-extension))
    'ok))

(def funflow-config-pipeline-direct-test
  (test-suite "agentic-ai-lab Funflow direct config pipeline"
    (yuanxu-test-case "lowers direct Funflow POO config to CI/CD runtime facts"
      (check-equal? (run-funflow-config-pipeline-direct-checks) 'ok))))
