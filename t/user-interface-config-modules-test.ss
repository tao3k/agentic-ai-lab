;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests custom user config profile modules.
;;; Invariant: user fragments remain declarative module selections.

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
        :poo-flow/modules/workflow/scenario/configuration/interface
        :core/module-system/selection/objects
        :poo-flow/modules/agent-sandbox/config
        (only-in "../user-interface/custom/my-module/profiles/session"
                 poo-flow-custom-my-module-session-module)
        (only-in "../user-interface/custom/my-module/profiles/task"
                 poo-flow-custom-my-module-task-module)
        (only-in "../user-interface/custom/my-module/profiles/cicd"
                 poo-flow-custom-my-module-cicd-module)
        (only-in "../user-interface/custom/my-module/profiles/object-extension"
                 poo-flow-custom-my-module-object-extension-module))

(export user-interface-config-modules-test)

;; : (-> PooUserModuleSelection [PooSandboxProfile])
(def (config-module-profiles module-selection)
  (cdr (poo-flow-user-module-selection-flag-entry module-selection ':config)))

;; : (-> [PooSandboxProfile] Symbol PooSandboxProfile)
(def (config-profile profiles name)
  (poo-flow-sandbox-profile-by-name profiles name))

;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;; : TestSuite
;;; This suite keeps module declarations in user config small while validation
;;; remains owned by upstream modules.
(def user-interface-config-modules-test
  (test-suite "poo-flow user interface config modules"
    (poo-flow-test-case "imports custom profile modules through their owner"
      (let* ((session-profiles
              (config-module-profiles
               (car poo-flow-custom-my-module-session-module)))
             (task-profiles
              (config-module-profiles
               (car poo-flow-custom-my-module-task-module)))
             (cicd-profiles
              (config-module-profiles
               (car poo-flow-custom-my-module-cicd-module)))
             (object-extension-profiles
              (config-module-profiles
               (car poo-flow-custom-my-module-object-extension-module)))
             (session-profile
              (config-profile session-profiles 'agent/session))
             (task-cache-profile
              (config-profile task-profiles 'agent/task-cache))
             (build-profile
              (config-profile cicd-profiles 'ci/build))
             (poo-object-profile
              (config-profile object-extension-profiles
                              'agent/poo-object-extension))
             (poo-object-resources
              (poo-flow-sandbox-profile-resource-policy poo-object-profile))
             (poo-object-mounts
              (test-ref poo-object-resources 'mounts)))
        (check-equal? (length session-profiles) 1)
        (check-equal? (length task-profiles) 2)
        (check-equal? (length cicd-profiles) 4)
        (check-equal? (length object-extension-profiles) 1)
        (check-equal? (poo-flow-sandbox-profile-capabilities
                       session-profile)
                      '(process-run filesystem-read tmpdir cache-mount))
        (check-equal? (poo-flow-sandbox-profile-resource-policy
                       task-cache-profile)
                      '((filesystem
                         (scope . project-workspace)
                         (paths
                         ((role . project-workspace)
                           (source . ".")
                           (project-marker . "gerbil.pkg")
                           (mode . read-only)))
                         (access . read-only))
                        (cpu . 2)
                        (memory . "2Gi")
                        (timeout-ms . 180000)))
        (check-equal? (poo-flow-sandbox-profile-network-policy
                       build-profile)
                      '(allowlisted "github.com" "crates.io"))
        (check-equal? (poo-flow-sandbox-profile-network-policy
                       poo-object-profile)
                      '(allowlisted "github.com" "crates.io"))
        (check-equal? (poo-flow-sandbox-profile-capabilities
                       poo-object-profile)
                      '(process-run filesystem-read tmpdir cache-mount
                        artifact-cache))
        (check-equal? (poo-flow-sandbox-profile-resource-policy
                       poo-object-profile)
                      '((filesystem
                         (scope . project-workspace)
                         (paths
                         ((role . project-workspace)
                           (source . ".")
                           (project-marker . "gerbil.pkg")
                           (mode . read-write)))
                         (mounts . declared)
                         (access . read-write))
                        (mounts
                         ((path . "/workspace/project")
                          (role . project-workspace)
                          (source . ".")
                          (project-marker . "gerbil.pkg")
                          (target . "/workspace/project")
                          (mode . read-write)
                          (purpose . project-source))
                         ((path . "/workspace/project/.data")
                          (source . ".data")
                          (target . "/workspace/project/.data")
                          (mode . read)
                          (purpose . research-checkouts))
                         ((path . "/workspace/cache")
                          (source . ".cache/agent-semantic-protocol")
                          (target . "/workspace/cache")
                          (mode . read-write)
                          (purpose . semantic-cache))
                         ((path . "/workspace/config")
                          (source . "user-interface/custom/my-module")
                          (target . "/workspace/config")
                          (mode . read)
                          (purpose . user-config))
                         ((path . "/run/secrets")
                          (source-kind . env)
                          (source . "$POO_FLOW_AGENT_SECRETS")
                          (target . "/run/secrets")
                          (mode . read)
                          (purpose . credentials)))
                        (cpu . 2)
                        (memory . "4Gi")
                        (timeout-ms . 300000)))
        (check-equal? (length poo-object-mounts) 5)
        (check-equal? (map (lambda (mount)
                             (test-ref mount 'mode))
                           poo-object-mounts)
                      '(read-write read read-write read read))
        (check-equal? (map (lambda (mount)
                             (test-ref mount 'purpose))
                           poo-object-mounts)
                      '(project-source
                        research-checkouts
                        semantic-cache
                        user-config
                        credentials))
        (check-equal? (poo-flow-sandbox-profile-metadata poo-object-profile)
                      '((declared-by . poo-flow-poo-prototype)
                        (runtime-executed . #f)
                        (backend . nono-sandbox)
                        (intent . poo-object-extension)
                        (scope . demo)
                        (poo-object . objects.nono-sandbox.profile)
                        (slot-operators . (override append remove))
                        (authoring-style . native-gerbil-poo)))))))
