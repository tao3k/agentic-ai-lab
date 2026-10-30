;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CI/CD downstream sandbox profile cases live here.
;;; Invariant: cases stay declarative and do not execute release workflows.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
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
        :yuanxu/modules/funflow/control-plane/api
        (only-in "../user-interface/custom/my-module/profiles/cicd"
                 agentic-ai-lab-custom-my-module-cicd-module)
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :agentic-ai-lab/modules/workflow/scenario/configuration/init-syntax
        :agentic-ai-lab/modules/agent-sandbox/config)

(export user-interface-cicd-profile-case-test)

;; : TestSuite
;;; This suite protects the CI/CD profile case as an executable downstream
;;; configuration story.
(def user-interface-cicd-profile-case-test
  (test-suite "agentic-ai-lab user interface CI/CD sandbox profiles"
    (yuanxu-test-case "loads CI/CD sandbox profiles from root user-interface config"
      (let* ((nono-config
              (car agentic-ai-lab-custom-my-module-cicd-module))
             (profiles
              (cdr (yuanxu-user-module-selection-flag-entry
                    nono-config
                    ':config)))
             (binding
              (cdr (yuanxu-user-module-selection-flag-entry
                    nono-config
                    ':binding)))
             (check-profile
              (agentic-ai-lab-sandbox-profile-by-name profiles 'ci/check))
             (build-profile
              (agentic-ai-lab-sandbox-profile-by-name profiles 'ci/build))
             (release-profile
              (agentic-ai-lab-sandbox-profile-by-name profiles 'cd/release))
             (promote-profile
              (agentic-ai-lab-sandbox-profile-by-name profiles
                                                'cicd/artifact-promote)))
        (check-equal? binding 'native-ffi)
        (check-equal? (length profiles) 4)
        (check-equal? (agentic-ai-lab-sandbox-profile-network-policy check-profile)
                      '(deny-by-default))
        (check-equal? (agentic-ai-lab-sandbox-profile-capabilities build-profile)
                      '(process-run filesystem-read filesystem-write tmpdir
                        cache-mount))
        (check-equal? (agentic-ai-lab-sandbox-profile-resource-policy check-profile)
                      '((filesystem
                         (scope . project-workspace)
                         (paths
                         ((role . project-workspace)
                           (source . ".")
                           (project-marker . "gerbil.pkg")
                           (mode . read-only)))
                         (access . read-only))
                        (cpu . 1)
                        (memory . "1Gi")
                        (timeout-ms . 90000)))
        (check-equal? (agentic-ai-lab-sandbox-profile-network-policy release-profile)
                      '(allowlisted "github.com" "ghcr.io"))
        (check-equal? (agentic-ai-lab-sandbox-profile-metadata promote-profile)
                      '((declared-by . agentic-ai-lab-poo-prototype)
                        (runtime-executed . #f)
                        (backend . nono-sandbox)
                        (intent . ci-check)
                        (scope . cicd)
                        (stage . check)
                        (intent . ci-build)
                        (scope . cicd)
                        (stage . build)
                        (artifacts . export)
                        (intent . artifact-promote)
                        (scope . cicd)
                        (stage . promote)
                        (artifacts . consume)))))
    (yuanxu-test-case "defaults nono use-module config to native FFI binding"
      (let* ((check-capabilities '(process-run filesystem-read tmpdir))
             (check-metadata '((intent . ci-check)))
             (nono-config
              (car (use-module nono-sandbox
                     (.def (ci/check @ nono-sandbox-profile)
                       network: (deny-network)
                       capabilities: check-capabilities
                       resources: =>.+ readonly-project-workspace-resources
                       metadata: => (lambda (super-metadata)
                                      (append super-metadata
                                              check-metadata))))))
             (binding
              (cdr (yuanxu-user-module-selection-flag-entry
                    nono-config
                    ':binding))))
        (check-equal? binding 'native-ffi)))
    (yuanxu-test-case "rejects CI/CD resources without filesystem sandbox"
      (let* ((broken-capabilities '(process-run filesystem-read tmpdir))
             (broken-metadata '((intent . ci-check)
                                (scope . cicd)))
             (broken-resources (.o cpu: 1
                                   memory: "1Gi"))
             (failure
              (with-catch (lambda (failure) failure)
                          (lambda ()
                            (let* ((broken-config
                                    (car (use-module nono-sandbox
                                           (.def (ci/broken
                                                  @
                                                  nono-sandbox-profile)
                                             network: (deny-network)
                                             capabilities: broken-capabilities
                                             resources: broken-resources
                                             metadata: => (lambda
                                                           (super-metadata)
                                                           (append
                                                            super-metadata
                                                            broken-metadata))))))
                                   (profiles
                                    (cdr
                                     (yuanxu-user-module-selection-flag-entry
                                      broken-config
                                      ':config)))
                                   (broken-profile
                                    (agentic-ai-lab-sandbox-profile-by-name
                                     profiles
                                     'ci/broken)))
                              (agentic-ai-lab-sandbox-profile-resource-policy
                               broken-profile))))))
        (check-equal? (error-object? failure) #t)
        (check-equal? (execution-failure? failure) #f)))))
