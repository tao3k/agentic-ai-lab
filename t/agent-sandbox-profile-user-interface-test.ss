;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile user interface stays on the module-system facade.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
        test-suite)
        (only-in :clan/poo/object .o .ref .slot? object?)
        :core/module-system/selection/objects
        :poo-flow/modules/workflow/scenario/configuration/interface
        :poo-flow/modules/workflow/scenario/configuration/init-syntax
        :poo-flow/modules/agent-sandbox/config)

(export agent-sandbox-profile-user-interface-test)

;;; These profiles model the downstream DSL surface that users edit, while
;;; upstream modules remain responsible for validation and backend defaults.
;; : [PooSandboxProfile]
(def user-sandbox-profiles
  (poo-flow-sandbox-profiles
   (agent/nono
    (backend nono)
    (network deny-by-default)
    (capabilities process-run filesystem-read filesystem-write tmpdir)
    (resources (filesystem
                (scope . project-workspace)
                (paths
                 ((role . project-workspace)
                  (source . ".")
                  (project-marker . "gerbil.pkg")
                  (mode . read-write)))
                (access . read-write))
               (cpu . 2)
               (memory . "4Gi")
               (timeout-ms . 300000))
    (metadata (intent . coding-agent) (risk . high-demand)))
   (agent/cube
    (backend cubeSandbox cube-local)
    (network allowlisted "github.com" "crates.io")
    (capabilities process-run filesystem-read cache-mount)
    (resources (filesystem
                (scope . snapshot)
                (snapshot . clone)
                (access . read-only))
               (cpu . 4)
               (memory . "8Gi")
               (timeout-ms . 600000))
    (metadata (intent . ci-agent) (risk . hermetic)))))

;;; The nono profile case exercises POO slot override and inherited-slot
;;; transforms without exposing backend implementation objects.
;; : Capabilities
(def user-nono-operator-cache-capabilities
  '(cache-mount))

;; : Metadata
(def user-nono-operator-metadata
  '((intent . operator-demo)
    (stage . extension)))

;; : PooUserModuleSelection
(def user-nono-operator-module
  (car
   (use-module nono-sandbox
     (.def (agent/operator @ nono-sandbox-profile
                           network capabilities resources metadata)
       network: (allowlisted-network "github.com" "crates.io")
       capabilities: => (lambda (super-capabilities)
                          (append super-capabilities
                                  user-nono-operator-cache-capabilities))
       resources: =>.+ readwrite-project-workspace-resources
       metadata: => (lambda (super-metadata)
                      (append super-metadata
                              user-nono-operator-metadata))))))

;;; The cube case keeps CI-style sandbox extension visible in the user-facing
;;; module syntax.
;; : PooSandboxFilesystemPrototype
(def user-cube-snapshot-filesystem
  (.o scope: 'snapshot
      snapshot: 'clone))

;; : PooSandboxResourcesPrototype
(def user-cube-build-resources
  (.o filesystem: user-cube-snapshot-filesystem
      cpu: 4
      memory: "8Gi"
      timeout-ms: 600000))

;; : Metadata
(def user-cube-base-metadata
  '((intent . cube-base)
    (scope . profile)))

;; : Metadata
(def user-cube-build-metadata
  '((intent . cube-build)
    (stage . build)))

;; : PooUserModuleSelection
(def user-cube-build-module
  (car
   (use-module cubeSandbox
     (.def (ci/cube-base @ cubeSandbox-profile
                         network resources metadata)
       network: (allowlisted-network "github.com" "crates.io")
       resources: user-cube-build-resources
       metadata: => (lambda (super-metadata)
                      (append super-metadata
                              user-cube-base-metadata)))

     (.def (ci/cube @ ci/cube-base
                    metadata)
       (metadata (super-metadata)
         (profile-derivation-metadata
          (super-metadata)
          'ci/cube
          'ci/cube-base
          'session
          "cube-build"
          user-cube-build-metadata))))))

;;; The docker case verifies a second backend can use the same declarative
;;; profile surface with different capability policy.
;; : PooSandboxFilesystemPrototype
(def user-docker-volume-filesystem
  (.o scope: 'volume
      materialized-by: 'runtime
      mounts: 'runtime))

;; : PooSandboxResourcesPrototype
(def user-docker-volume-resources
  (.o filesystem: user-docker-volume-filesystem
      cpu: 2
      memory: "4Gi"))

;; : Metadata
(def user-docker-base-metadata
  '((intent . docker-base)
    (scope . profile)))

;; : Metadata
(def user-docker-build-metadata
  '((intent . docker-build)
    (stage . build)))

