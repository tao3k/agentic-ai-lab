;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox cases prove declarations stay data-only before realization.
;;; Backend descriptors are inspected as upstream module facts, not executed here.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-not-equal?
                 check-output
        test-suite)
        (only-in :clan/poo/object .ref)
        "user-interface-fixtures.ss"
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :agentic-ai-lab/modules/workflow/scenario/configuration/profile-config
        :agentic-ai-lab/modules/agent-sandbox/config
        :agentic-ai-lab/modules/sandbox-core/backend-capability-catalog
        (only-in :agentic-ai-lab/modules/sandbox-core/profile-support/policy
                 agentic-ai-lab-sandbox-backend-capability/backend-kind))

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
   ((equal? (yuanxu-user-module-selection-key (car modules)) key)
    (car modules))
   (else
    (module-selection-by-key (cdr modules) key))))

;; : (-> Unit TestSuite)
;;; This suite protects sandbox configuration cases as declarative user-facing
;;; data rather than backend implementation code.
(def user-interface-config-sandbox-case-test
  (test-suite "agentic-ai-lab user interface sandbox config"
    (yuanxu-test-case "loads upstream agent sandbox profile defaults"
      (let* ((presentation
              (agentic-ai-lab-default-sandbox-profile-presentation))
             (nono-profile
              (agentic-ai-lab-sandbox-profile-by-name
               agentic-ai-lab-default-sandbox-profiles
               'agent/nono))
             (cube-profile
              (agentic-ai-lab-sandbox-profile-by-name
               agentic-ai-lab-default-sandbox-profiles
               'agent/cube))
             (docker-profile
              (agentic-ai-lab-sandbox-profile-by-name
               agentic-ai-lab-default-sandbox-profiles
               'agent/docker)))
        (check-equal? agentic-ai-lab-default-sandbox-profile-names
                      '(agent/nono agent/cube agent/docker))
        (check-equal? (.ref presentation 'profile-count) 3)
        (check-equal? (agentic-ai-lab-sandbox-profile-backend-kind nono-profile)
                      'nono)
        (check-equal? (agentic-ai-lab-sandbox-profile-resource-policy nono-profile)
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
        (check-equal? (agentic-ai-lab-sandbox-profile-backend-ref cube-profile)
                      'cube-local)
        (check-equal? (agentic-ai-lab-sandbox-profile-network-policy cube-profile)
                      '(allowlisted "github.com" "crates.io"))
        (check-equal? (agentic-ai-lab-sandbox-profile-backend-kind docker-profile)
                      'docker)
        (check-equal?
         (agentic-ai-lab-sandbox-profile-recipe-portable? nono-profile)
         #t)
        (check-equal? (.ref presentation 'descriptor-realized?) #f)
        (check-equal? (.ref presentation 'runtime-executed) #f)))
(yuanxu-test-case "rejects absolute paths in public sandbox recipes"
  (let (profile
        (agentic-ai-lab-sandbox-profile
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
     (agentic-ai-lab-sandbox-profile-recipe-portable? profile)
     #f)
    (check-error
     (lambda () (agentic-ai-lab-sandbox-profile->descriptor profile)))))

(yuanxu-test-case "rejects relative runtime targets in public sandbox recipes"
  (let (profile
        (agentic-ai-lab-sandbox-profile
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
     (agentic-ai-lab-sandbox-profile-recipe-portable? profile)
     #f)
    (check-error
     (lambda () (agentic-ai-lab-sandbox-profile->descriptor profile)))))

(yuanxu-test-case "rejects traversal sources outside the logical resource root"
  (let (profile
        (agentic-ai-lab-sandbox-profile
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
     (agentic-ai-lab-sandbox-profile-recipe-portable? profile)
     #f)
    (check-error
     (lambda () (agentic-ai-lab-sandbox-profile->descriptor profile)))))

(yuanxu-test-case "rejects alternate absolute source syntaxes"
  (let ((windows-drive-profile
         (agentic-ai-lab-sandbox-profile
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
         (agentic-ai-lab-sandbox-profile
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
         (agentic-ai-lab-sandbox-profile
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
     (agentic-ai-lab-sandbox-profile-recipe-portable? windows-drive-profile)
     #f)
    (check-equal?
     (agentic-ai-lab-sandbox-profile-recipe-portable? windows-unc-profile)
     #f)
    (check-equal?
     (agentic-ai-lab-sandbox-profile-recipe-portable? file-uri-profile)
     #f)))

(yuanxu-test-case "accepts canonical relative sources under a logical resource root"
  (let (profile
        (agentic-ai-lab-sandbox-profile
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
     (agentic-ai-lab-sandbox-profile-recipe-portable? profile)
     #t)))
    (yuanxu-test-case "declares sandbox and loop module flags without descriptors"
      (let* ((modules
              (yuanxu-user-config-modules test-agentic-ai-lab-user-config))
             (loop-module
              (module-selection-by-key modules '(flow . loop-engine)))
             (nono-module
              (module-selection-by-key modules '(sandbox . nono-sandbox)))
             (cube-module
              (module-selection-by-key modules '(sandbox . cubeSandbox)))
             (docker-module
              (module-selection-by-key modules '(sandbox . docker-sandbox))))
        (check-equal? (yuanxu-user-module-selection? loop-module) #t)
        (check-equal? (yuanxu-user-module-selection-has-flags?
                       loop-module
                       '(+loop-engine +runtime-manifest))
                      #t)
        (check-equal? (yuanxu-user-module-selection-has-flag?
                       nono-module
                       '+nono)
                      #t)
        (check-equal? (yuanxu-user-module-selection-has-flag?
                       cube-module
                       '+cube)
                      #t)
        (check-equal? (yuanxu-user-module-selection-has-flag?
                       docker-module
                       '+docker)
                      #t)))
    (yuanxu-test-case "backend modules contribute capabilities without core branches"
      (let* ((modules
              (yuanxu-user-config-modules test-agentic-ai-lab-user-config))
             (nono
              (agentic-ai-lab-user-config-sandbox-backend-capability modules 'nono))
             (cube
              (agentic-ai-lab-user-config-sandbox-backend-capability modules 'cube))
             (docker
              (agentic-ai-lab-user-config-sandbox-backend-capability modules 'docker)))
        (check-eq? (agentic-ai-lab-sandbox-backend-capability/backend-kind nono)
                   'nono)
        (check-eq? (agentic-ai-lab-sandbox-backend-capability/backend-kind cube)
                   'cube)
        (check-eq? (agentic-ai-lab-sandbox-backend-capability/backend-kind docker)
                   'docker)
        (check-equal?
         (let ((selection
                (module-selection-by-key modules '(sandbox . nono-sandbox))))
           (yuanxu-user-module-selection-has-flag?
            selection ':backend-capability-registry))
         #t)))
    (yuanxu-test-case "queries selected module features without package management"
      (let* ((custom-config
              (yuanxuUserConfigFromProfile test-agentic-ai-lab-user-custom-profile)))
        (check-equal? (yuanxu-user-config-feature?
                       test-agentic-ai-lab-user-config
                       'flow
                       'funflow
                       '+functional
                       '+dag
                       '+typed-receipts
                       '+runtime-manifest)
                      #t)
        (check-equal? (yuanxu-user-config-feature?
                       test-agentic-ai-lab-user-config
                       'flow
                       'funflow
                       '+cicd)
                      #t)
        (check-equal? (yuanxu-user-config-feature?
                       test-agentic-ai-lab-user-config
                       'flow
                       'loop-engine
                       '+loop-engine
                       '+runtime-manifest)
                      #t)
        (check-equal? (yuanxu-user-config-feature?
                       test-agentic-ai-lab-user-config
                       'loop
                       'governor
                       '+missing)
                      #f)
        (check-equal? (yuanxu-user-config-feature?
                       test-agentic-ai-lab-user-config
                       'sandbox
                       'nono-sandbox
                       '+nono
                       '+doctor)
                      #t)
        (check-equal? (yuanxu-user-config-feature?
                       test-agentic-ai-lab-user-config
                       'sandbox
                       'cubeSandbox
                       '+cube
                       '+doctor)
                      #t)
        (check-equal? (yuanxu-user-config-feature?
                       test-agentic-ai-lab-user-config
                       'sandbox
                       'docker-sandbox
                       '+docker
                       '+doctor)
                      #t)
        (check-equal? (yuanxu-user-config-feature?
                       custom-config
                       'custom
                       'my-module
                       '+doctor)
                      #t)))
    (yuanxu-test-case "keeps flow loop and sandbox settings declarative"
      (let ((settings (yuanxu-user-config-settings test-agentic-ai-lab-user-config)))
        (check-equal? (.ref settings 'surface) "agentic-ai-lab")
        (check-equal? (.ref settings 'flow-mode) 'funflow)
        (check-equal? (.ref settings 'loop-strategy) 'governed)
        (check-equal? (.ref settings 'sandbox-policy) 'module-gated)
        (check-equal? (.ref settings 'sandbox-backends)
                      '(nono cube docker))))))
