;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: static user-facing entrypoint metadata for module-system reports.
;;; Invariant: this owner contains names and boundary facts only, not activation logic.

(export agentic-ai-lab-user-config-public-entrypoints
        agentic-ai-lab-user-config-api-entrypoints
        agentic-ai-lab-user-config-boundary)

;;; Boundary: these names are the manual-facing declaration surface, not an
;;; implementation map. Programmatic constructors stay in the API list below.
;; : (-> Unit [String])
(def agentic-ai-lab-user-config-public-entrypoints
  '("yuanxu!"
    "load!"
    "use-module"
    ":workflow"
    "loop-engine"
    ":loop"
    ":sandbox"
    ":custom"
    ":config"
    "profiles"
    "agentic-ai-lab-profile"
    "agentic-ai-lab-profile-set"
    "agentic-ai-lab-profile-extend"
    "agentic-ai-lab-sandbox-profile"
    "agentic-ai-lab-sandbox-profiles"
    "agentic-ai-lab-nono-sandbox-profile"
    "agentic-ai-lab-nono-sandbox-profiles"
    "agentic-ai-lab-cubeSandbox-profile"
    "agentic-ai-lab-cubeSandbox-profiles"
    "agentic-ai-lab-docker-sandbox-profile"
    "agentic-ai-lab-docker-sandbox-profiles"))

;;; Boundary: these names are the programmatic API exposed for tests, doctors,
;;; presentations, and advanced module code. They should not be required in
;;; everyday init.ss/config.ss files.
;; : (-> Unit [String])
(def agentic-ai-lab-user-config-api-entrypoints
  '("agentic-ai-lab-module-bundles"
    "agentic-ai-lab-custom-module-bundles"
    "agentic-ai-lab-init-module-bundles"
    "yuanxu-user-module-selection"
    "yuanxu-user-custom-module-selection"
    "yuanxu-user-module-selection-feature?"
    "yuanxu-user-modules-feature?"
    "yuanxu-user-config-feature?"
    "yuanxu-user-config-feature-facts"
    "yuanxu-user-module-bundle"
    "agentic-ai-lab-use-module"
    "yuanxu-user-module-when"
    "yuanxu-settings"
    "agentic-ai-lab-sandbox-profile->profile"
    "agenticAiLabSandboxProfilesPresentation"
    "yuanxuUserProfile"
    "yuanxuUserProfileSet"
    "yuanxuUserProfileExtend"
    "yuanxuUserConfigFromProfile"
    "yuanxuUserConfig"
    "agenticAiLabUserConfigPresentation"
    "agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement"
    "agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifest-agreement"
    "agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abis"
    "agentic-ai-lab-user-config-workflow-cicd-marlin-runtime-handoff-abis"
    "agentic-ai-lab-user-workflow-cicd-marlin-handoff-receipt-bundle"
    "agentic-ai-lab-user-config-workflow-cicd-marlin-handoff-receipt-bundle"
    "agenticAiLabUserProfilePresentation"
    "agenticAiLabUserProfileSetPresentation"))

;;; Boundary: user files own declarations; testing policy owns admission.
;; : (-> Unit Alist)
(def agentic-ai-lab-user-config-boundary
  '((user-owned . (module-selection settings presentation))
    (module-system-owned . (descriptor-realization validation policy))
    (package-management . #f)
    (dependency-installation . #f)
    (declarative-module-selection-only . #t)
    (brand-name . "agentic-ai-lab")
    (scheme-owner . "agentic-ai-lab.scheme")
    (runtime-owner . "marlin-agent-core")
    (runtime-executed . #f)))
