;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream-shaped Funflow POO config lowers to readiness facts.

(import (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy agentic-ai-lab-product-use-module)
        (only-in :yuanxu/modules/funflow/config-adapter yuanxu-funflow-poo-pipeline->check-map)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/modules/funflow/config-prototypes funflow-check funflow-pipeline)
         (only-in :std/test check-equal? test-suite)
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/entrypoints
        :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
        :agentic-ai-lab/modules/workflow/funflow-config
        :agentic-ai-lab/modules/agent-sandbox/config
        (only-in :yuanxu/modules/funflow/check-objects yuanxu-cicd-check-map-name)
        (only-in :agentic-ai-lab/modules/workflow/cicd-runtime agentic-ai-lab-cicd-check-map->runtime-manifest-readiness))

(export funflow-config-pipeline-downstream-test)

'agentic-ai-lab-import-side-effect-test-suite?

;; : (-> List Symbol Object)
(def (funflow-config-downstream-alist-ref alist key)
  (match alist
    ([[(? symbol? row-key) . row-value] . rest]
     (if (eq? row-key key)
       row-value
       (funflow-config-downstream-alist-ref rest key)))
    ([_ . rest]
     (funflow-config-downstream-alist-ref rest key))
    (else #f)))

;; : (-> Unit [PooUserModuleSelection])
(def (funflow-config-downstream-selection)
  (let ()
    (.def (funflow-downstream/build @ funflow-check)
      check-name: 'build
      profile-ref: 'ci/build
      command-vector: '("gerbil" "build")
      artifact-outputs: '(build-log)
      cache-intents: '(gerbil-build-cache)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff)
    (.def (funflow-downstream/test @ funflow-check)
      check-name: 'test
      profile-ref: 'ci/check
      command-vector: '("gerbil" "env" "./unit-tests.ss")
      artifact-outputs: '(test-receipt)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff
      dependency-refs: '(build))
    (.def (funflow-downstream/package @ funflow-check)
      check-name: 'package
      profile-ref: 'ci/check
      command-vector: '("gerbil" "env" "./unit-tests.ss")
      artifact-outputs: '(dependency-graph-receipt)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff
      dependency-refs: '(test))
    (.def (funflow-downstream/default @ funflow-pipeline)
      pipeline-name: 'default
      checks: (list funflow-downstream/build
                    funflow-downstream/test
                    funflow-downstream/package)
      metadata: '((scenario . funflow-cicd)
                  (authoring-style . gerbil-poo)))
    (agentic-ai-lab-product-use-module 'funflow
      (agentic-ai-lab-funflow-config-flags
        (yuanxu-funflow-poo-pipeline->check-map funflow-downstream/default)
        (list ':config funflow-downstream/default)))))

;; : (-> Unit [PooSandboxProfile])
(def (funflow-config-downstream-sandbox-profiles)
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
(def (run-funflow-config-pipeline-downstream-checks)
  (let* ((selection (car (funflow-config-downstream-selection)))
         (pipeline
          (funflow-config-downstream-alist-ref
           (yuanxu-user-module-selection-flags selection)
           ':workflow-pipeline))
         (readiness
          (agentic-ai-lab-cicd-check-map->runtime-manifest-readiness
           pipeline
           (funflow-config-downstream-sandbox-profiles)))
         (dependency-graph
          (funflow-config-downstream-alist-ref readiness 'dependency-graph))
         (entries (funflow-config-downstream-alist-ref readiness 'checks))
         (build-entry (car entries))
         (test-entry (cadr entries))
         (package-entry (caddr entries))
         (build-summaries
          (funflow-config-downstream-alist-ref
           build-entry
           'sandbox-runtime-summaries))
         (build-summary (car build-summaries))
         (build-filesystem
          (funflow-config-downstream-alist-ref build-summary 'filesystem)))
    (check-equal? (yuanxu-user-module-selection-key selection)
                  '(flow . funflow))
    (check-equal? (yuanxu-cicd-check-map-name pipeline) 'default)
    (check-equal? (length entries) 3)
    (check-equal? (funflow-config-downstream-alist-ref dependency-graph
                                                      'nodes)
                  '(build test package))
    (check-equal? (funflow-config-downstream-alist-ref dependency-graph
                                                      'order-policy)
                  'declaration-topological-report)
    (check-equal? (funflow-config-downstream-alist-ref dependency-graph
                                                      'ready-order)
                  '(build test package))
    (check-equal? (funflow-config-downstream-alist-ref dependency-graph
                                                      'unordered-nodes)
                  '())
    (check-equal? (funflow-config-downstream-alist-ref dependency-graph
                                                      'blocked-order?)
                  #f)
    (check-equal? (funflow-config-downstream-alist-ref dependency-graph
                                                      'valid?)
                  #t)
    (check-equal? (funflow-config-downstream-alist-ref test-entry
                                                      'dependency-refs)
                  '(build))
    (check-equal? (funflow-config-downstream-alist-ref package-entry
                                                      'dependency-refs)
                  '(test))
    (check-equal? (funflow-config-downstream-alist-ref build-entry
                                                      'sandbox-unresolved-profile-refs)
                  '())
    (check-equal? (funflow-config-downstream-alist-ref build-summary
                                                      'profile-name)
                  'ci/build)
    (check-equal? (funflow-config-downstream-alist-ref build-filesystem
                                                      'path-count)
                  1)
    (check-equal? (funflow-config-downstream-alist-ref readiness
                                                      'runtime-executed)
                  #f)
    'ok))

(def funflow-config-pipeline-downstream-test
  (test-suite "agentic-ai-lab Funflow downstream config pipeline"
    (yuanxu-test-case "lowers downstream Funflow POO config to readiness facts"
      (check-equal? (run-funflow-config-pipeline-downstream-checks) 'ok))))
