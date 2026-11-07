;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Loading declarations have one owner. Domain APIs below only construct and inspect values.
(export agentic-ai-lab-user-config-public-entrypoints
        agentic-ai-lab-user-config-api-entrypoints agentic-ai-lab-user-config-boundary)
(def agentic-ai-lab-user-config-public-entrypoints '("yuanxu!"))
(def agentic-ai-lab-user-config-api-entrypoints
  '("yuanxu-user-module-selection-feature?" "yuanxu-user-modules-feature?"
    "yuanxu-user-config-feature?" "yuanxu-user-config-feature-facts"
    "yuanxu-settings" "yuanxuUserConfig"
    "agentic-ai-lab-sandbox-profile->profile" "agenticAiLabSandboxProfilesPresentation"
    "agenticAiLabUserConfigPresentation"
    "agentic-ai-lab-user-workflow-cicd-runtime-command-manifest-agreement"
    "agentic-ai-lab-user-config-workflow-cicd-runtime-command-manifest-agreement"
    "agentic-ai-lab-user-workflow-cicd-marlin-runtime-handoff-abis"
    "agentic-ai-lab-user-config-workflow-cicd-marlin-runtime-handoff-abis"
    "agentic-ai-lab-user-workflow-cicd-marlin-handoff-receipt-bundle"
    "agentic-ai-lab-user-config-workflow-cicd-marlin-handoff-receipt-bundle"
    "agenticAiLabUserProfilePresentation" "agenticAiLabUserProfileSetPresentation"))
(def agentic-ai-lab-user-config-boundary
  '((user-owned . (module-selection settings presentation))
    (module-system-owned . (descriptor-realization validation policy))
    (package-management . #f) (dependency-installation . #f)
    (declarative-module-selection-only . #t)
    (brand-name . "agentic-ai-lab") (scheme-owner . "agentic-ai-lab.scheme")
    (runtime-owner . "marlin-agent-core") (runtime-executed . #f)))