;; : PooUserModuleSelection
(def user-docker-build-module
  (car
   (use-module docker-sandbox
     (.def (ci/docker-base @ docker-sandbox-profile
                           network capabilities resources metadata)
       network: (allowlisted-network "ghcr.io")
       capabilities: '(process-run filesystem-read filesystem-write tmpdir)
       resources: =>.+ readwrite-project-workspace-resources
       metadata: => (lambda (super-metadata)
                      (append super-metadata
                              user-docker-base-metadata)))

     (.def (ci/docker @ ci/docker-base
                      capabilities resources metadata)
       capabilities: '(process-run filesystem-read tmpdir)
       resources: user-docker-volume-resources
       (metadata (super-metadata)
         (profile-derivation-metadata
          (super-metadata)
          'ci/docker
          'ci/docker-base
          'branch
          "docker-build"
          user-docker-build-metadata))))))

;;; Local alist lookup keeps assertions readable while avoiding a dependency on
;;; internal profile projection helpers.
;; : (-> Symbol (Or Alist Object) Object)
(def (alist-value key entries)
  (cond
   ((object? entries)
    (and (.slot? entries key)
         (.ref entries key)))
   (else
    (let (entry (assoc key entries))
      (if entry (cdr entry) #f)))))

;;; Inheritance metadata is append-only in these cases; the last derivation row
;;; is the concrete child profile step asserted by the profile tests.
;; : (-> [Object] Object)
(def (last-value values)
  (car (reverse values)))

;;; This suite exercises the downstream-facing profile syntax without exposing
;;; backend implementation slots as part of the user contract.
;; : TestSuite
(def agent-sandbox-profile-user-interface-test
  (test-suite "poo-flow agent sandbox profile user interface"
    (poo-flow-test-case "declares nono and cubeSandbox profiles as inert user data"
      (let* ((nono-profile
              (poo-flow-sandbox-profile-by-name user-sandbox-profiles
                                                'agent/nono))
             (cube-profile
              (poo-flow-sandbox-profile-by-name user-sandbox-profiles
                                                'agent/cube)))
        (check-equal? (length user-sandbox-profiles) 2)
        (check-equal? (poo-flow-sandbox-profile? nono-profile) #t)
        (check-equal? (poo-flow-sandbox-profile-name nono-profile) 'agent/nono)
        (check-equal? (poo-flow-sandbox-profile-backend-kind nono-profile)
                      'nono)
        (check-equal? (poo-flow-sandbox-profile-backend-ref cube-profile)
                      'cube-local)
        (check-equal? (poo-flow-sandbox-profile-network-policy cube-profile)
                      '(allowlisted "github.com" "crates.io"))))
    (poo-flow-test-case "applies POO slot transforms through nono object validation"
      (let* ((profile-payload
              (poo-flow-user-module-selection-flag-entry
               user-nono-operator-module
               ':config))
             (profiles (cdr profile-payload))
             (operator-profile
              (poo-flow-sandbox-profile-by-name profiles 'agent/operator)))
        (check-equal? (poo-flow-user-module-selection-key
                       user-nono-operator-module)
                      '(sandbox . nono-sandbox))
        (check-equal? (length profiles) 1)
        (check-equal? (poo-flow-sandbox-profile-name operator-profile)
                      'agent/operator)
        (check-equal? (poo-flow-sandbox-profile-backend-kind operator-profile)
                      'nono)
        (check-equal? (poo-flow-sandbox-profile-backend-ref operator-profile)
                      'agent/operator)
        (check-equal? (poo-flow-sandbox-profile-network-policy
                       operator-profile)
                      '(allowlisted "github.com" "crates.io"))
        (check-equal? (poo-flow-sandbox-profile-capabilities
                       operator-profile)
                      '(process-run filesystem-read tmpdir cache-mount))
        (check-equal? (poo-flow-sandbox-profile-resource-policy
                       operator-profile)
                      '((filesystem
                         (scope . project-workspace)
                         (paths
                          ((role . project-workspace)
                           (source . ".")
                           (project-marker . "gerbil.pkg")
                           (mode . read-write)))
                         (access . read-write))
                        (cpu . 2)
                        (memory . "4Gi")
                        (timeout-ms . 300000)))
        (check-equal? (poo-flow-sandbox-profile-metadata operator-profile)
                      '((declared-by . poo-flow-poo-prototype)
                        (runtime-executed . #f)
                        (backend . nono-sandbox)
                        (intent . operator-demo)
                        (stage . extension)))))
    (poo-flow-test-case "applies profile inheritance for cube and docker sandbox objects"
      (let* ((cube-profiles
              (cdr (poo-flow-user-module-selection-flag-entry
                    user-cube-build-module
                    ':config)))
             (docker-profiles
              (cdr (poo-flow-user-module-selection-flag-entry
                    user-docker-build-module
                    ':config)))
             (cube-profile
              (poo-flow-sandbox-profile-by-name cube-profiles 'ci/cube))
             (docker-profile
              (poo-flow-sandbox-profile-by-name docker-profiles 'ci/docker))
             (cube-lineage
              (alist-value
               'derivation-path
               (poo-flow-sandbox-profile-metadata cube-profile)))
             (docker-lineage
              (alist-value
               'derivation-path
               (poo-flow-sandbox-profile-metadata docker-profile)))
             (cube-step (last-value cube-lineage))
             (docker-step (last-value docker-lineage)))
        (check-equal? (poo-flow-user-module-selection-key
                       user-cube-build-module)
                      '(sandbox . cubeSandbox))
        (check-equal? (poo-flow-user-module-selection-key
                       user-docker-build-module)
                      '(sandbox . docker-sandbox))
        (check-equal? (poo-flow-sandbox-profile-backend-kind cube-profile)
                      'cube)
        (check-equal? (poo-flow-sandbox-profile-resource-policy cube-profile)
                      '((filesystem
                         (scope . snapshot)
                         (snapshot . clone))
                        (cpu . 4)
                        (memory . "8Gi")
                        (timeout-ms . 600000)))
        (check-equal? (alist-value 'parent-profile cube-step)
                      'ci/cube-base)
        (check-equal? (alist-value 'scope cube-step) 'session)
        (check-equal? (alist-value 'scope-ref cube-step) "cube-build")
        (check-equal? (poo-flow-sandbox-profile-backend-kind docker-profile)
                      'docker)
        (check-equal? (poo-flow-sandbox-profile-capabilities docker-profile)
                      '(process-run filesystem-read tmpdir))
        (check-equal? (poo-flow-sandbox-profile-resource-policy docker-profile)
                      '((filesystem
                         (scope . volume)
                         (materialized-by . runtime)
                        (mounts . runtime))
                        (cpu . 2)
                        (memory . "4Gi")))
        (check-equal? (alist-value 'parent-profile docker-step)
                      'ci/docker-base)
        (check-equal? (alist-value 'scope docker-step) 'branch)
        (check-equal? (alist-value 'scope-ref docker-step) "docker-build")
        (check-equal? (alist-value
                       'backend-kind
                       (poo-flow-sandbox-profile->profile cube-profile))
                      'cube)
        (check-equal? (alist-value
                       'backend-kind
                       (poo-flow-sandbox-profile->profile docker-profile))
                      'docker)))
    (poo-flow-test-case "projects user declarations into validated agent sandbox profiles"
      (let* ((nono-profile
              (poo-flow-sandbox-profile-by-name user-sandbox-profiles
                                                'agent/nono))
             (profile
              (poo-flow-sandbox-profile->profile nono-profile)))
        (check-equal? (alist-value 'schema profile)
                      'poo-flow.agent-sandbox-profile.v1)
        (check-equal? (alist-value 'backend-kind profile) 'nono)
        (check-equal? (alist-value 'backend-ref profile) 'nono)
        (check-equal? (alist-value 'network-policy profile)
                      '(deny-by-default))
        (check-equal? (alist-value 'capabilities profile)
                      '(process-run filesystem-read filesystem-write tmpdir))
        (check-equal? (alist-value 'resource-policy profile)
                      '((filesystem
                         (scope . project-workspace)
                         (paths
                          ((role . project-workspace)
                           (source . ".")
                           (project-marker . "gerbil.pkg")
                           (mode . read-write)))
                         (access . read-write))
                        (cpu . 2)
                        (memory . "4Gi")
                        (timeout-ms . 300000)))))
    (poo-flow-test-case "presents profile collections as runtime handoff intent data"
      (let* ((presentation
              (pooFlowSandboxProfilesPresentation user-sandbox-profiles))
             (runtime-intents (.ref presentation 'runtime-intents))
             (runtime-summaries (.ref presentation 'runtime-summaries))
             (handoff-summaries (.ref presentation 'handoff-summaries))
             (policy-projections (.ref presentation 'policy-projections))
             (nono-intent (car runtime-intents))
             (cube-intent (cadr runtime-intents))
             (nono-summary (car runtime-summaries))
             (nono-filesystem (alist-value 'filesystem nono-summary))
             (cube-handoff (cadr handoff-summaries))
             (cube-handoff-summary
              (alist-value 'runtime-summary cube-handoff))
             (nono-policy (car policy-projections))
             (nono-policy-validation
              (alist-value 'validation nono-policy))
             (nono-intent-policy
              (alist-value 'policy-projection nono-intent))
             (nono-durable-summary
              (alist-value 'durable-policy-summary nono-intent))
             (nono-policy-durable-summary
              (alist-value 'durable-policy-summary nono-policy)))
        (check-equal? (.ref presentation 'kind)
                      poo-flow-sandbox-profiles-presentation-kind)
        (check-equal? (.ref presentation 'profile-count) 2)
        (check-equal? (.ref presentation 'profile-names)
                      '(agent/nono agent/cube))
        (check-equal? (length runtime-summaries) 2)
        (check-equal? (length handoff-summaries) 2)
        (check-equal? (length policy-projections) 2)
        (check-equal? (.ref presentation 'policy-valid?) #t)
        (check-equal? (.ref presentation 'policy-diagnostics) '())
        (check-equal? (alist-value 'backend-kind nono-intent) 'nono)
        (check-equal? (alist-value 'backend-ref cube-intent) 'cube-local)
        (check-equal? (alist-value 'policy-valid? nono-intent) #t)
        (check-equal? (alist-value 'kind nono-intent-policy)
                      "poo-flow.sandbox.profile-policy.projection.v1")
        (check-equal? (alist-value 'durable-policy-ref nono-intent)
                      'durable/default)
        (check-equal? (alist-value 'durable-valid? nono-intent) #t)
        (check-equal? (alist-value 'sandbox-handle-class nono-intent)
                      'sandbox/profile-handle)
        (check-equal? (alist-value 'journal-owner nono-durable-summary)
                      'runtime/fact-log)
        (check-equal? (alist-value 'checkpoint-store nono-durable-summary)
                      'runtime/checkpoint-store)
        (check-equal? (alist-value 'runtime-owner nono-intent)
                      "marlin-agent-core")
        (check-equal? (alist-value 'descriptor-realized? cube-intent) #f)
        (check-equal? (alist-value 'runtime-executed cube-intent) #f)
        (check-equal? (alist-value 'schema nono-summary)
                      'poo-flow.agent-sandbox-profile.runtime-summary.v1)
        (check-equal? (alist-value 'profile-name nono-summary) 'agent/nono)
        (check-equal? (alist-value 'descriptor-realized? nono-summary) #t)
        (check-equal? (alist-value 'valid? nono-summary) #t)
        (check-equal? (alist-value 'path-count nono-filesystem) 1)
        (check-equal? (alist-value 'scope nono-filesystem)
                      'project-workspace)
        (check-equal? (alist-value 'schema cube-handoff)
                      'poo-flow.agent-sandbox-profile.handoff-summary.v1)
        (check-equal? (alist-value 'handoff-contract cube-handoff)
                      'poo-flow.agent-sandbox-profile.runtime-handoff.v1)
        (check-equal? (alist-value 'schema cube-handoff-summary)
                      'poo-flow.agent-sandbox-profile.runtime-summary.v1)
        (check-equal? (alist-value 'kind nono-policy)
                      "poo-flow.sandbox.profile-policy.projection.v1")
        (check-equal? (alist-value 'valid? nono-policy) #t)
        (check-equal? (alist-value 'durable-policy-ref nono-policy)
                      'durable/default)
        (check-equal? (alist-value 'repair-mode nono-policy-durable-summary)
                      'fail-closed)
        (check-equal? (alist-value 'valid? nono-policy-validation) #t)
        (check-equal? (alist-value 'durable-valid? nono-policy-validation)
                      #t)
        (check-equal? (alist-value 'diagnostic-count nono-policy-validation)
                      0)
        (check-equal? (.ref presentation 'runtime-executed) #f)))))
