;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: static user-facing entrypoint metadata for module-system reports.
;;; Invariant: this owner contains names and boundary facts only, not activation logic.

(export poo-flow-user-config-public-entrypoints
        poo-flow-user-config-api-entrypoints
        poo-flow-user-config-boundary)

;;; Boundary: these names are the manual-facing declaration surface, not an
;;; implementation map. Programmatic constructors stay in the API list below.
;; : (-> Unit [String])
(def poo-flow-user-config-public-entrypoints
  '("poo-flow!"
    "load!"
    "use-module"
    ":workflow"
    "loop-engine"
    ":loop"
    ":sandbox"
    ":custom"
    ":config"
    "profiles"
    "poo-flow-profile"
    "poo-flow-profile-set"
    "poo-flow-profile-extend"
    "poo-flow-sandbox-profile"
    "poo-flow-sandbox-profiles"
    "poo-flow-nono-sandbox-profile"
    "poo-flow-nono-sandbox-profiles"
    "poo-flow-cubeSandbox-profile"
    "poo-flow-cubeSandbox-profiles"
    "poo-flow-docker-sandbox-profile"
    "poo-flow-docker-sandbox-profiles"))

;;; Boundary: these names are the programmatic API exposed for tests, doctors,
;;; presentations, and advanced module code. They should not be required in
;;; everyday init.ss/config.ss files.
;; : (-> Unit [String])
(def poo-flow-user-config-api-entrypoints
  '("poo-flow-module-bundles"
    "poo-flow-custom-module-bundles"
    "poo-flow-init-module-bundles"
    "poo-flow-user-module-selection"
    "poo-flow-user-custom-module-selection"
    "poo-flow-user-module-selection-feature?"
    "poo-flow-user-modules-feature?"
    "poo-flow-user-config-feature?"
    "poo-flow-user-config-feature-facts"
    "poo-flow-user-module-bundle"
    "poo-flow-use-module"
    "poo-flow-user-module-when"
    "poo-flow-settings"
    "poo-flow-sandbox-profile->profile"
    "pooFlowSandboxProfilesPresentation"
    "pooFlowUserProfile"
    "pooFlowUserProfileSet"
    "pooFlowUserProfileExtend"
    "pooFlowUserConfigFromProfile"
    "pooFlowUserConfig"
    "pooFlowUserConfigPresentation"
    "poo-flow-user-workflow-cicd-runtime-command-manifest-agreement"
    "poo-flow-user-config-workflow-cicd-runtime-command-manifest-agreement"
    "poo-flow-user-workflow-cicd-marlin-runtime-handoff-abis"
    "poo-flow-user-config-workflow-cicd-marlin-runtime-handoff-abis"
    "poo-flow-user-workflow-cicd-marlin-handoff-receipt-bundle"
    "poo-flow-user-config-workflow-cicd-marlin-handoff-receipt-bundle"
    "pooFlowUserProfilePresentation"
    "pooFlowUserProfileSetPresentation"))

;;; Boundary: user files own declarations; testing policy owns admission.
;; : (-> Unit Alist)
(def poo-flow-user-config-boundary
  '((user-owned . (module-selection settings presentation))
    (module-system-owned . (descriptor-realization validation policy))
    (package-management . #f)
    (dependency-installation . #f)
    (declarative-module-selection-only . #t)
    (brand-name . "poo-flow")
    (scheme-owner . "poo-flow.scheme")
    (runtime-owner . "marlin-agent-core")
    (runtime-executed . #f)))
