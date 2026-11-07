;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: standalone downstream live CI/CD case module.
;;; Invariant: pure use-* declarations only; src/testing owns execution.

;;; This is a real downstream case, not a profile metadata extension. The user
;;; interface selects sandbox profile supers, then declares isolation
;;; policy, command fields, and runner-local options.
;; : POOObject
(import (only-in :agentic-ai-lab/modules/module-authoring/module-config-syntax
                 agentic-ai-lab-module-inherited-config))

(export agentic-ai-lab-custom-my-module-cicd-case)

(def agentic-ai-lab-custom-my-module-cicd-case
  (agentic-ai-lab-module-inherited-config
   'nono-sandbox
   'ci/build
   '((mode . project-copy)
     (project-mount . isolated-copy)
     (source . ".")
     (root-env . "TMPDIR")
     (root . "agentic-ai-lab-live-case/current-system-build")
     (workspace . "workspace")
     (home . ".home")
     (exclude . (".git" ".tmp" ".cache" "run")))
   '((policy . whitelist)
     (enabled-env . "AGENTIC_AI_LAB_LIVE_CICD_BUILD")
     (clear-env . ("AGENTIC_AI_LAB_LIVE_CICD_BUILD")))
   '((program . "gxpkg")
     (args . ("build")))
   '((network . blocked)
     (audit . disabled))))
