;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream-shaped Funflow POO config lowers to readiness facts.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test check-equal? test-suite)
        :core/module-system/selection/objects
        :poo-flow/modules/workflow/scenario/configuration/interface
        :poo-flow/modules/workflow/scenario/configuration/init-syntax
        :poo-flow/modules/agent-sandbox/config
        :poo-flow/modules/workflow/interface)

(export funflow-config-pipeline-downstream-test)

'poo-flow-import-side-effect-test-suite?

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
  (use-module funflow
    :config
    (.def (funflow-downstream/build @ funflow-check
                                    check-name profile-ref command-vector
                                    artifact-outputs cache-intents
                                    result-protocol runtime-mode)
      check-name: 'build
      profile-ref: 'ci/build
      command-vector: '("gerbil" "build")
      artifact-outputs: '(build-log)
      cache-intents: '(gerbil-build-cache)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff)

    (.def (funflow-downstream/test @ funflow-check
                                   check-name profile-ref command-vector
                                   artifact-outputs result-protocol
                                   runtime-mode dependency-refs)
      check-name: 'test
      profile-ref: 'ci/check
      command-vector: '("gerbil" "env" "./unit-tests.ss")
      artifact-outputs: '(test-receipt)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff
      dependency-refs: '(build))

    (.def (funflow-downstream/package @ funflow-check
                                      check-name profile-ref command-vector
                                      artifact-outputs result-protocol
                                      runtime-mode dependency-refs)
      check-name: 'package
      profile-ref: 'ci/check
      command-vector: '("gerbil" "env" "./unit-tests.ss")
      artifact-outputs: '(dependency-graph-receipt)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff
      dependency-refs: '(test))

    (.def (funflow-downstream/default @ funflow-pipeline
                                      pipeline-name checks metadata)
      pipeline-name: 'default
      checks: (list funflow-downstream/build
                    funflow-downstream/test
                    funflow-downstream/package)
      metadata: '((scenario . funflow-cicd)
                  (authoring-style . gerbil-poo-native)))))

;; : (-> Unit [PooSandboxProfile])
(def (funflow-config-downstream-sandbox-profiles)
  (poo-flow-sandbox-profiles
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
           (poo-flow-user-module-selection-flags selection)
           ':workflow-pipeline))
         (readiness
          (poo-flow-cicd-check-map->runtime-manifest-readiness
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
    (check-equal? (poo-flow-user-module-selection-key selection)
                  '(flow . funflow))
    (check-equal? (poo-flow-cicd-check-map-name pipeline) 'default)
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
  (test-suite "poo-flow Funflow downstream config pipeline"
    (poo-flow-test-case "lowers downstream Funflow POO config to readiness facts"
      (check-equal? (run-funflow-config-pipeline-downstream-checks) 'ok))))
