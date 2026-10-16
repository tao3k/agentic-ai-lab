;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox cases prove declarations stay data-only before realization.
;;; Backend descriptors are inspected as upstream module facts, not executed here.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-not-equal?
                 check-output
        test-suite)
        (only-in :clan/poo/object .ref)
        "user-interface-fixtures.ss"
        :poo-flow/modules/workflow/scenario/configuration/interface
        :poo-flow/modules/workflow/scenario/configuration/profile-config
        :poo-flow/modules/agent-sandbox/config
        :poo-flow/modules/sandbox-core/backend-capability-catalog
        (only-in :poo-flow/modules/sandbox-core/profile-support/policy
                 poo-flow-sandbox-backend-capability/backend-kind))

(def (check-error thunk)
  (check-equal?
   (with-catch
    (lambda (_error) #t)
    (lambda () (thunk) #f))
   #t))

(export user-interface-config-sandbox-case-test)

;; : (-> [PooUserModuleSelection] Pair MaybePooUserModuleSelection)
(def (module-selection-by-key modules key)
  (cond
   ((null? modules) #f)
   ((equal? (poo-flow-user-module-selection-key (car modules)) key)
    (car modules))
   (else
    (module-selection-by-key (cdr modules) key))))

;; : (-> Unit TestSuite)
;;; This suite protects sandbox configuration cases as declarative user-facing
;;; data rather than backend implementation code.
(def user-interface-config-sandbox-case-test
  (test-suite "poo-flow user interface sandbox config"
    (poo-flow-test-case "loads upstream agent sandbox profile defaults"
      (let* ((presentation
              (poo-flow-default-sandbox-profile-presentation))
             (nono-profile
              (poo-flow-sandbox-profile-by-name
               poo-flow-default-sandbox-profiles
               'agent/nono))
             (cube-profile
              (poo-flow-sandbox-profile-by-name
               poo-flow-default-sandbox-profiles
               'agent/cube))
             (docker-profile
              (poo-flow-sandbox-profile-by-name
               poo-flow-default-sandbox-profiles
               'agent/docker)))
        (check-equal? poo-flow-default-sandbox-profile-names
                      '(agent/nono agent/cube agent/docker))
        (check-equal? (.ref presentation 'profile-count) 3)
        (check-equal? (poo-flow-sandbox-profile-backend-kind nono-profile)
                      'nono)
        (check-equal? (poo-flow-sandbox-profile-resource-policy nono-profile)
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
        (check-equal? (poo-flow-sandbox-profile-backend-ref cube-profile)
                      'cube-local)
        (check-equal? (poo-flow-sandbox-profile-network-policy cube-profile)
                      '(allowlisted "github.com" "crates.io"))
        (check-equal? (poo-flow-sandbox-profile-backend-kind docker-profile)
                      'docker)
        (check-equal?
         (poo-flow-sandbox-profile-recipe-portable? nono-profile)
         #t)
        (check-equal? (.ref presentation 'descriptor-realized?) #f)
        (check-equal? (.ref presentation 'runtime-executed) #f)))
(poo-flow-test-case "rejects absolute paths in public sandbox recipes"
  (let (profile
        (poo-flow-sandbox-profile
         (absolute-path-recipe
              (backend nono)
              (network deny-by-default)
              (capabilities filesystem-read)
              (resources
               (filesystem
                (scope . project-workspace)
                (paths
                 ((role . project-workspace)
                  (source . ".")
                  (project-marker . "gerbil.pkg")
                  (target . "/workspace/project")
                  (mode . read-only)))))
              (metadata (intent . portability-regression)))))
    (check-equal?
     (poo-flow-sandbox-profile-recipe-portable? profile)
     #f)
    (check-error
     (lambda () (poo-flow-sandbox-profile->descriptor profile)))))

(poo-flow-test-case "rejects relative runtime targets in public sandbox recipes"
  (let (profile
        (poo-flow-sandbox-profile
         (relative-target-recipe
          (backend nono)
          (network deny-by-default)
          (capabilities filesystem-read)
          (resources
           (filesystem
            (scope . project-workspace)
            (paths
             ((role . project-workspace)
              (source . ".")
              (project-marker . "gerbil.pkg")
              (target . "runtime-owned")
              (mode . read-only)))))
          (metadata (intent . portability-regression)))))
    (check-equal?
     (poo-flow-sandbox-profile-recipe-portable? profile)
     #f)
    (check-error
     (lambda () (poo-flow-sandbox-profile->descriptor profile)))))

(poo-flow-test-case "rejects traversal sources outside the logical resource root"
  (let (profile
        (poo-flow-sandbox-profile
         (traversal-source-recipe
          (backend nono)
          (network deny-by-default)
          (capabilities filesystem-read)
          (resources
           (filesystem
            (scope . project-workspace)
            (paths
             ((role . project-workspace)
              (source . "../outside")
              (project-marker . "gerbil.pkg")
              (mode . read-only)))))
          (metadata (intent . portability-regression)))))
    (check-equal?
     (poo-flow-sandbox-profile-recipe-portable? profile)
     #f)
    (check-error
     (lambda () (poo-flow-sandbox-profile->descriptor profile)))))

(poo-flow-test-case "rejects alternate absolute source syntaxes"
  (let ((windows-drive-profile
         (poo-flow-sandbox-profile
          (windows-drive-source-recipe
           (backend nono)
           (network deny-by-default)
           (capabilities filesystem-read)
           (resources
            (filesystem
             (scope . project-workspace)
             (paths
              ((role . project-workspace)
               (source . "C:\\outside")
               (project-marker . "gerbil.pkg")
               (mode . read-only)))))
           (metadata (intent . portability-regression)))))
        (windows-unc-profile
         (poo-flow-sandbox-profile
          (windows-unc-source-recipe
           (backend nono)
           (network deny-by-default)
           (capabilities filesystem-read)
           (resources
            (filesystem
             (scope . project-workspace)
             (paths
              ((role . project-workspace)
               (source . "\\\\server\\share")
               (project-marker . "gerbil.pkg")
               (mode . read-only)))))
           (metadata (intent . portability-regression)))))
        (file-uri-profile
         (poo-flow-sandbox-profile
          (file-uri-source-recipe
           (backend nono)
           (network deny-by-default)
           (capabilities filesystem-read)
           (resources
            (filesystem
             (scope . project-workspace)
             (paths
              ((role . project-workspace)
               (source . "file:///outside")
               (project-marker . "gerbil.pkg")
               (mode . read-only)))))
           (metadata (intent . portability-regression))))))
    (check-equal?
     (poo-flow-sandbox-profile-recipe-portable? windows-drive-profile)
     #f)
    (check-equal?
     (poo-flow-sandbox-profile-recipe-portable? windows-unc-profile)
     #f)
    (check-equal?
     (poo-flow-sandbox-profile-recipe-portable? file-uri-profile)
     #f)))

(poo-flow-test-case "accepts canonical relative sources under a logical resource root"
  (let (profile
        (poo-flow-sandbox-profile
         canonical-relative-source-recipe
         (backend nono)
         (network deny-by-default)
         (capabilities filesystem-read)
         (resources
          (filesystem
           (scope . project-workspace)
           (paths
            ((role . project-workspace)
             (source . "src/module")
             (project-marker . "gerbil.pkg")
             (mode . read-only)))))
         (metadata (intent . portability-regression))))
    (check-equal?
     (poo-flow-sandbox-profile-recipe-portable? profile)
     #t)))
    (poo-flow-test-case "declares sandbox and loop module flags without descriptors"
      (let* ((modules
              (poo-flow-user-config-modules test-poo-flow-user-config))
             (loop-module
              (module-selection-by-key modules '(flow . loop-engine)))
             (nono-module
              (module-selection-by-key modules '(sandbox . nono-sandbox)))
             (cube-module
              (module-selection-by-key modules '(sandbox . cubeSandbox)))
             (docker-module
              (module-selection-by-key modules '(sandbox . docker-sandbox))))
        (check-equal? (poo-flow-user-module-selection? loop-module) #t)
        (check-equal? (poo-flow-user-module-selection-has-flags?
                       loop-module
                       '(+loop-engine +runtime-manifest))
                      #t)
        (check-equal? (poo-flow-user-module-selection-has-flag?
                       nono-module
                       '+nono)
                      #t)
        (check-equal? (poo-flow-user-module-selection-has-flag?
                       cube-module
                       '+cube)
                      #t)
        (check-equal? (poo-flow-user-module-selection-has-flag?
                       docker-module
                       '+docker)
                      #t)))
    (poo-flow-test-case "backend modules contribute capabilities without core branches"
      (let* ((modules
              (poo-flow-user-config-modules test-poo-flow-user-config))
             (nono
              (poo-flow-user-config-sandbox-backend-capability modules 'nono))
             (cube
              (poo-flow-user-config-sandbox-backend-capability modules 'cube))
             (docker
              (poo-flow-user-config-sandbox-backend-capability modules 'docker)))
        (check-eq? (poo-flow-sandbox-backend-capability/backend-kind nono)
                   'nono)
        (check-eq? (poo-flow-sandbox-backend-capability/backend-kind cube)
                   'cube)
        (check-eq? (poo-flow-sandbox-backend-capability/backend-kind docker)
                   'docker)
        (check-equal?
         (let ((selection
                (module-selection-by-key modules '(sandbox . nono-sandbox))))
           (poo-flow-user-module-selection-has-flag?
            selection ':backend-capability-registry))
         #t)))
    (poo-flow-test-case "queries selected module features without package management"
      (let* ((custom-config
              (pooFlowUserConfigFromProfile test-poo-flow-user-custom-profile)))
        (check-equal? (poo-flow-user-config-feature?
                       test-poo-flow-user-config
                       'flow
                       'funflow
                       '+functional
                       '+dag
                       '+typed-receipts
                       '+runtime-manifest)
                      #t)
        (check-equal? (poo-flow-user-config-feature?
                       test-poo-flow-user-config
                       'flow
                       'funflow
                       '+cicd)
                      #t)
        (check-equal? (poo-flow-user-config-feature?
                       test-poo-flow-user-config
                       'flow
                       'loop-engine
                       '+loop-engine
                       '+runtime-manifest)
                      #t)
        (check-equal? (poo-flow-user-config-feature?
                       test-poo-flow-user-config
                       'loop
                       'governor
                       '+missing)
                      #f)
        (check-equal? (poo-flow-user-config-feature?
                       test-poo-flow-user-config
                       'sandbox
                       'nono-sandbox
                       '+nono
                       '+doctor)
                      #t)
        (check-equal? (poo-flow-user-config-feature?
                       test-poo-flow-user-config
                       'sandbox
                       'cubeSandbox
                       '+cube
                       '+doctor)
                      #t)
        (check-equal? (poo-flow-user-config-feature?
                       test-poo-flow-user-config
                       'sandbox
                       'docker-sandbox
                       '+docker
                       '+doctor)
                      #t)
        (check-equal? (poo-flow-user-config-feature?
                       custom-config
                       'custom
                       'my-module
                       '+doctor)
                      #t)))
    (poo-flow-test-case "keeps flow loop and sandbox settings declarative"
      (let ((settings (poo-flow-user-config-settings test-poo-flow-user-config)))
        (check-equal? (.ref settings 'surface) "poo-flow")
        (check-equal? (.ref settings 'flow-mode) 'funflow)
        (check-equal? (.ref settings 'loop-strategy) 'governed)
        (check-equal? (.ref settings 'sandbox-policy) 'module-gated)
        (check-equal? (.ref settings 'sandbox-backends)
                      '(nono cube docker))))))
