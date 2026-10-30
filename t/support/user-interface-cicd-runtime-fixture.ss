;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: focused CI/CD runtime projection fixture.
;;; Invariant: construct only the profiles required by the real downstream
;;; Funflow case; do not import the aggregate custom-profile owner.

(import (only-in :yuanxu/module-system/selection/objects
                 yuanxuUserConfig
                 yuanxu-settings
                 yuanxu-user-module-selection)
        (only-in :agentic-ai-lab/modules/agent-sandbox/config
                 agentic-ai-lab-sandbox-profile-config)
        (only-in "../../user-interface/custom/my-module/cases/funflow-cicd"
                 agentic-ai-lab-custom-my-module-funflow-cicd-case))

(export user-interface-cicd-runtime-fixture-config)

(def user-interface-cicd-runtime-fixture-readonly-resources
  '((filesystem
     (scope . project-workspace)
     (paths
      ((role . project-workspace)
       (source . ".")
       (project-marker . "gerbil.pkg")
       (mode . read-only)))
     (access . read-only))))

(def user-interface-cicd-runtime-fixture-readwrite-resources
  '((filesystem
     (scope . project-workspace)
     (paths
      ((role . project-workspace)
       (source . ".")
       (project-marker . "gerbil.pkg")
       (mode . read-write)))
     (access . read-write))))

;; : (-> [PooUserModuleSelection])
(def (user-interface-cicd-runtime-fixture-profile-module)
  (list
   (yuanxu-user-module-selection
    'sandbox
    'nono-sandbox
    (list
     (cons
      ':config
      (list
       (agentic-ai-lab-sandbox-profile-config
        'ci/check
        (list
         '(backend nono)
         '(network deny-by-default)
         '(capabilities process-run filesystem-read tmpdir)
         (cons 'resources
               user-interface-cicd-runtime-fixture-readonly-resources)))
       (agentic-ai-lab-sandbox-profile-config
        'ci/build
        (list
         '(backend nono)
         '(network allowlisted "github.com" "crates.io")
         '(capabilities process-run filesystem-read filesystem-write tmpdir
                        cache-mount)
         (cons 'resources
               user-interface-cicd-runtime-fixture-readwrite-resources)))))))))

;; : (-> PooUserConfig)
(def (user-interface-cicd-runtime-fixture-config)
  (yuanxuUserConfig
   (append (user-interface-cicd-runtime-fixture-profile-module)
           agentic-ai-lab-custom-my-module-funflow-cicd-case)
   (yuanxu-settings)))
